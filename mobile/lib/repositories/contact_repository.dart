import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/database.dart';
import '../core/formatters.dart';
import '../core/phone.dart';
import '../core/sync_queue.dart';
import '../models/app_user.dart';
import '../models/contact.dart';
import '../models/enums.dart';
import '../models/follow_up.dart';
import '../models/timeline_item.dart';

class ContactRepository {
  ContactRepository(this._database);

  final AppDatabase _database;
  static const _uuid = Uuid();

  Future<Database> get _db => _database.db;

  // ── Lecture ───────────────────────────────────────────────

  /// Répertoire : contacts + dernière note + prochaine relance, en une requête.
  Future<List<ContactListItem>> list({
    String search = '',
    ContactStatus? status,
    ContactListFilter filter = ContactListFilter.all,
    int limit = 300,
  }) async {
    final where = <String>[];
    final args = <Object?>[];

    final q = search.trim();
    if (q.isNotEmpty) {
      final digits = q.replaceAll(RegExp(r'\D'), '');
      final parts = [
        'c.first_name LIKE ?',
        'c.last_name LIKE ?',
        "(c.first_name || ' ' || c.last_name) LIKE ?",
        'c.neighborhood LIKE ?',
      ];
      args.addAll(['%$q%', '%$q%', '%$q%', '%$q%']);
      if (digits.length >= 3) {
        parts.add('c.phone_normalized LIKE ?');
        args.add('%$digits%');
      }
      where.add('(${parts.join(' OR ')})');
    }
    if (status != null) {
      where.add('c.status = ?');
      args.add(status.value);
    }
    switch (filter) {
      case ContactListFilter.all:
        break;
      case ContactListFilter.toContact:
        where.add("c.do_not_contact = 0 AND c.last_follow_up_at IS NULL AND c.status IN ('nouveau', 'a_contacter')");
      case ContactListFilter.inProgress:
        where.add("c.status IN ('contacte', 'invite', 'premiere_visite', 'en_accompagnement')");
      case ContactListFilter.pendingSync:
        where.add("c.sync_state <> 'synced'");
    }

    final rows = await (await _db).rawQuery(
      '''
      SELECT c.*,
        (SELECT COALESCE(f.description, '') FROM follow_ups f
           WHERE f.contact_uuid = c.uuid AND f.description IS NOT NULL AND f.description <> ''
           ORDER BY f.created_at DESC LIMIT 1) AS last_follow_up_note,
        (SELECT e.notes FROM contact_events e
           WHERE e.contact_uuid = c.uuid AND e.notes IS NOT NULL AND e.notes <> ''
           ORDER BY e.occurred_at DESC LIMIT 1) AS last_event_note,
        (SELECT MIN(f2.scheduled_at) FROM follow_ups f2
           WHERE f2.contact_uuid = c.uuid AND f2.completed_at IS NULL AND f2.scheduled_at IS NOT NULL) AS next_follow_up_at
      FROM contacts c
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY c.updated_at DESC
      LIMIT ?
      ''',
      [...args, limit],
    );

    return rows
        .map(
          (r) => ContactListItem(
            contact: Contact.fromDb(r),
            lastNote: (r['last_follow_up_note'] as String?)?.isNotEmpty == true
                ? r['last_follow_up_note'] as String
                : r['last_event_note'] as String?,
            nextFollowUpAt: dateFromDb(r['next_follow_up_at']),
          ),
        )
        .toList();
  }

  /// Compteurs des puces de filtre du répertoire.
  Future<Map<ContactListFilter, int>> filterCounts() async {
    final db = await _db;
    Future<int> c(String where) async =>
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM contacts c${where.isEmpty ? '' : ' WHERE $where'}')) ?? 0;
    return {
      ContactListFilter.all: await c(''),
      ContactListFilter.toContact: await c(
        "c.do_not_contact = 0 AND c.last_follow_up_at IS NULL AND c.status IN ('nouveau', 'a_contacter')",
      ),
      ContactListFilter.inProgress: await c("c.status IN ('contacte', 'invite', 'premiere_visite', 'en_accompagnement')"),
      ContactListFilter.pendingSync: await c("c.sync_state <> 'synced'"),
    };
  }

