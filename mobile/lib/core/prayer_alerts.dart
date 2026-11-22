import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/prayer.dart';

/// Alertes sonores de la chaîne de prière, programmées SUR LE TÉLÉPHONE :
/// elles sonnent même application fermée, écran verrouillé ou sans Internet.
///
/// Pour chacun de mes créneaux :
///  - 10 min avant : « Votre créneau commence dans 10 minutes » ;
///  - au début, puis +2, +5 et +10 min : « C'est votre tour : prenez la main »
///    (annulées dès que je prends la main) ;
///  - X min avant la fin (réglé par l'organisateur) : « Votre temps finit dans X minutes » ;
///  - à la fin : « Votre temps de prière est terminé ».
class PrayerAlerts {
  PrayerAlerts._();
  static final instance = PrayerAlerts._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  AndroidScheduleMode _mode = AndroidScheduleMode.exactAllowWhileIdle;

  static const _channel = AndroidNotificationDetails(
    'chaine_priere',
    'Chaîne de prière',
    channelDescription: 'Début et fin de vos créneaux, prise de main',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    category: AndroidNotificationCategory.alarm,
    ticker: 'Chaîne de prière',
  );
  static const _details = NotificationDetails(
    android: _channel,
    iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true, presentBanner: true),
  );

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    _ready = true;
  }

  /// Programme (ou reprogramme) les alertes de mes créneaux pour une session.
  Future<void> scheduleFor(PrayerLiveState state, int myUserId) async {
    await init();
    if (!_ready) return;
    final now = DateTime.now();
    final warn = state.session.endWarningMinutes;
    final current = state.currentTurn;

    for (final slot in state.slots.where((s) => s.person.id == myUserId && !s.isPast(state.now))) {
      final holdingHand = current != null && current.person.id == myUserId && current.slotUuid == slot.uuid;
      final title = state.session.title;

      await _at(
        slot,
        0,
        slot.startsAt.subtract(const Duration(minutes: 10)),
        title,
        'Votre créneau commence dans 10 minutes.',
        now,
      );

      for (final (i, delay) in const [(1, 0), (2, 2), (3, 5), (4, 10)]) {
        if (holdingHand) {
          await _plugin.cancel(_id(slot, i));
        } else {
          await _at(
            slot,
            i,
            slot.startsAt.add(Duration(minutes: delay)),
            title,
            'C’est votre tour : veuillez prendre la main 🔥',
            now,
          );
        }
      }

      if (warn > 0 && slot.endsAt.difference(slot.startsAt).inMinutes > warn) {
        await _at(
          slot,
          5,
          slot.endsAt.subtract(Duration(minutes: warn)),
          title,
          'Votre temps finit dans $warn minute${warn > 1 ? 's' : ''}.',
          now,
        );
      }
      await _at(slot, 6, slot.endsAt, title, 'Votre temps de prière est terminé. Merci 🙏', now);
    }
  }

  /// Dès que je prends la main : plus besoin de me rappeler de la prendre.
  Future<void> cancelTakeReminders(PrayerSlot slot) async {
    if (!_ready) return;
    for (var i = 1; i <= 4; i++) {
      await _plugin.cancel(_id(slot, i));
    }
  }

  /// Alerte immédiate (ex. « Veuillez prendre la main » pendant que l'écran est ouvert).
  Future<void> showNow(String title, String body) async {
    await init();
    if (!_ready) return;
    await HapticFeedback.heavyImpact();
    await _plugin.show(9999, title, body, _details);
  }

  Future<void> _at(PrayerSlot slot, int kind, DateTime when, String title, String body, DateTime now) async {
    final id = _id(slot, kind);
    if (!when.isAfter(now)) {
      await _plugin.cancel(id);
      return;
    }
    final at = tz.TZDateTime.from(when.toUtc(), tz.UTC);
    try {
      await _plugin.zonedSchedule(id, title, body, at, _details, androidScheduleMode: _mode);
    } on PlatformException {
      // Alarmes exactes refusées par le téléphone : on passe en mode approximatif.
      _mode = AndroidScheduleMode.inexactAllowWhileIdle;
      await _plugin.zonedSchedule(id, title, body, at, _details, androidScheduleMode: _mode);
    }
  }

  /// Identifiant stable par créneau et type d'alerte (reprogrammer remplace au lieu de dupliquer).
  static int _id(PrayerSlot slot, int kind) {
    var h = 0x811C9DC5; // FNV-1a : même valeur à chaque lancement, contrairement à hashCode.
    for (final c in slot.uuid.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
    }
    return (h & 0x0FFFFFFF) * 8 + kind;
  }
}
