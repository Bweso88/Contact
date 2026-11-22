import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../core/config.dart';
import '../core/database.dart';
import '../core/formatters.dart';
import '../core/sync_queue.dart';
import '../models/contact.dart';
import '../models/enums.dart';
import '../models/follow_up.dart';
import 'api_client.dart';
import 'auth_controller.dart';

class SyncStatus {
  const SyncStatus({
    this.online = true,
    this.running = false,
    this.pending = 0,
    this.conflicts = 0,
    this.failed = 0,
    this.lastSyncAt,
    this.lastError,
  });

  final bool online;
  final bool running;
  final int pending;
  final int conflicts;

  /// Opérations refusées par le serveur (ex. validation) : à examiner.
  final int failed;
  final DateTime? lastSyncAt;
  final String? lastError;

  SyncStatus copyWith({
    bool? online,
    bool? running,
    int? pending,
    int? conflicts,
    int? failed,
    DateTime? lastSyncAt,
    String? lastError,
    bool clearError = false,
  }) => SyncStatus(
    online: online ?? this.online,
    running: running ?? this.running,
    pending: pending ?? this.pending,
    conflicts: conflicts ?? this.conflicts,
    failed: failed ?? this.failed,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    lastError: clearError ? null : (lastError ?? this.lastError),
  );
}

