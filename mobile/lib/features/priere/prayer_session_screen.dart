import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/excel_export.dart';
import '../../core/formatters.dart';
import '../../core/prayer_alerts.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/prayer.dart';
import '../../repositories/prayer_repository.dart';
import '../../services/auth_controller.dart';
import 'prayer_visuals.dart';

/// Couleurs de la salle de prière : fond nuit pour que la flamme rayonne.
abstract final class _Night {
  static const bg = Color(0xFF141B2B);
  static const card = Color(0xFF1F2940);
  static const line = Color(0xFF2E3A55);
  static const text = Color(0xFFF1F5F9);
  static const muted = Color(0xFF94A3B8);
  static const fire = Color(0xFFFF8A3D);
  static const water = Color(0xFF4FC3F7);
}

String _duration(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60;
  return h > 0 ? '$h h ${m.toString().padLeft(2, '0')}' : '${d.inMinutes} min';
}

/// Salle de prière en direct.
class PrayerSessionScreen extends ConsumerStatefulWidget {
  const PrayerSessionScreen({super.key, required this.uuid});

  final String uuid;

  @override
  ConsumerState<PrayerSessionScreen> createState() => _PrayerSessionScreenState();
}

class _PrayerSessionScreenState extends ConsumerState<PrayerSessionScreen> {
  final _message = TextEditingController();
  bool _busy = false;
  String? _scheduledSignature;
  DateTime? _lastNudge;

