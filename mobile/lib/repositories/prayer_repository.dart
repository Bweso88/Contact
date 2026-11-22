import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/config.dart';
import '../models/app_user.dart';
import '../models/prayer.dart';
import '../services/api_client.dart';
import '../services/auth_controller.dart';

/// Chaîne de prière : contrairement aux contacts, tout se passe EN DIRECT
/// (il faut voir qui prie maintenant), donc une connexion est nécessaire.
abstract class PrayerRepository {
  Future<List<PrayerSession>> sessions();

  /// État de la session, rafraîchi en continu.
  Stream<PrayerLiveState> watch(String sessionUuid);

  Future<void> takeHand(String sessionUuid, PrayerVisual visual);
  Future<void> releaseHand(String sessionUuid);
  Future<void> sendMessage(String sessionUuid, String body);

  /// Personnes pouvant recevoir un créneau (intercesseurs).
  Future<List<PrayerPerson>> intercessors();

  Future<String> createSession({
    required String title,
    String? description,
    String? whatsappGroupUrl,
    int endWarningMinutes = 5,
    required List<({int userId, DateTime startsAt, DateTime endsAt})> slots,
  });
}

class PrayerException implements Exception {
  const PrayerException(this.message);
  final String message;
  @override
  String toString() => message;
}

// ── Mode connecté : API Laravel, interrogée toutes les 4 secondes ──

class ApiPrayerRepository implements PrayerRepository {
  ApiPrayerRepository(this._api);

  final ApiClient _api;
  static const pollInterval = Duration(seconds: 4);