  /// Quartiers les plus saisis récemment : proposés en puces 1-tap.
  Future<List<String>> recentNeighborhoods({int limit = 6}) async {
    final rows = await (await _db).rawQuery(
      'SELECT neighborhood, COUNT(*) AS n FROM contacts WHERE neighborhood IS NOT NULL AND neighborhood <> \'\' '
      'GROUP BY neighborhood ORDER BY n DESC, MAX(created_at) DESC LIMIT ?',
      [limit],
    );
    return rows.map((r) => r['neighborhood'] as String).toList();
  }

  /// Prochaine action programmée d'un contact (carte « Prochaine action de suivi »).
  Future<FollowUp?> nextFollowUp(String contactUuid) async {
    final rows = await (await _db).query(
      'follow_ups',
      where: 'contact_uuid = ? AND completed_at IS NULL AND scheduled_at IS NOT NULL',
      whereArgs: [contactUuid],
      orderBy: 'scheduled_at ASC',
      limit: 1,
    );
    return rows.isEmpty ? null : FollowUp.fromDb(rows.first);
  }

  Future<Contact?> find(String uuid) async {
    final rows = await (await _db).query('contacts', where: 'uuid = ?', whereArgs: [uuid], limit: 1);
    return rows.isEmpty ? null : Contact.fromDb(rows.first);
  }

  /// Contacts déjà enregistrés avec ce numéro (vérification, pas rejet).
  Future<List<Contact>> findByPhone(String? phone) async {
    final normalized = normalizePhone(phone);
    if (normalized == null) return [];
    final rows = await (await _db).query('contacts', where: 'phone_normalized = ?', whereArgs: [normalized]);
    return rows.map(Contact.fromDb).toList();
  }

