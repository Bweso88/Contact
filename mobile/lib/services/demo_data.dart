import 'dart:math';

import 'package:uuid/uuid.dart';

import '../core/database.dart';
import '../core/formatters.dart';
import '../core/phone.dart';
import '../models/app_user.dart';
import '../models/enums.dart';

/// Données fictives du mode démonstration (aucun serveur configuré).
/// Marquées « synced » : elles ne partent jamais vers une API.
abstract final class DemoData {
  static AppUser user(String username) => AppUser(
    id: 1,
    name: username.trim().isEmpty ? 'Démo' : _capitalize(username.trim()),
    username: username.trim().isEmpty ? 'demo' : username.trim(),
    roles: const ['responsable_eglise'],
    permissions: const [
      'dashboard.view_global',
      'reports.view',
      'contacts.create',
      'contacts.view_all',
      'contacts.update',
      'contacts.assign',
      'follow_ups.create',
      'follow_ups.update_own',
      'follow_ups.update_all',
      'consents.manage',
      'teams.view',
      'house_churches.view',
      'integrations.propose',
      'integrations.confirm',
    ],
    teams: const [UserTeam(id: 1, name: 'Équipe évangélisation A', isLeader: true)],
  );

  static const _people = [
    ('Grâce', 'Mabiala', 'Mafouta', ContactStatus.aContacter, ContactSource.evangelisation),
    ('Christ', 'Nkounkou', 'Mafouta', ContactStatus.contacte, ContactSource.evangelisation),
    ('Prisca', 'Malonga', 'Mansimou', ContactStatus.invite, ContactSource.evangelisation),
    ('Jonathan', 'Bouesso', 'Mansimou', ContactStatus.premiereVisite, ContactSource.accueil),
    ('Merveille', 'Samba', 'Kinsoundi', ContactStatus.enAccompagnement, ContactSource.accueil),
    ('Dieudonné', 'Massamba', 'Mafouta', ContactStatus.integre, ContactSource.evangelisation),
    ('Exaucée', 'Loubaki', 'Moukondo', ContactStatus.nouveau, ContactSource.accueil),
    ('Rodrigue', 'Mpassi', 'Mansimou', ContactStatus.injoignable, ContactSource.evangelisation),
    ('Bénédicte', 'Ngoma', 'Kinsoundi', ContactStatus.contacte, ContactSource.invitationMembre),
    ('Fortuné', 'Kibangou', 'Mafouta', ContactStatus.nouveau, ContactSource.evangelisation),
  ];

  static const _notes = [
    'Rencontrée au marché, souhaite être rappelée le soir.',
    'Intéressé par le culte de dimanche, viendra avec son frère.',
    'A demandé une invitation pour le groupe des jeunes.',
    'Très accueillante, préfère WhatsApp.',
    null,
  ];

  static Future<void> seed(AppDatabase database, AppUser user) async {
    final db = await database.db;
    final existing = await db.query('contacts', limit: 1);
    if (existing.isNotEmpty) return;

    const uuid = Uuid();
    final rnd = Random(42);
    final now = DateTime.now();

    await db.transaction((txn) async {
      for (var i = 0; i < _people.length; i++) {
        final (first, last, quartier, status, source) = _people[i];
        final id = uuid.v4();
        final metAt = now.subtract(Duration(days: rnd.nextInt(25) + 1, hours: rnd.nextInt(8)));
        final phone = '06 ${100 + i * 37} ${10 + i} ${20 + i * 3}';
        final note = _notes[i % _notes.length];

        await txn.insert('contacts', {
          'uuid': id,
          'first_name': first,
          'last_name': last,
          'phone': phone,
          'phone_normalized': normalizePhone(phone),
          'neighborhood': quartier,
          'arrondissement': quartier == 'Mansimou' ? 'Madibou' : 'Djiri',
          'source': source.value,
          'status': status.value,
          'first_met_at': dateToDb(metAt),
          'team_id': 1,
          'team_name': 'Équipe évangélisation A',
          'assigned_user_id': user.id,
          'assigned_user_name': user.name,
          'created_by_id': user.id,
          'created_by_name': user.name,
          'wants_contact': 1,
          'preferred_channel': i.isEven ? 'whatsapp' : 'appel',
          'do_not_contact': 0,
          'last_follow_up_at': status == ContactStatus.nouveau || status == ContactStatus.aContacter
              ? null
              : dateToDb(metAt.add(const Duration(days: 2))),
          'version': 1,
          'sync_state': 'synced',
          'created_at': dateToDb(metAt),
          'updated_at': dateToDb(metAt.add(Duration(days: rnd.nextInt(3)))),
        });

        await txn.insert('contact_events', {
          'uuid': uuid.v4(),
          'contact_uuid': id,
          'type': source == ContactSource.accueil ? 'visite_culte' : 'premiere_rencontre',
          'occurred_at': dateToDb(metAt),
          'location': quartier,
          'notes': note,
          'recorded_by_name': user.name,
          'sync_state': 'synced',
          'created_at': dateToDb(metAt),
        });

        await txn.insert('status_changes', {
          'contact_uuid': id,
          'to_status': status.value,
          'reason': 'Données de démonstration',
          'changed_by_name': user.name,
          'changed_at': dateToDb(metAt),
        });

        // Une relance programmée : en retard, aujourd'hui ou à venir.
        if (!status.excludedFromReminders) {
          await txn.insert('follow_ups', {
            'uuid': uuid.v4(),
            'contact_uuid': id,
            'user_id': user.id,
            'user_name': user.name,
            'action_type': i.isEven ? 'whatsapp' : 'appel',
            'description': i.isEven ? 'Prendre des nouvelles et rappeler le culte de dimanche.' : null,
            'scheduled_at': dateToDb(now.add(Duration(days: (i % 3) - 1, hours: 2))),
            'sync_state': 'synced',
            'created_at': dateToDb(metAt),
            'updated_at': dateToDb(metAt),
          });
        }
      }
    });
  }

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
