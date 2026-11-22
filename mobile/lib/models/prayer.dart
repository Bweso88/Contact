import 'enums.dart';

/// Animation choisie pour un tour de prière (miroir de App\Enums\PrayerVisual).
enum PrayerVisual implements ApiEnum {
  feu('feu', 'Feu'),
  eau('eau', 'Eau');

  const PrayerVisual(this.value, this.label);
  @override
  final String value;
  @override
  final String label;

  static PrayerVisual from(Object? v) => enumFromValue(values, v, feu);
}

DateTime _d(Object? v) => DateTime.parse(v as String).toLocal();
DateTime? _dn(Object? v) => v == null ? null : _d(v);

class PrayerPerson {
  const PrayerPerson({required this.id, required this.name, this.assembly});

  final int id;
  final String name;

  /// Assemblée de l'intercesseur, affichée pendant qu'il prie.
  final String? assembly;

  String get initials => name.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join().toUpperCase();

  factory PrayerPerson.fromJson(Map<String, dynamic> j) =>
      PrayerPerson(id: j['id'] as int, name: j['name'] as String, assembly: j['assembly'] as String?);
}

class PrayerSession {
  const PrayerSession({
    required this.uuid,
    required this.title,
    this.description,
    required this.startsAt,
    required this.endsAt,
    this.endWarningMinutes = 5,
    this.whatsappGroupUrl,
    this.liveTurn,
  });

  final String uuid;
  final String title;
  final String? description;
  final DateTime startsAt;
  final DateTime endsAt;

  /// Alerte « votre temps finit dans X min », réglée par l'organisateur.
  final int endWarningMinutes;
  final String? whatsappGroupUrl;

  /// Tour en cours (pour l'aperçu dans la liste).
  final PrayerTurn? liveTurn;

  bool isLive(DateTime now) => !now.isBefore(startsAt) && now.isBefore(endsAt);

  factory PrayerSession.fromJson(Map<String, dynamic> j) => PrayerSession(
    uuid: j['uuid'] as String,
    title: j['title'] as String,
    description: j['description'] as String?,
    startsAt: _d(j['starts_at']),
    endsAt: _d(j['ends_at']),
    endWarningMinutes: (j['end_warning_minutes'] as int?) ?? 5,
    whatsappGroupUrl: j['whatsapp_group_url'] as String?,
    liveTurn: j['current_turn'] == null ? null : PrayerTurn.fromJson(j['current_turn'] as Map<String, dynamic>),
  );
}

class PrayerSlot {
  const PrayerSlot({required this.uuid, required this.person, required this.startsAt, required this.endsAt});

  final String uuid;
  final PrayerPerson person;
  final DateTime startsAt;
  final DateTime endsAt;

  /// On peut prendre la main 10 minutes avant le début de son créneau (même règle que le serveur).
  static const earlyStart = Duration(minutes: 10);

  bool covers(DateTime t) => !t.isBefore(startsAt) && t.isBefore(endsAt);
  bool isOpenAt(DateTime t) => !t.isBefore(startsAt.subtract(earlyStart)) && t.isBefore(endsAt);
  bool isPast(DateTime t) => !t.isBefore(endsAt);

  factory PrayerSlot.fromJson(Map<String, dynamic> j) => PrayerSlot(
    uuid: j['uuid'] as String,
    person: PrayerPerson.fromJson(j['user'] as Map<String, dynamic>),
    startsAt: _d(j['starts_at']),
    endsAt: _d(j['ends_at']),
  );
}

class PrayerTurn {
  const PrayerTurn({
    required this.uuid,
    required this.person,
    required this.visual,
    required this.startedAt,
    this.endedAt,
    this.slotUuid,
    this.autoEnded = false,
  });

  final String uuid;
  final PrayerPerson person;
  final PrayerVisual visual;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? slotUuid;

  /// Clos automatiquement à la fin du créneau.
  final bool autoEnded;

  bool get isOpen => endedAt == null;
  Duration duration(DateTime now) => (endedAt ?? now).difference(startedAt);

  factory PrayerTurn.fromJson(Map<String, dynamic> j) => PrayerTurn(
    uuid: j['uuid'] as String,
    person: PrayerPerson.fromJson(j['user'] as Map<String, dynamic>),
    visual: PrayerVisual.from(j['visual']),
    startedAt: _d(j['started_at']),
    endedAt: _dn(j['ended_at']),
    slotUuid: j['slot_uuid'] as String?,
    autoEnded: (j['auto_ended'] as bool?) ?? false,
  );
}

class PrayerMessage {
  const PrayerMessage({required this.uuid, required this.person, required this.body, required this.createdAt});

  final String uuid;
  final PrayerPerson person;
  final String body;
  final DateTime createdAt;

  factory PrayerMessage.fromJson(Map<String, dynamic> j) => PrayerMessage(
    uuid: j['uuid'] as String,
    person: PrayerPerson.fromJson(j['user'] as Map<String, dynamic>),
    body: j['body'] as String,
    createdAt: _d(j['created_at']),
  );
}

/// État complet d'une session à un instant : ce que voit la salle de prière.
class PrayerLiveState {
  const PrayerLiveState({
    required this.session,
    required this.slots,
    required this.turns,
    required this.messages,
    required this.now,
  });

  final PrayerSession session;
  final List<PrayerSlot> slots;

  /// Tours terminés et tour en cours, du plus ancien au plus récent.
  final List<PrayerTurn> turns;

  /// Messages, du plus récent au plus ancien.
  final List<PrayerMessage> messages;

  /// Heure de référence (heure du serveur en mode connecté).
  final DateTime now;

  PrayerTurn? get currentTurn {
    for (final t in turns.reversed) {
      if (t.isOpen) return t;
    }
    return null;
  }

  PrayerSlot? get currentSlot {
    for (final s in slots) {
      if (s.covers(now)) return s;
    }
    return null;
  }

  PrayerSlot? nextSlotOf(int userId) {
    for (final s in slots) {
      if (s.person.id == userId && !s.isPast(now)) return s;
    }
    return null;
  }

  PrayerSlot? openSlotOf(int userId) {
    for (final s in slots) {
      if (s.person.id == userId && s.isOpenAt(now)) return s;
    }
    return null;
  }

  /// Dernier tour terminé (pour afficher « … a fini de prier »).
  PrayerTurn? get lastFinishedTurn {
    for (final t in turns.reversed) {
      if (!t.isOpen) return t;
    }
    return null;
  }

  /// La main est libre alors qu'un créneau a commencé : « Veuillez prendre la main ».
  bool get waitingForHand => currentTurn == null && currentSlot != null;

  /// Temps restant dans le créneau du tour en cours.
  Duration? remainingFor(PrayerTurn turn) {
    for (final s in slots) {
      if (s.uuid == turn.slotUuid) return s.endsAt.difference(now);
    }
    return null;
  }

  /// Minutes réellement priées pendant un créneau.
  Duration prayedDuring(PrayerSlot slot) =>
      turns.where((t) => t.slotUuid == slot.uuid).fold(Duration.zero, (sum, t) => sum + t.duration(now));
}