  /// Reprogramme les alertes quand le planning ou le tour en cours change (pas à chaque seconde).
  void _onState(PrayerLiveState st) {
    final me = ref.read(currentUserProvider);
    if (me == null) return;
    final sig = [
      st.session.endWarningMinutes,
      for (final s in st.slots) '${s.uuid}${s.person.id}${s.startsAt.millisecondsSinceEpoch}${s.endsAt.millisecondsSinceEpoch}',
      st.currentTurn?.uuid,
    ].join('|');
    if (sig != _scheduledSignature) {
      _scheduledSignature = sig;
      unawaited(PrayerAlerts.instance.scheduleFor(st, me.id));
    }

    // Écran ouvert, c'est mon créneau et la main est libre : on insiste toutes les 2 minutes.
    final slot = st.currentSlot;
    if (st.waitingForHand && slot != null && slot.person.id == me.id) {
      final now = DateTime.now();
      if (_lastNudge == null || now.difference(_lastNudge!) > const Duration(minutes: 2)) {
        _lastNudge = now;
        unawaited(PrayerAlerts.instance.showNow(st.session.title, 'C’est votre tour : veuillez prendre la main 🔥'));
      }
    }
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  PrayerRepository get _repo => ref.read(prayerRepositoryProvider);

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on PrayerException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Connexion nécessaire pour la chaîne de prière.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), action: action));
  }

  Future<void> _take() async {
    final visual = await showModalBottomSheet<PrayerVisual>(
      context: context,
      backgroundColor: _Night.card,
      showDragHandle: true,
      builder: (ctx) => const _VisualPicker(),
    );
    if (visual == null) return;
    await _run(() => _repo.takeHand(widget.uuid, visual));
    final st = ref.read(prayerLiveProvider(widget.uuid)).valueOrNull;
    final me = ref.read(currentUserProvider);
    final slot = st == null || me == null ? null : st.openSlotOf(me.id);
    if (slot != null) unawaited(PrayerAlerts.instance.cancelTakeReminders(slot));
  }

  Future<void> _release() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rendre la main ?'),
        content: const Text('La flamme passera à la personne suivante.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continuer à prier')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Je rends la main')),
        ],
      ),
    );
    if (ok == true) await _run(() => _repo.releaseHand(widget.uuid));
  }

  Future<void> _send(PrayerLiveState st) async {
    final body = _message.text.trim();
    if (body.isEmpty) return;
    await _run(() => _repo.sendMessage(widget.uuid, body));
    _message.clear();
    if (mounted) FocusScope.of(context).unfocus();
    _snack(
      'Message publié.',
      action: SnackBarAction(label: 'WhatsApp', onPressed: () => _shareWhatsApp(st, body)),
    );
  }

  /// Ouvre le groupe WhatsApp s'il est configuré, sinon WhatsApp avec un texte prêt à envoyer.
  void _shareWhatsApp(PrayerLiveState st, [String? extra]) {
    final current = st.currentTurn;
    final status = current == null
        ? '🕯 Chaîne de prière « ${st.session.title} » : la main est libre.'
        : '${current.visual == PrayerVisual.feu ? '🔥' : '💧'} ${current.person.name} tient la main depuis ${_duration(current.duration(st.now))} — « ${st.session.title} »';
    final text = [if (extra != null) extra, status].join('\n\n');
    final group = st.session.whatsappGroupUrl;
    final uri = group != null && group.isNotEmpty && extra == null ? Uri.parse(group) : Uri.https('wa.me', '/', {'text': text});
    unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
  }

  Future<void> _export(PrayerLiveState st) => ExcelExport.share(
    context,
    fileName: st.session.title,
    sheets: [
      ExportSheet(
        'Planning',
        const ['Début', 'Fin', 'Intercesseur', 'Assemblée', 'Temps prié (min)', 'Situation'],
        [
          for (final sl in st.slots)
            [
              sl.startsAt,
              sl.endsAt,
              sl.person.name,
              sl.person.assembly,
              st.prayedDuring(sl).inMinutes,
              st.currentTurn?.slotUuid == sl.uuid
                  ? 'Prie maintenant'
                  : sl.isPast(st.now)
                  ? (st.prayedDuring(sl) > Duration.zero ? 'A fini de prier' : 'Créneau non tenu')
                  : 'À venir',
            ],
        ],
      ),
      ExportSheet(
        'Tours de prière',
        const ['Intercesseur', 'Assemblée', 'Feu / eau', 'Début', 'Fin', 'Durée (min)', 'Fin automatique'],
        [
          for (final t in st.turns)
            [t.person.name, t.person.assembly, t.visual.label, t.startedAt, t.endedAt, t.duration(st.now).inMinutes, t.autoEnded],
        ],
      ),
      ExportSheet(
        'Messages',
        const ['Date', 'Auteur', 'Message'],
        [
          for (final m in st.messages.reversed) [m.createdAt, m.person.name, m.body],
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(prayerLiveProvider(widget.uuid));
    final me = ref.watch(currentUserProvider);
    ref.listen(prayerLiveProvider(widget.uuid), (_, next) {
      final st = next.valueOrNull;
      if (st != null) _onState(st);
    });

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _Night.bg,
        appBarTheme: Theme.of(context).appBarTheme.copyWith(backgroundColor: _Night.bg, foregroundColor: _Night.text),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(live.valueOrNull?.session.title ?? 'Chaîne de prière', style: HF.heading(18, color: _Night.text)),
          actions: [
            if (live.valueOrNull != null && (me?.can('prayer.manage') ?? false))
              ExportButton(onPressed: () => _export(live.value!)),
            if (live.valueOrNull != null)
              IconButton(
                tooltip: 'Partager sur WhatsApp',
                icon: const Icon(Icons.share_outlined),
                onPressed: () => _shareWhatsApp(live.value!),
              ),
          ],
        ),
        body: live.when(
          loading: () => const Center(child: CircularProgressIndicator(color: _Night.fire)),
          error: (e, _) => _Offline(onRetry: () => ref.invalidate(prayerLiveProvider(widget.uuid))),
          data: (st) => me == null ? const SizedBox.shrink() : _content(st, me),
        ),
      ),
    );
  }

  Widget _content(PrayerLiveState st, AppUser me) {
    final current = st.currentTurn;
    final mine = current != null && current.person.id == me.id;
    final mySlot = st.openSlotOf(me.id);
    final nextMine = st.nextSlotOf(me.id);
    final canManage = me.can('prayer.manage');
    final accent = current?.visual == PrayerVisual.eau ? _Night.water : _Night.fire;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Center(
          child: Text(
            '${formatDate(st.session.startsAt)} · ${formatTime(st.session.startsAt)} – ${formatTime(st.session.endsAt)}',
            style: const TextStyle(color: _Night.muted),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: PrayerVisualView(visual: current?.visual, size: MediaQuery.of(context).size.width * 0.72),
        ),
        const SizedBox(height: 4),
        if (current != null) ...[
          Text(
            mine ? 'Vous tenez la main' : current.person.name,
            textAlign: TextAlign.center,
            style: HF.heading(26, color: _Night.text),
          ),
          if (current.person.assembly != null)
            Text(
              current.person.assembly!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _Night.text, fontSize: 15),
            ),
          const SizedBox(height: 4),
          Text(
            '${mine ? 'Vous priez' : 'prie'} depuis ${_duration(current.duration(st.now))} · ${current.visual.label}',
            textAlign: TextAlign.center,
            style: TextStyle(color: accent, fontWeight: FontWeight.w600, fontSize: 15),
          ),
          if (st.remainingFor(current) case final left? when !left.isNegative) ...[
            const SizedBox(height: 10),
            Center(
              child: _RemainingPill(
                left: left,
                warn: Duration(minutes: st.session.endWarningMinutes),
              ),
            ),
          ],
        ] else ...[
          if (st.waitingForHand)
            _WaitingBanner(slot: st.currentSlot!, isMe: st.currentSlot!.person.id == me.id)
          else
            Text(
              'La flamme attend…',
              textAlign: TextAlign.center,
              style: HF.heading(24, color: _Night.text),
            ),
          if (st.lastFinishedTurn case final done? when st.now.difference(done.endedAt!) < const Duration(minutes: 15)) ...[
            const SizedBox(height: 12),
            Text(
              '✓ ${done.person.id == me.id ? 'Vous avez' : '${done.person.name} a'} fini de prier'
              '${done.autoEnded ? ' (temps écoulé)' : ''} · ${_duration(done.duration(st.now))}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF81C784), fontWeight: FontWeight.w600),
            ),
          ],
          if (!st.waitingForHand && st.currentSlot == null) ...[
            const SizedBox(height: 4),
            const Text(
              'Aucun créneau en ce moment.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _Night.muted),
            ),
          ],
        ],
        const SizedBox(height: 24),
        _actions(st, me, current, mine, mySlot, nextMine, canManage),
        const SizedBox(height: 28),
        _sectionTitle(Icons.calendar_month_outlined, 'Planning'),
        const SizedBox(height: 10),
        for (final s in st.slots) _SlotTile(slot: s, state: st, me: me),
        const SizedBox(height: 24),
        _sectionTitle(Icons.forum_outlined, 'Messages'),
        const SizedBox(height: 10),
        _composer(st),
        const SizedBox(height: 12),
        if (st.messages.isEmpty) const Text('Aucun message pour l’instant.', style: TextStyle(color: _Night.muted)),
        for (final m in st.messages) _MessageTile(message: m, isMe: m.person.id == me.id, now: st.now),
      ],
    );
  }

  Widget _actions(
    PrayerLiveState st,
    AppUser me,
    PrayerTurn? current,
    bool mine,
    PrayerSlot? mySlot,
    PrayerSlot? nextMine,
    bool canManage,
  ) {
    if (mine) {
      return _BigButton(label: 'Je rends la main', icon: Icons.front_hand_outlined, filled: false, busy: _busy, onTap: _release);
    }
    if (current == null && (mySlot != null || canManage)) {
      return Column(
        children: [
          _BigButton(label: 'Je prends la main', icon: Icons.local_fire_department, busy: _busy, onTap: _take),
          if (mySlot == null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Hors créneau : autorisé car vous êtes responsable.',
                style: TextStyle(color: _Night.muted, fontSize: 12),
              ),
            ),
        ],
      );
    }
    final String info;
    if (mySlot != null && current != null) {
      info = '${current.person.name} prie encore. La main vous reviendra dès qu’elle sera rendue.';
    } else if (nextMine != null) {
      final wait = nextMine.startsAt.difference(st.now);
      info =
          'Votre créneau : ${formatTime(nextMine.startsAt)} – ${formatTime(nextMine.endsAt)}'
          '${wait.isNegative ? '' : ' (dans ${_duration(wait)})'}';
    } else {
      info = 'Vous n’avez pas de créneau dans cette chaîne. Vous pouvez soutenir par vos messages.';
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Night.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Night.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: _Night.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(info, style: const TextStyle(color: _Night.text)),
          ),
        ],
      ),
    );
  }

  Widget _composer(PrayerLiveState st) => Row(
    children: [
      Expanded(
        child: TextField(
          controller: _message,
          minLines: 1,
          maxLines: 4,
          maxLength: 500,
          style: const TextStyle(color: _Night.text),
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Sujet, encouragement…',
            hintStyle: const TextStyle(color: _Night.muted),
            counterText: '',
            filled: true,
            fillColor: _Night.card,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _Night.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _Night.fire, width: 2),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      IconButton.filled(
        tooltip: 'Publier',
        style: IconButton.styleFrom(backgroundColor: HF.terracotta, minimumSize: const Size(52, 52)),
        onPressed: _busy ? null : () => _send(st),
        icon: const Icon(Icons.send, color: Colors.white),
      ),
    ],
  );

  static Widget _sectionTitle(IconData icon, String title) => Row(
    children: [
      Icon(icon, color: _Night.fire, size: 20),
      const SizedBox(width: 8),
      Text(title, style: HF.heading(18, color: _Night.text)),
    ],
  );
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.icon, required this.onTap, this.filled = true, this.busy = false});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: filled ? const [BoxShadow(color: Color(0x66FF6D00), blurRadius: 24, offset: Offset(0, 8))] : null,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 64,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: filled ? const Color(0xFFE65100) : _Night.card,
            foregroundColor: Colors.white,
            side: filled ? null : const BorderSide(color: _Night.fire, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            textStyle: HF.heading(19, color: Colors.white),
          ),
          onPressed: busy ? null : onTap,
          icon: busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Icon(icon, size: 26),
          label: Text(label),
        ),
      ),
    );
  }
}