/// Synchronisation hors connexion (section 7 du cahier des charges) :
///  1. chaque écriture locale ajoute une opération dans sync_queue ;
///  2. au retour du réseau (ou toutes les 5 min), on envoie la file à POST /api/sync ;
///  3. le serveur valide chaque opération et répond ok / conflict / error ;
///  4. la réponse contient aussi les changements faits par les autres depuis le dernier passage.
///
/// L'UUID généré sur le téléphone rend l'envoi idempotent : si la réponse se perd
/// et qu'on renvoie la même création, le serveur la reconnaît et ne crée pas de doublon.
class SyncController extends Notifier<SyncStatus> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _timer;
  bool _busy = false;

  AppDatabase get _database => ref.read(databaseProvider);

  @override
  SyncStatus build() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = _isOnline(results);
      final wasOffline = !state.online;
      state = state.copyWith(online: online);
      if (online && wasOffline) syncNow();
    });
    Connectivity().checkConnectivity().then((r) => state = state.copyWith(online: _isOnline(r)));

    _timer = Timer.periodic(AppConfig.syncInterval, (_) => syncNow());

    ref.onDispose(() {
      _connectivitySub?.cancel();
      _timer?.cancel();
    });

    // Recompte la file à chaque écriture locale.
    ref.listen(dataRevisionProvider, (_, __) => refreshCounts());
    Future.microtask(refreshCounts);

    return const SyncStatus();
  }

  static bool _isOnline(List<ConnectivityResult> r) => r.any((x) => x != ConnectivityResult.none);

  Future<void> refreshCounts() async {
    final db = await _database.db;
    final pending = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM sync_queue')) ?? 0;
    final failed = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM sync_queue WHERE attempts >= 3')) ?? 0;
    final conflicts =
        Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM contacts WHERE sync_state = 'conflict'")) ?? 0;
    state = state.copyWith(pending: pending, failed: failed, conflicts: conflicts);
  }

  Future<void> syncNow() async {
    if (_busy || ref.read(currentUserProvider) == null) return;

    if (AppConfig.isDemo) {
      state = state.copyWith(lastSyncAt: DateTime.now(), clearError: true);
      return;
    }
    if (!state.online) return;

    _busy = true;
    state = state.copyWith(running: true, clearError: true);
    try {
      // Plusieurs tours si la file dépasse un lot ; borne de sécurité à 20 tours.
      for (var round = 0; round < 20; round++) {
        final hasMore = await _syncRound();
        if (!hasMore) break;
      }
      state = state.copyWith(lastSyncAt: DateTime.now());
    } on ApiException catch (e) {
      state = state.copyWith(lastError: e.message);
    } catch (e) {
      state = state.copyWith(lastError: 'Synchronisation interrompue : $e');
    } finally {
      _busy = false;
      state = state.copyWith(running: false);
      await refreshCounts();
      ref.read(dataRevisionProvider.notifier).bump();
    }
  }

  /// Un aller-retour avec le serveur. Renvoie true s'il reste des opérations à envoyer.
  Future<bool> _syncRound() async {
    final db = await _database.db;

    // Les opérations d'un contact en conflit attendent la décision de l'utilisateur ;
    // celles refusées 5 fois sont mises de côté (visibles dans le profil).
    final ops = await db.rawQuery(
      '''
      SELECT * FROM sync_queue
      WHERE attempts < 5
        AND entity_uuid NOT IN (SELECT uuid FROM contacts WHERE sync_state = 'conflict')
      ORDER BY id LIMIT ?
      ''',
      [AppConfig.syncBatchSize],
    );

    final cursor = (await db.query('meta', where: 'key = ?', whereArgs: ['last_pulled_at'])).firstOrNull?['value'] as String?;

    final res = await ref.read(apiClientProvider).post('/api/sync', {
      'last_pulled_at': cursor,
      'operations': [
        for (final op in ops)
          {
            'id': op['id'],
            'entity': op['entity'],
            'uuid': op['entity_uuid'],
            'operation': op['operation'],
            'base_version': op['base_version'],
            'payload': jsonDecode(op['payload'] as String),
          },
      ],
    });

    await db.transaction((txn) async {
      for (final r in (res['results'] as List? ?? const []).cast<Map<String, dynamic>>()) {
        await _applyResult(txn, r, ops);
      }
      await _applyServerChanges(txn, (res['changes'] as Map<String, dynamic>?) ?? const {});
      if (res['cursor'] != null) {
        await txn.insert('meta', {
          'key': 'last_pulled_at',
          'value': res['cursor'].toString(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });

    return ops.length >= AppConfig.syncBatchSize;
  }

  Future<void> _applyResult(Transaction txn, Map<String, dynamic> r, List<Map<String, Object?>> ops) async {
    final opId = r['id'] as int;
    final op = ops.where((o) => o['id'] == opId).firstOrNull;
    if (op == null) return;
    final entity = op['entity'] as String;
    final uuid = op['entity_uuid'] as String;

    switch (r['status']) {
      case 'ok':
        await txn.delete('sync_queue', where: 'id = ?', whereArgs: [opId]);
        final remaining =
            Sqflite.firstIntValue(await txn.rawQuery('SELECT COUNT(*) FROM sync_queue WHERE entity_uuid = ?', [uuid])) ?? 0;
        final table = _tableFor(entity);
        final values = <String, Object?>{if (remaining == 0) 'sync_state': SyncState.synced.value};
        if (entity == SyncEntity.contact && r['version'] != null) {
          values['version'] = r['version'];
          // Les opérations suivantes du même contact partent de la nouvelle version.
          await txn.update('sync_queue', {'base_version': r['version']}, where: 'entity_uuid = ?', whereArgs: [uuid]);
        }
        if (values.isNotEmpty) await txn.update(table, values, where: 'uuid = ?', whereArgs: [uuid]);

      case 'conflict':
        // Ne jamais écraser en silence : on garde les deux versions et on demande.
        await txn.update(
          'contacts',
          {'sync_state': SyncState.conflict.value, 'server_payload': jsonEncode(r['server'])},
          where: 'uuid = ?',
          whereArgs: [uuid],
        );

      default:
        await txn.rawUpdate('UPDATE sync_queue SET attempts = attempts + 1, last_error = ? WHERE id = ?', [
          r['message']?.toString() ?? 'Refusé par le serveur',
          opId,
        ]);
    }
  }

  static String _tableFor(String entity) => switch (entity) {
    SyncEntity.contact => 'contacts',
    SyncEntity.followUp => 'follow_ups',
    _ => 'contact_events',
  };

  /// Intègre les modifications faites par les autres utilisateurs.
  /// Un enregistrement modifié localement et pas encore envoyé n'est pas écrasé :
  /// le serveur signalera le conflit au prochain envoi.
  Future<void> _applyServerChanges(Transaction txn, Map<String, dynamic> changes) async {
    for (final j in (changes['contacts'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      if (j['deleted'] == true) {
        await txn.delete('contacts', where: "uuid = ? AND sync_state = 'synced'", whereArgs: [j['uuid']]);
        continue;
      }
      await _upsertIfSynced(txn, 'contacts', Contact.fromApi(j).toDb());
    }
    for (final j in (changes['follow_ups'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      await _upsertIfSynced(txn, 'follow_ups', FollowUp.fromApi(j).toDb());
    }
    for (final j in (changes['contact_events'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      await _upsertIfSynced(txn, 'contact_events', {
        'uuid': j['uuid'],
        'contact_uuid': j['contact_uuid'],
        'type': j['type'],
        'occurred_at': dateToDb(DateTime.parse(j['occurred_at'] as String)),
        'location': j['location'],
        'notes': j['notes'],
        'recorded_by_name': (j['recorded_by'] as Map?)?['name'],
        'sync_state': SyncState.synced.value,
        'created_at': dateToDb(DateTime.parse((j['created_at'] ?? j['occurred_at']) as String)),
      });
    }
  }

  /// UPDATE puis INSERT — surtout pas INSERT OR REPLACE : REPLACE supprime la ligne,
  /// ce qui effacerait en cascade les suivis et rencontres du contact.
  Future<void> _upsertIfSynced(Transaction txn, String table, Map<String, Object?> row) async {
    final uuid = row['uuid'];
    final local = await txn.query(table, columns: ['sync_state'], where: 'uuid = ?', whereArgs: [uuid], limit: 1);
    if (local.isEmpty) {
      // Un suivi peut arriver avant son contact (hors de notre périmètre) : on l'ignore.
      try {
        await txn.insert(table, row);
      } on DatabaseException {
        return;
      }
    } else if (local.first['sync_state'] == SyncState.synced.value) {
      await txn.update(table, row, where: 'uuid = ?', whereArgs: [uuid]);
    }
  }

  /// Résolution d'un conflit sur une fiche.
  /// [keepMine] : renvoyer mes modifications par-dessus la version du serveur.
  /// Sinon : adopter la version du serveur et abandonner mes modifications de la fiche.
  Future<void> resolveConflict(Contact contact, {required bool keepMine}) async {
    final payload = contact.serverPayload;
    if (payload == null) return;
    final server = Contact.fromApi(jsonDecode(payload) as Map<String, dynamic>);
    final db = await _database.db;

    await db.transaction((txn) async {
      if (keepMine) {
        await txn.update(
          'sync_queue',
          {'base_version': server.version, 'attempts': 0},
          where: 'entity_uuid = ?',
          whereArgs: [contact.uuid],
        );
        await txn.update(
          'contacts',
          {'sync_state': SyncState.pending.value, 'server_payload': null, 'version': server.version},
          where: 'uuid = ?',
          whereArgs: [contact.uuid],
        );
      } else {
        await txn.delete('sync_queue', where: 'entity_uuid = ?', whereArgs: [contact.uuid]);
        await txn.update('contacts', server.toDb(), where: 'uuid = ?', whereArgs: [contact.uuid]);
      }
    });

    ref.read(dataRevisionProvider.notifier).bump();
    if (keepMine) unawaited(syncNow());
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncStatus>(SyncController.new);