  /// Historique complet d'une fiche, du plus récent au plus ancien.
  Future<List<TimelineItem>> timeline(String contactUuid) async {
    final db = await _db;
    final items = <TimelineItem>[];

    for (final r in await db.query('contact_events', where: 'contact_uuid = ?', whereArgs: [contactUuid])) {
      final type = ContactEventType.from(r['type']);
      items.add(
        TimelineItem(
          date: dateFromDb(r['occurred_at'])!,
          icon: type == ContactEventType.decisionDeFoi ? Icons.favorite_outline : Icons.place_outlined,
          title: type.label,
          subtitle: [r['location'], r['notes']].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
          author: r['recorded_by_name'] as String?,
          pendingSync: r['sync_state'] == SyncState.pending.value,
        ),
      );
    }

    for (final r in await db.query('follow_ups', where: 'contact_uuid = ?', whereArgs: [contactUuid])) {
      final type = FollowUpActionType.from(r['action_type']);
      final result = FollowUpResult.from(r['result']);
      final done = r['completed_at'] != null;
      final date = dateFromDb(done ? r['completed_at'] : (r['scheduled_at'] ?? r['created_at']))!;
      items.add(
        TimelineItem(
          date: date,
          icon: _followUpIcon(type),
          title: done ? '${type.label}${result != null ? ' — ${result.label}' : ''}' : '${type.label} programmé',
          subtitle: r['description'] as String?,
          author: r['user_name'] as String?,
          pendingSync: r['sync_state'] == SyncState.pending.value,
        ),
      );
    }

    for (final r in await db.query('status_changes', where: 'contact_uuid = ?', whereArgs: [contactUuid])) {
      items.add(
        TimelineItem(
          date: dateFromDb(r['changed_at'])!,
          icon: Icons.flag_outlined,
          title: 'Statut : ${ContactStatus.from(r['to_status']).label}',
          subtitle: r['reason'] as String?,
          author: r['changed_by_name'] as String?,
        ),
      );
    }

    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  static IconData _followUpIcon(FollowUpActionType t) => switch (t) {
    FollowUpActionType.appel => Icons.call_outlined,
    FollowUpActionType.sms => Icons.sms_outlined,
    FollowUpActionType.whatsapp => Icons.chat_outlined,
    FollowUpActionType.visite => Icons.directions_walk,
    FollowUpActionType.invitationCulte => Icons.event_outlined,
    FollowUpActionType.rendezVous => Icons.schedule,
    FollowUpActionType.note => Icons.notes,
  };

  // ── Écriture (toujours locale d'abord, puis file d'attente) ──

  /// Enregistre une nouvelle personne + sa première rencontre + son consentement.
  Future<Contact> create(ContactDraft d, AppUser user) async {
    final now = DateTime.now();
    final phone = d.phone.trim().isEmpty ? null : d.phone.trim();
    String? blank(String s) => s.trim().isEmpty ? null : s.trim();

    final contact = Contact(
      uuid: _uuid.v4(),
      firstName: d.firstName.trim(),
      lastName: d.lastName.trim(),
      phone: phone,
      phoneNormalized: normalizePhone(phone),
      gender: d.gender,
      ageRange: d.ageRange,
      neighborhood: blank(d.neighborhood),
      arrondissement: blank(d.arrondissement),
      addressHint: blank(d.addressHint),
      source: d.source,
      status: d.wantsContact ? ContactStatus.nouveau : ContactStatus.nePlusContacter,
      firstMetAt: d.firstMetAt,
      teamId: d.teamId,
      teamName: d.teamName,
      createdById: user.id,
      createdByName: user.name,
      wantsContact: d.wantsContact,
      preferredChannel: d.preferredChannel,
      doNotContact: !d.wantsContact,
      wantsSpiritualSupport: d.wantsSpiritualSupport,
      wantsServiceInvitation: d.wantsServiceInvitation,
      wantsHouseChurch: d.wantsHouseChurch,
      createdAt: now,
      updatedAt: now,
    );

    final eventUuid = _uuid.v4();
    final eventType = d.source == ContactSource.accueil ? ContactEventType.visiteCulte : ContactEventType.premiereRencontre;

    await (await _db).transaction((txn) async {
      await txn.insert('contacts', contact.toDb());
      await txn.insert('contact_events', {
        'uuid': eventUuid,
        'contact_uuid': contact.uuid,
        'type': eventType.value,
        'occurred_at': dateToDb(d.firstMetAt),
        'location': contact.neighborhood,
        'notes': blank(d.notes),
        'recorded_by_name': user.name,
        'created_at': dateToDb(now),
      });
      await txn.insert('status_changes', {
        'contact_uuid': contact.uuid,
        'to_status': contact.status.value,
        'reason': 'Enregistrement',
        'changed_by_name': user.name,
        'changed_at': dateToDb(now),
      });
      await enqueue(
        txn,
        entity: SyncEntity.contact,
        uuid: contact.uuid,
        operation: SyncOp.create,
        payload: {
          ...contact.toApi(),
          'first_event': {
            'uuid': eventUuid,
            'type': eventType.value,
            'occurred_at': d.firstMetAt.toUtc().toIso8601String(),
            'notes': blank(d.notes),
          },
          // Consentement explicite recueilli au moment de la rencontre.
          'consent': {'purpose': 'suivi', 'granted': d.wantsContact, 'method': 'oral', 'channel': d.preferredChannel?.value},
        },
      );
    });

    return contact;
  }

  /// « Enregistrer une nouvelle rencontre » sur un dossier existant (cas du doublon).
  Future<void> addEncounter(String contactUuid, ContactEventType type, AppUser user, {String? notes, String? location}) async {
    final now = DateTime.now();
    final eventUuid = _uuid.v4();
    final payload = {
      'uuid': eventUuid,
      'contact_uuid': contactUuid,
      'type': type.value,
      'occurred_at': now.toUtc().toIso8601String(),
      'location': location,
      'notes': notes,
    };

    await (await _db).transaction((txn) async {
      await txn.insert('contact_events', {
        'uuid': eventUuid,
        'contact_uuid': contactUuid,
        'type': type.value,
        'occurred_at': dateToDb(now),
        'location': location,
        'notes': notes,
        'recorded_by_name': user.name,
        'created_at': dateToDb(now),
      });
      await txn.update('contacts', {'updated_at': dateToDb(now)}, where: 'uuid = ?', whereArgs: [contactUuid]);
      await enqueue(txn, entity: SyncEntity.event, uuid: eventUuid, operation: SyncOp.create, payload: payload);
    });
  }

  /// Changement de statut historisé. « Intégré » est refusé (confirmation serveur requise).
  Future<void> changeStatus(Contact contact, ContactStatus to, AppUser user, {String? reason}) async {
    if (!to.manuallyAssignable) {
      throw StateError('Le statut « Intégré » découle d’une intégration confirmée par un responsable.');
    }
    if (contact.status == to) return;

    final now = DateTime.now();
    final doNotContact = to == ContactStatus.nePlusContacter ? true : contact.doNotContact;

    await (await _db).transaction((txn) async {
      await txn.update(
        'contacts',
        {
          'status': to.value,
          'do_not_contact': boolToDb(doNotContact),
          'sync_state': SyncState.pending.value,
          'updated_at': dateToDb(now),
        },
        where: 'uuid = ?',
        whereArgs: [contact.uuid],
      );
      await txn.insert('status_changes', {
        'contact_uuid': contact.uuid,
        'from_status': contact.status.value,
        'to_status': to.value,
        'reason': reason,
        'changed_by_name': user.name,
        'changed_at': dateToDb(now),
      });
      await enqueue(
        txn,
        entity: SyncEntity.contact,
        uuid: contact.uuid,
        operation: SyncOp.statusChange,
        payload: {'status': to.value, 'reason': reason, 'changed_at': now.toUtc().toIso8601String()},
        baseVersion: contact.version,
      );
    });
  }

  // ── Statistiques du tableau de bord (calculées sur les données locales) ──

  Future<DashboardStats> stats(DateTime since) async {
    final db = await _db;
    Future<int> count(String sql, [List<Object?> args = const []]) async =>
        Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;

    final s = dateToDb(since);
    return DashboardStats(
      total: await count('SELECT COUNT(*) FROM contacts'),
      newContacts: await count('SELECT COUNT(*) FROM contacts WHERE created_at >= ?', [s]),
      evangelisation: await count('SELECT COUNT(*) FROM contacts WHERE source = ? AND created_at >= ?', [
        ContactSource.evangelisation.value,
        s,
      ]),
      newVisitors: await count('SELECT COUNT(*) FROM contacts WHERE source = ? AND created_at >= ?', [
        ContactSource.accueil.value,
        s,
      ]),
      pendingFollowUps: await count(
        'SELECT COUNT(*) FROM follow_ups f JOIN contacts c ON c.uuid = f.contact_uuid '
        'WHERE f.completed_at IS NULL AND c.do_not_contact = 0',
      ),
      returned: await count(
        'SELECT COUNT(*) FROM (SELECT contact_uuid FROM contact_events WHERE type = ? GROUP BY contact_uuid HAVING COUNT(*) >= 2)',
        [ContactEventType.visiteCulte.value],
      ),
      integrated: await count('SELECT COUNT(*) FROM contacts WHERE status = ?', [ContactStatus.integre.value]),
      byStatus: {
        for (final r in await db.rawQuery('SELECT status, COUNT(*) AS n FROM contacts GROUP BY status'))
          ContactStatus.from(r['status']): r['n'] as int,
      },
    );
  }
}

enum ContactListFilter {
  all('Tous'),
  toContact('À contacter'),
  inProgress('En cours'),
  pendingSync('Non synchronisés');

  const ContactListFilter(this.label);
  final String label;
}

class ContactListItem {
  const ContactListItem({required this.contact, this.lastNote, this.nextFollowUpAt});

  final Contact contact;
  final String? lastNote;
  final DateTime? nextFollowUpAt;
}

class DashboardStats {
  const DashboardStats({
    required this.total,
    required this.newContacts,
    required this.evangelisation,
    required this.newVisitors,
    required this.pendingFollowUps,
    required this.returned,
    required this.integrated,
    required this.byStatus,
  });

  final int total;
  final int newContacts;
  final int evangelisation;
  final int newVisitors;
  final int pendingFollowUps;
  final int returned;
  final int integrated;
  final Map<ContactStatus, int> byStatus;
}

final contactRepositoryProvider = Provider<ContactRepository>((ref) => ContactRepository(ref.watch(databaseProvider)));