/// Choix feu / eau au moment de prendre la main.
class _VisualPicker extends StatelessWidget {
  const _VisualPicker();

  @override
  Widget build(BuildContext context) {
    Widget option(PrayerVisual v, String hint) => Expanded(
      child: Material(
        color: _Night.bg,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.pop(context, v),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                PrayerVisualView(visual: v, size: 120),
                Text(v.label, style: HF.heading(18, color: _Night.text)),
                Text(hint, style: const TextStyle(color: _Night.muted, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pendant votre prière', style: HF.heading(20, color: _Night.text)),
            const SizedBox(height: 4),
            const Text('Tous les intercesseurs verront cette animation.', style: TextStyle(color: _Night.muted)),
            const SizedBox(height: 16),
            Row(
              children: [
                option(PrayerVisual.feu, 'Le feu qui brûle'),
                const SizedBox(width: 12),
                option(PrayerVisual.eau, 'L’eau vive'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot, required this.state, required this.me});

  final PrayerSlot slot;
  final PrayerLiveState state;
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    final current = state.currentTurn;
    final praying = current != null && current.slotUuid == slot.uuid;
    final isMe = slot.person.id == me.id;
    final past = slot.isPast(state.now);
    final now = slot.covers(state.now);
    final prayed = state.prayedDuring(slot);

    final (IconData icon, Color color, String status) = praying
        ? (
            current!.visual == PrayerVisual.feu ? Icons.local_fire_department : Icons.water_drop,
            current.visual == PrayerVisual.feu ? _Night.fire : _Night.water,
            'prie maintenant',
          )
        : past
        ? (
            prayed > Duration.zero ? Icons.check_circle : Icons.remove_circle_outline,
            prayed > Duration.zero ? const Color(0xFF66BB6A) : _Night.muted,
            prayed > Duration.zero ? 'a prié ${_duration(prayed)}' : 'créneau non tenu',
          )
        : now
        ? (Icons.hourglass_top, const Color(0xFFFFCA28), 'en attente de prise de main')
        : (Icons.schedule, _Night.muted, 'à venir');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Night.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: praying || now ? color : _Night.line, width: praying || now ? 1.5 : 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatTime(slot.startsAt),
                  style: const TextStyle(color: _Night.text, fontWeight: FontWeight.w700),
                ),
                Text(formatTime(slot.endsAt), style: const TextStyle(color: _Night.muted, fontSize: 12)),
              ],
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: isMe ? HF.terracotta : _Night.line,
            child: Text(
              slot.person.initials,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? 'Vous' : slot.person.name,
                  style: const TextStyle(color: _Night.text, fontWeight: FontWeight.w600),
                ),
                Text(status, style: TextStyle(color: color, fontSize: 13)),
              ],
            ),
          ),
          Icon(icon, color: color),
        ],
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message, required this.isMe, required this.now});

  final PrayerMessage message;
  final bool isMe;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: isMe ? const Color(0xFF3A2A22) : _Night.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isMe ? 'Vous' : message.person.name,
                style: const TextStyle(color: _Night.text, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(formatRelative(message.createdAt), style: const TextStyle(color: _Night.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(message.body, style: const TextStyle(color: _Night.text, height: 1.45)),
        ],
      ),
    );
  }
}