  @override
  Future<List<PrayerSession>> sessions() async {
    final res = await _api.get('/api/prayer-sessions');
    return (res['data'] as List).map((j) => PrayerSession.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Stream<PrayerLiveState> watch(String sessionUuid) async* {
    var received = false;
    while (true) {
      try {
        final res = await _api.get('/api/prayer-sessions/$sessionUuid/live');
        final serverNow = DateTime.parse(res['server_time'] as String).toLocal();
        received = true;
        yield PrayerLiveState(
          session: PrayerSession.fromJson(res['session'] as Map<String, dynamic>),
          slots: (res['slots'] as List).map((j) => PrayerSlot.fromJson(j as Map<String, dynamic>)).toList(),
          turns: (res['turns'] as List).map((j) => PrayerTurn.fromJson(j as Map<String, dynamic>)).toList(),
          messages: (res['messages'] as List).map((j) => PrayerMessage.fromJson(j as Map<String, dynamic>)).toList(),
          now: serverNow,
        );
      } on ApiException {
        // Coupure passagère : on garde le dernier état affiché et on réessaie.
        if (!received) rethrow;
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  @override
  Future<void> takeHand(String sessionUuid, PrayerVisual visual) =>
      _wrap(() => _api.post('/api/prayer-sessions/$sessionUuid/take', {'visual': visual.value}));

  @override
  Future<void> releaseHand(String sessionUuid) => _wrap(() => _api.post('/api/prayer-sessions/$sessionUuid/release'));

  @override
  Future<void> sendMessage(String sessionUuid, String body) =>
      _wrap(() => _api.post('/api/prayer-sessions/$sessionUuid/messages', {'body': body}));

  @override
  Future<List<PrayerPerson>> intercessors() async {
    final res = await _api.get('/api/prayer-sessions/intercessors');
    return (res['data'] as List).map((j) => PrayerPerson.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<String> createSession({
    required String title,
    String? description,
    String? whatsappGroupUrl,
    int endWarningMinutes = 5,
    required List<({int userId, DateTime startsAt, DateTime endsAt})> slots,
  }) async {
    final res = await _api.post('/api/prayer-sessions', {
      'title': title,
      'description': description,
      'whatsapp_group_url': whatsappGroupUrl,
      'end_warning_minutes': endWarningMinutes,
      'slots': [
        for (final s in slots)
          {'user_id': s.userId, 'starts_at': s.startsAt.toUtc().toIso8601String(), 'ends_at': s.endsAt.toUtc().toIso8601String()},
      ],
    });
    return (res['data'] as Map<String, dynamic>)['uuid'] as String;
  }

  Future<void> _wrap(Future<Object?> Function() call) async {
    try {
      await call();
    } on ApiException catch (e) {
      throw PrayerException(e.message);
    }
  }
}

// ── Mode démonstration : tout en mémoire, de faux intercesseurs prient ──

class DemoPrayerRepository implements PrayerRepository {
  DemoPrayerRepository(this._me) {
    _seed();
  }

  final AppUser _me;
  static const _uuid = Uuid();

  final _sessions = <PrayerSession>[];
  final _slots = <String, List<PrayerSlot>>{};
  final _turns = <String, List<PrayerTurn>>{};
  final _messages = <String, List<PrayerMessage>>{};
  final _changes = StreamController<String>.broadcast();

  /// En démo, un faux intercesseur attend 45 s avant de prendre la main :
  /// le temps de voir « Veuillez prendre la main ».
  static const _fakeDelay = Duration(seconds: 45);

  static const _people = [
    PrayerPerson(id: 101, name: 'Grâce Mabiala', assembly: 'Assemblée de Mafouta'),
    PrayerPerson(id: 102, name: 'Marc Nkounkou', assembly: 'Assemblée de Mansimou'),
    PrayerPerson(id: 103, name: 'Prisca Malonga', assembly: 'Assemblée de Kinsoundi'),
    PrayerPerson(id: 104, name: 'Jonathan Bouesso', assembly: 'Assemblée de Mafouta'),
    PrayerPerson(id: 105, name: 'Merveille Samba', assembly: 'Assemblée de Moukondo'),
  ];

  PrayerPerson get _mePerson => PrayerPerson(id: _me.id, name: _me.name, assembly: 'Assemblée de Mafouta');

  PrayerSlot _slot(PrayerPerson p, DateTime start, Duration length) =>
      PrayerSlot(uuid: _uuid.v4(), person: p, startsAt: start, endsAt: start.add(length));

  void _add(
    PrayerSession s,
    List<PrayerSlot> slots, {
    List<PrayerTurn> turns = const [],
    List<PrayerMessage> messages = const [],
  }) {
    _sessions.add(s);
    _slots[s.uuid] = slots;
    _turns[s.uuid] = [...turns];
    _messages[s.uuid] = [...messages];
  }

  void _seed() {
    final now = DateTime.now();

    // 1. Essai rapide : créneaux de 3 minutes, alerte 1 minute avant la fin.
    final t0 = now.add(const Duration(minutes: 1));
    const len = Duration(minutes: 3);
    final essai = [_slot(_mePerson, t0, len), _slot(_people[1], t0.add(len), len), _slot(_people[2], t0.add(len * 2), len)];
    _add(
      PrayerSession(
        uuid: _uuid.v4(),
        title: 'Essai — créneaux de 3 minutes',
        description: 'Pour tester les alertes : votre tour commence dans 1 minute.',
        startsAt: t0,
        endsAt: t0.add(len * 3),
        endWarningMinutes: 1,
      ),
      essai,
      messages: [
        PrayerMessage(
          uuid: _uuid.v4(),
          person: _people[1],
          body: 'Testons la chaîne ! Prends la main quand ton tour sonne.',
          createdAt: now,
        ),
      ],
    );

    // 2. Ce soir : Grâce a prié, c'est maintenant votre créneau, puis Marc, puis Prisca.
    final start = DateTime(now.year, now.month, now.day, now.hour).subtract(const Duration(hours: 1));
    final mine = PrayerSlot(
      uuid: _uuid.v4(),
      person: _mePerson,
      startsAt: now.subtract(const Duration(minutes: 5)),
      endsAt: now.add(const Duration(minutes: 55)),
    );
    final grace = PrayerSlot(uuid: _uuid.v4(), person: _people[0], startsAt: start, endsAt: mine.startsAt);
    _add(
      PrayerSession(
        uuid: _uuid.v4(),
        title: 'Chaîne de prière — ce soir',
        description: 'Pour les familles du quartier et les nouveaux venus.',
        startsAt: start,
        endsAt: start.add(const Duration(hours: 4)),
      ),
      [
        grace,
        mine,
        _slot(_people[1], mine.endsAt, const Duration(hours: 1)),
        _slot(
          _people[2],
          mine.endsAt.add(const Duration(hours: 1)),
          start.add(const Duration(hours: 4)).difference(mine.endsAt.add(const Duration(hours: 1))),
        ),
      ],
      turns: [
        PrayerTurn(
          uuid: _uuid.v4(),
          person: _people[0],
          visual: PrayerVisual.eau,
          startedAt: start.add(const Duration(minutes: 2)),
          endedAt: mine.startsAt,
          autoEnded: true,
          slotUuid: grace.uuid,
        ),
      ],
      messages: [
        PrayerMessage(
          uuid: _uuid.v4(),
          person: _people[0],
          body: 'J’ai prié pour la santé de maman Bouesso. À toi la main 🙏',
          createdAt: mine.startsAt,
        ),
        PrayerMessage(
          uuid: _uuid.v4(),
          person: _people[1],
          body: 'Sujet de ce soir : les jeunes du quartier Mafouta.',
          createdAt: start,
        ),
      ],
    );

    // 3. Demain soir.
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 21);
    _add(
      PrayerSession(
        uuid: _uuid.v4(),
        title: 'Veillée du vendredi',
        startsAt: tomorrow,
        endsAt: tomorrow.add(const Duration(hours: 3)),
        endWarningMinutes: 10,
      ),
      [
        for (var i = 0; i < 3; i++)
          _slot(i == 1 ? _mePerson : _people[i + 2], tomorrow.add(Duration(hours: i)), const Duration(hours: 1)),
      ],
    );
  }

  /// Fait vivre la démo : fin automatique des créneaux et faux intercesseurs qui prennent la main.
  void _advance(String uuid) {
    final now = DateTime.now();
    final turns = _turns[uuid]!;
    final slots = _slots[uuid]!;

    // Fin du créneau : « il a fini de prier ».
    final i = turns.indexWhere((t) => t.isOpen);
    if (i >= 0) {
      final t = turns[i];
      final slot = slots.where((s) => s.uuid == t.slotUuid).firstOrNull;
      if (slot != null && !now.isBefore(slot.endsAt)) {
        turns[i] = PrayerTurn(
          uuid: t.uuid,
          person: t.person,
          visual: t.visual,
          startedAt: t.startedAt,
          endedAt: slot.endsAt,
          slotUuid: t.slotUuid,
          autoEnded: true,
        );
      }
    }

    // Main libre pendant le créneau d'un faux intercesseur : il la prend après un moment.
    if (turns.any((t) => t.isOpen)) return;
    final current = slots.where((s) => s.covers(now)).firstOrNull;
    if (current == null || current.person.id == _me.id) return;
    final lastEnd = turns.isEmpty ? current.startsAt : turns.last.endedAt ?? current.startsAt;
    final waitingSince = lastEnd.isAfter(current.startsAt) ? lastEnd : current.startsAt;
    if (now.difference(waitingSince) < _fakeDelay) return;

    final visual = current.person.id.isEven ? PrayerVisual.eau : PrayerVisual.feu;
    turns.add(PrayerTurn(uuid: _uuid.v4(), person: current.person, visual: visual, startedAt: now, slotUuid: current.uuid));
    _messages[uuid]!.insert(
      0,
      PrayerMessage(uuid: _uuid.v4(), person: current.person, body: 'Je prends la main 🙏', createdAt: now),
    );
  }

  PrayerLiveState _state(String uuid) {
    _advance(uuid);
    final turns = _turns[uuid]!;
    final open = turns.where((t) => t.isOpen).firstOrNull;
    final s = _sessions.firstWhere((x) => x.uuid == uuid);
    return PrayerLiveState(
      session: PrayerSession(
        uuid: s.uuid,
        title: s.title,
        description: s.description,
        startsAt: s.startsAt,
        endsAt: s.endsAt,
        endWarningMinutes: s.endWarningMinutes,
        whatsappGroupUrl: s.whatsappGroupUrl,
        liveTurn: open,
      ),
      slots: List.unmodifiable(_slots[uuid]!),
      turns: List.unmodifiable(turns),
      messages: List.unmodifiable(_messages[uuid]!),
      now: DateTime.now(),
    );
  }

  @override
  Future<List<PrayerSession>> sessions() async => [for (final s in _sessions) _state(s.uuid).session];

  @override
  Stream<PrayerLiveState> watch(String sessionUuid) async* {
    yield _state(sessionUuid);
    // Un rafraîchissement par seconde (chronomètre) + immédiat à chaque action.
    final ticks = Stream<String>.periodic(const Duration(seconds: 1), (_) => sessionUuid);
    await for (final _ in StreamGroup2.merge([ticks, _changes.stream.where((u) => u == sessionUuid)])) {
      yield _state(sessionUuid);
    }
  }

  @override
  Future<void> takeHand(String sessionUuid, PrayerVisual visual) async {
    final st = _state(sessionUuid);
    final current = st.currentTurn;
    if (current != null) {
      throw PrayerException(
        current.person.id == _me.id ? 'Vous tenez déjà la main.' : '${current.person.name} prie en ce moment.',
      );
    }
    final slot = st.openSlotOf(_me.id);
    if (slot == null && !_me.can('prayer.manage')) {
      throw const PrayerException('Ce n’est pas encore votre créneau de prière.');
    }
    _turns[sessionUuid]!.add(
      PrayerTurn(uuid: _uuid.v4(), person: _mePerson, visual: visual, startedAt: DateTime.now(), slotUuid: slot?.uuid),
    );
    _changes.add(sessionUuid);
  }

  @override
  Future<void> releaseHand(String sessionUuid) async {
    final list = _turns[sessionUuid]!;
    final i = list.indexWhere((t) => t.isOpen && t.person.id == _me.id);
    if (i < 0) return;
    final t = list[i];
    list[i] = PrayerTurn(
      uuid: t.uuid,
      person: t.person,
      visual: t.visual,
      startedAt: t.startedAt,
      endedAt: DateTime.now(),
      slotUuid: t.slotUuid,
    );
    _changes.add(sessionUuid);
  }

  @override
  Future<void> sendMessage(String sessionUuid, String body) async {
    _messages[sessionUuid]!.insert(0, PrayerMessage(uuid: _uuid.v4(), person: _mePerson, body: body, createdAt: DateTime.now()));
    _changes.add(sessionUuid);
  }

  @override
  Future<List<PrayerPerson>> intercessors() async => [_mePerson, ..._people];

  @override
  Future<String> createSession({
    required String title,
    String? description,
    String? whatsappGroupUrl,
    int endWarningMinutes = 5,
    required List<({int userId, DateTime startsAt, DateTime endsAt})> slots,
  }) async {
    final people = await intercessors();
    final sorted = [...slots]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final s = PrayerSession(
      uuid: _uuid.v4(),
      title: title,
      description: description,
      whatsappGroupUrl: whatsappGroupUrl,
      endWarningMinutes: endWarningMinutes,
      startsAt: sorted.first.startsAt,
      endsAt: sorted.last.endsAt,
    );
    _add(s, [
      for (final x in sorted)
        PrayerSlot(uuid: _uuid.v4(), person: people.firstWhere((p) => p.id == x.userId), startsAt: x.startsAt, endsAt: x.endsAt),
    ]);
    _sessions.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return s.uuid;
  }
}

/// Fusion minimale de flux (évite une dépendance à package:async).
abstract final class StreamGroup2 {
  static Stream<T> merge<T>(List<Stream<T>> streams) {
    late StreamController<T> controller;
    final subs = <StreamSubscription<T>>[];
    controller = StreamController<T>(
      onListen: () {
        for (final s in streams) {
          subs.add(s.listen(controller.add, onError: controller.addError));
        }
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return controller.stream;
  }
}

/// Un seul dépôt par utilisateur connecté (la démo garde son état en mémoire).
final prayerRepositoryProvider = Provider<PrayerRepository>((ref) {
  final user = ref.watch(currentUserProvider);
  if (AppConfig.isDemo) {
    return DemoPrayerRepository(user ?? const AppUser(id: 0, name: 'Démo', username: 'demo'));
  }
  return ApiPrayerRepository(ref.watch(apiClientProvider));
});

final prayerSessionsProvider = FutureProvider.autoDispose<List<PrayerSession>>(
  (ref) => ref.watch(prayerRepositoryProvider).sessions(),
);

final prayerLiveProvider = StreamProvider.autoDispose.family<PrayerLiveState, String>(
  (ref, uuid) => ref.watch(prayerRepositoryProvider).watch(uuid),
);
