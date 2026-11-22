import 'package:eglise_connect/core/phone.dart';
import 'package:eglise_connect/models/app_user.dart';
import 'package:eglise_connect/models/contact.dart';
import 'package:eglise_connect/models/enums.dart';
import 'package:eglise_connect/models/follow_up.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lancer : flutter test
void check(bool ok, String what) => expect(ok, isTrue, reason: what);

void main() {
  test('Normalisation, enums et modèles', () {
    check(normalizePhone('06 123 45 67') == '242061234567', 'normalise local');
    check(normalizePhone('+242 061234567') == '242061234567', 'normalise +242');
    check(normalizePhone('00242-06-123-45-67') == '242061234567', 'normalise 00242');
    check(normalizePhone('') == null && normalizePhone('12') == null, 'vide / trop court');

    // Valeurs identiques aux enums PHP
    check(
      ContactStatus.values.map((e) => e.value).join(',') ==
          'nouveau,a_contacter,contacte,invite,premiere_visite,en_accompagnement,integre,en_pause,injoignable,ne_plus_contacter',
      'statuts = PHP',
    );
    check(
      ContactStatus.from('premiere_visite') == ContactStatus.premiereVisite && ContactStatus.from('xx') == ContactStatus.nouveau,
      'from + repli',
    );
    check(!ContactStatus.integre.manuallyAssignable && ContactStatus.enPause.excludedFromReminders, 'règles statut');
    check(AgeRange.from('18_25') == AgeRange.de18a25 && Gender.from(null) == null, 'enums nullables');

    final now = DateTime(2026, 11, 22, 10, 30);
    final c = Contact(
      uuid: 'u1',
      firstName: 'Grâce',
      lastName: 'Mabiala',
      phone: '06 123 45 67',
      phoneNormalized: normalizePhone('06 123 45 67'),
      source: ContactSource.accueil,
      status: ContactStatus.invite,
      firstMetAt: now,
      wantsServiceInvitation: true,
      createdAt: now,
      updatedAt: now,
    );
    final back = Contact.fromDb(c.toDb());
    check(
      back.fullName == 'Grâce Mabiala' &&
          back.status == ContactStatus.invite &&
          back.wantsServiceInvitation == true &&
          back.wantsHouseChurch == null &&
          back.firstMetAt == now &&
          back.initials == 'GM',
      'Contact aller-retour SQLite',
    );
    check(c.toApi()['first_met_at'] == '2026-11-22' && !c.toApi().containsKey('status'), 'toApi (date, sans statut)');
    final fromApi = Contact.fromApi({
      'uuid': 'u2',
      'first_name': 'A',
      'last_name': 'B',
      'source': 'evangelisation',
      'status': 'contacte',
      'first_met_at': '2026-11-20',
      'team': {'id': 3, 'name': 'Équipe A'},
      'version': 4,
      'do_not_contact': true,
      'created_at': '2026-11-20T08:00:00Z',
      'updated_at': '2026-11-21T08:00:00Z',
    });
    check(
      fromApi.teamName == 'Équipe A' && fromApi.version == 4 && !fromApi.canBeContacted && fromApi.syncState == SyncState.synced,
      'Contact.fromApi',
    );
    check(c.copyWith(status: ContactStatus.contacte).status == ContactStatus.contacte, 'copyWith');

    final f = FollowUp(
      uuid: 'f1',
      contactUuid: 'u1',
      actionType: FollowUpActionType.appel,
      scheduledAt: DateTime.now().subtract(const Duration(days: 2)),
      createdAt: now,
    );
    final fb = FollowUp.fromDb(f.toDb());
    check(fb.isOverdue && !fb.isDone && fb.actionType == FollowUpActionType.appel, 'FollowUp aller-retour + retard');

    final u = AppUser.fromJson(
      AppUser(
        id: 1,
        name: 'X',
        username: 'x',
        permissions: ['contacts.create'],
        teams: [UserTeam(id: 2, name: 'T')],
      ).toJson(),
    );
    check(u.can('contacts.create') && !u.can('contacts.delete') && u.primaryTeam?.id == 2, 'AppUser JSON + permissions');
  });
}