class _Offline extends StatelessWidget {
  const _Offline({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, color: _Night.muted, size: 48),
          const SizedBox(height: 12),
          Text('Connexion nécessaire', style: HF.heading(18, color: _Night.text)),
          const SizedBox(height: 6),
          const Text(
            'La chaîne de prière se vit en direct : il faut Internet pour voir qui tient la main.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _Night.muted),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    ),
  );
}

/// Temps restant dans le créneau ; passe à l'orange quand l'alerte de fin approche.
class _RemainingPill extends StatelessWidget {
  const _RemainingPill({required this.left, required this.warn});

  final Duration left;
  final Duration warn;

  @override
  Widget build(BuildContext context) {
    final urgent = left <= warn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: urgent ? const Color(0xFF4A2A1A) : _Night.card,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: urgent ? _Night.fire : _Night.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(urgent ? Icons.alarm : Icons.timer_outlined, size: 16, color: urgent ? _Night.fire : _Night.muted),
          const SizedBox(width: 6),
          Text(
            left.inMinutes >= 1 ? 'Reste ${_duration(left)}' : 'Reste ${left.inSeconds} s',
            style: TextStyle(color: urgent ? _Night.fire : _Night.text, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// « Veuillez prendre la main » : clignote tant que personne ne la prend.
class _WaitingBanner extends StatefulWidget {
  const _WaitingBanner({required this.slot, required this.isMe});

  final PrayerSlot slot;
  final bool isMe;

  @override
  State<_WaitingBanner> createState() => _WaitingBannerState();
}

class _WaitingBannerState extends State<_WaitingBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.55, end: 1.0).animate(_pulse),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF4A2A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Night.fire, width: 1.5),
        ),
        child: Column(
          children: [
            const Icon(Icons.notifications_active, color: _Night.fire, size: 30),
            const SizedBox(height: 6),
            Text(
              'Veuillez prendre la main',
              textAlign: TextAlign.center,
              style: HF.heading(22, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              widget.isMe
                  ? 'C’est votre créneau (${formatTime(widget.slot.startsAt)} – ${formatTime(widget.slot.endsAt)}).'
                  : 'Créneau de ${widget.slot.person.name}${widget.slot.person.assembly != null ? ' · ${widget.slot.person.assembly}' : ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _Night.text),
            ),
          ],
        ),
      ),
    );
  }
}
