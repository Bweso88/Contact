import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/database.dart';
import '../core/formatters.dart';
import '../core/sync_queue.dart';
import '../models/app_user.dart';
import '../models/enums.dart';
import '../models/follow_up.dart';

enum FollowUpBucket { overdue, today, upcoming }

class FollowUpRepository {
  FollowUpRepository(this._database);

  final AppDatabase _database;
  static const _uuid = Uuid();

  Future<Database> get _db => _database.db;

  /// Actions programmées non réalisées, pour les contacts qu'on peut encore relancer.
  /// [mineOnly] : seulement celles affectées à l'utilisateur.
  Future<List<FollowUp>> due(FollowUpBucket bucket, {int? userId}) async {
    final today = startOfDay(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));

    final (String cond, List<Object?> args) = switch (bucket) {
      FollowUpBucket.overdue => ('f.scheduled_at < ?', [dateToDb(today)]),
      FollowUpBucket.today => ('f.scheduled_at >= ? AND f.scheduled_at < ?', [dateToDb(today), dateToDb(tomorrow)]),
      FollowUpBucket.upcoming => ('f.scheduled_at >= ?', [dateToDb(tomorrow)]),
    };

    final excluded = ContactStatus.values.where((s) => s.excludedFromReminders).map((s) => "'${s.value}'").join(',');

    final rows = await (await _db).rawQuery(
      '''
      SELECT f.*, (c.first_name || ' ' || c.last_name) AS contact_name, c.phone AS contact_phone
      FROM follow_ups f
      JOIN contacts c ON c.uuid = f.contact_uuid
      WHERE f.completed_at IS NULL AND f.scheduled_at IS NOT NULL
        AND c.do_not_contact = 0 AND c.status NOT IN ($excluded)
        AND $cond ${userId != null ? 'AND f.user_id = ?' : ''}
      ORDER BY f.scheduled_at ${bucket == FollowUpBucket.overdue ? 'DESC' : 'ASC'}
      ''',
      [...args, if (userId != null) userId],
    );
    return rows.map(FollowUp.fromDb).toList();
  }

  /// Ajoute une action : réalisée tout de suite (completedAt) ou programmée (scheduledAt).
  Future<FollowUp> create({
    required String contactUuid,
    required FollowUpActionType type,
    required AppUser user,
    String? description,
    FollowUpResult? result,
    DateTime? scheduledAt,
    DateTime? completedAt,
  }) async {
    final f = FollowUp(
      uuid: _uuid.v4(),
      contactUuid: contactUuid,
      userId: user.id,
      userName: user.name,
      actionType: type,
      description: (description?.trim().isEmpty ?? true) ? null : description!.trim(),
      result: result,
      scheduledAt: scheduledAt,
      completedAt: completedAt,
      createdAt: DateTime.now(),
    );

    await (await _db).transaction((txn) async {
      await txn.insert('follow_ups', f.toDb());
      await _touchContact(txn, contactUuid, completedAt);
      await enqueue(txn, entity: SyncEntity.followUp, uuid: f.uuid, operation: SyncOp.create, payload: f.toApi());
    });
    return f;
  }

  /// Marque une action programmée comme réalisée.
  Future<void> complete(FollowUp f, FollowUpResult result, {String? description}) async {
    final now = DateTime.now();
    final desc = (description?.trim().isEmpty ?? true) ? f.description : description!.trim();

    await (await _db).transaction((txn) async {
      await txn.update(
        'follow_ups',
        {
          'completed_at': dateToDb(now),
          'result': result.value,
          'description': desc,
          'sync_state': SyncState.pending.value,
          'updated_at': dateToDb(now),
        },
        where: 'uuid = ?',
        whereArgs: [f.uuid],
      );
      await _touchContact(txn, f.contactUuid, now);
      await enqueue(
        txn,
        entity: SyncEntity.followUp,
        uuid: f.uuid,
        operation: SyncOp.update,
        payload: {'completed_at': now.toUtc().toIso8601String(), 'result': result.value, 'description': desc},
      );
    });
  }

  Future<void> _touchContact(DatabaseExecutor txn, String contactUuid, DateTime? completedAt) async {
    await txn.update(
      'contacts',
      {'updated_at': dateToDb(DateTime.now()), if (completedAt != null) 'last_follow_up_at': dateToDb(completedAt)},
      where: 'uuid = ?',
      whereArgs: [contactUuid],
    );
  }
}

final followUpRepositoryProvider = Provider<FollowUpRepository>((ref) => FollowUpRepository(ref.watch(databaseProvider)));
