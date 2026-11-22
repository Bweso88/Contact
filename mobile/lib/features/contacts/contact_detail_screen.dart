import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database.dart';
import '../../core/formatters.dart';
import '../../core/launcher.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/contact.dart';
import '../../models/enums.dart';
import '../../models/follow_up.dart';
import '../../models/timeline_item.dart';
import '../../repositories/contact_repository.dart';
import '../../services/sync_service.dart';
import '../suivi/follow_up_sheets.dart';

final contactProvider = FutureProvider.family<Contact?, String>((ref, uuid) {
  ref.watch(dataRevisionProvider);
  return ref.watch(contactRepositoryProvider).find(uuid);
});

final timelineProvider = FutureProvider.family<List<TimelineItem>, String>((ref, uuid) {
  ref.watch(dataRevisionProvider);
  return ref.watch(contactRepositoryProvider).timeline(uuid);
});

final nextFollowUpProvider = FutureProvider.family<FollowUp?, String>((ref, uuid) {
  ref.watch(dataRevisionProvider);
  return ref.watch(contactRepositoryProvider).nextFollowUp(uuid);
});

/// Fiche détaillée (écran « fiche_d_taill_e_contact » de la maquette).
class ContactDetailScreen extends ConsumerWidget {
  const ContactDetailScreen({super.key, required this.uuid});

  final String uuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contact = ref.watch(contactProvider(uuid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiche contact'),
        actions: [
          contact.maybeWhen(
            data: (c) => c == null
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Changer le statut',
                    icon: const Icon(Icons.flag_outlined),
                    onPressed: () => showStatusSheet(context, ref, c),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: contact.when(
        loading: () => const Center(child: CircularProgressIndicator(color: HF.terracotta)),
        error: (e, _) => EmptyState(icon: Icons.error_outline, title: 'Erreur', message: '$e'),
        data: (c) => c == null
            ? const EmptyState(
                icon: Icons.person_off_outlined,
                title: 'Contact introuvable',
                message: 'Il a peut-être été retiré de votre périmètre.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  if (c.syncState == SyncState.conflict) ...[_ConflictBanner(contact: c), const SizedBox(height: 16)],
                  _Header(contact: c),
                  const SizedBox(height: 16),
                  _JourneyCard(contact: c),
                  const SizedBox(height: 16),
                  _NextActionCard(contact: c),
                  const SizedBox(height: 16),
                  _HistoryCard(uuid: c.uuid),
                  const SizedBox(height: 16),
                  _InfoCard(contact: c),
                ],
              ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contact;
    final phone = c.phone;
    final reachable = c.canBeContacted && phone != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(HF.cardRadius),
        border: Border.all(color: HF.linen),
        gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.center, colors: [HF.terracottaWash, HF.card]),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InitialsAvatar(c.initials, size: 72),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.fullName, style: HF.heading(22)),
                    const SizedBox(height: 6),
                    StatusPill(c.status),
                    const SizedBox(height: 8),
                    if (c.neighborhood != null)
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 16, color: HF.terracotta),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              [c.neighborhood, c.arrondissement].whereType<String>().join(' · '),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (c.assignedUserName != null) ...[
            const SizedBox(height: 12),
            Pill('Suivi par : ${c.assignedUserName}', bg: HF.sand, icon: Icons.person_outline),
          ],
          if (!c.canBeContacted) ...[
            const SizedBox(height: 12),
            const Pill(
              'Ne souhaite plus être contacté(e) · exclu des relances',
              bg: HF.redWash,
              fg: HF.red,
              icon: Icons.do_not_disturb_on_outlined,
              maxWidth: double.infinity,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ActionTile(
                  vertical: true,
                  icon: Icons.chat_outlined,
                  label: 'WhatsApp',
                  bg: HF.sageWash,
                  fg: HF.sageDark,
                  onTap: reachable ? () => Launcher.whatsapp(context, phone!) : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ActionTile(
                  vertical: true,
                  icon: Icons.call_outlined,
                  label: 'Appeler',
                  onTap: reachable ? () => Launcher.call(context, phone!) : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ActionTile(
                  vertical: true,
                  icon: Icons.sms_outlined,
                  label: 'SMS',
                  onTap: reachable ? () => Launcher.sms(context, phone!) : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ActionTile(
                  vertical: true,
                  icon: Icons.edit_note,
                  label: 'Note',
                  fg: HF.terracottaDark,
                  onTap: () => showFollowUpSheet(context, ref, c, initialType: FollowUpActionType.note),
                ),
              ),
            ],
          ),
          if (phone == null) ...[
            const SizedBox(height: 8),
            const Text('Aucun numéro enregistré.', style: TextStyle(fontSize: 12, color: HF.muted)),
          ],
        ],
      ),
    );
  }
}

/// Frise « Parcours » : du premier contact à l'intégration.
class _JourneyCard extends ConsumerWidget {
  const _JourneyCard({required this.contact});

  final Contact contact;

  static const _steps = [
    ('Rencontre', Icons.handshake_outlined),
    ('Contacté', Icons.call_outlined),
    ('Invité', Icons.mail_outline),
    ('1re visite', Icons.church_outlined),
    ('Accompagné', Icons.volunteer_activism_outlined),
    ('Intégré', Icons.cottage_outlined),
  ];

  /// Position dans la frise ; null pour les statuts « à côté » (pause, injoignable, refus).
  static int? _index(ContactStatus s) => switch (s) {
    ContactStatus.nouveau || ContactStatus.aContacter => 0,
    ContactStatus.contacte => 1,
    ContactStatus.invite => 2,
    ContactStatus.premiereVisite => 3,
    ContactStatus.enAccompagnement => 4,
    ContactStatus.integre => 5,
    _ => null,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = _index(contact.status);

    return HFCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.trending_up,
            title: 'Parcours',
            trailing: idx == null
                ? Pill(contact.status.label, bg: HF.sand, fg: HF.muted)
                : Pill('Étape ${idx + 1} / ${_steps.length}', bg: HF.sageWash, fg: HF.sageDark),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _steps.length; i++) ...[
                  _Step(
                    label: _steps[i].$1,
                    icon: _steps[i].$2,
                    state: idx == null
                        ? _StepState.todo
                        : (i < idx ? _StepState.done : (i == idx ? _StepState.current : _StepState.todo)),
                  ),
                  if (i < _steps.length - 1)
                    Container(
                      width: 18,
                      height: 2,
                      margin: const EdgeInsets.only(top: 21),
                      color: idx != null && i < idx ? HF.sage : HF.linen,
                    ),
                ],
              ],
            ),
          ),
          if (idx == null) ...[
            const SizedBox(height: 12),
            Text(
              contact.status == ContactStatus.injoignable
                  ? 'Plusieurs tentatives sans réponse.'
                  : contact.status == ContactStatus.enPause
                  ? 'Suivi temporairement suspendu.'
                  : 'Suivi arrêté à sa demande.',
              style: const TextStyle(color: HF.muted),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => showStatusSheet(context, ref, contact),
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: const Text('Changer le statut'),
            ),
          ),
        ],
      ),
    );
  }
}

enum _StepState { done, current, todo }

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.icon, required this.state});

  final String label;
  final IconData icon;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData ic) = switch (state) {
      _StepState.done => (HF.sageDark, Colors.white, Icons.check),
      _StepState.current => (HF.terracottaDark, Colors.white, icon),
      _StepState.todo => (HF.sand, HF.muted, icon),
    };
    return SizedBox(
      width: 68,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(ic, color: fg, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: state == _StepState.todo ? FontWeight.w500 : FontWeight.w700,
              color: state == _StepState.current ? HF.terracottaDark : (state == _StepState.done ? HF.sageDark : HF.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextActionCard extends ConsumerWidget {
  const _NextActionCard({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = ref.watch(nextFollowUpProvider(contact.uuid)).valueOrNull;

    return HFCard(
      color: HF.sand,
      borderColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: HF.terracottaDark, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.calendar_month_outlined, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Prochaine action de suivi', style: HF.heading(17, weight: FontWeight.w600)),
                    const Text('Planifier la prochaine étape relationnelle', style: TextStyle(fontSize: 13, color: HF.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (next != null)
            HFCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.alarm, color: next.isOverdue ? HF.red : HF.terracotta),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(next.actionType.label, style: const TextStyle(fontSize: 13, color: HF.muted)),
                        Text(
                          next.isOverdue ? 'En retard · ${formatDateTime(next.scheduledAt!)}' : formatRelative(next.scheduledAt!),
                          style: HF.heading(16, color: next.isOverdue ? HF.red : HF.charcoal),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: HF.sand,
                      foregroundColor: HF.charcoal,
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: () => showCompleteSheet(context, ref, next),
                    child: const Text('Clôturer'),
                  ),
                ],
              ),
            )
          else
            Text(
              contact.canBeContacted
                  ? 'Aucune action programmée.'
                  : 'Aucune relance : la personne ne souhaite plus être contactée.',
              style: const TextStyle(color: HF.muted),
            ),
          if (contact.canBeContacted) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => showFollowUpSheet(context, ref, contact, schedule: true),
              icon: const Icon(Icons.event_available_outlined),
              label: const Text('Programmer un suivi'),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryCard extends ConsumerStatefulWidget {
  const _HistoryCard({required this.uuid});

  final String uuid;

  @override
  ConsumerState<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends ConsumerState<_HistoryCard> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(timelineProvider(widget.uuid)).valueOrNull ?? const [];
    final shown = _all ? items : items.take(6).toList();

    return HFCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.history,
            title: 'Historique',
            trailing: Text(
              '${items.length} élément${items.length > 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 12, color: HF.muted),
            ),
          ),
          if (items.isEmpty) const Text('Rien pour l’instant.', style: TextStyle(color: HF.muted)),
          for (var i = 0; i < shown.length; i++) _TimelineRow(item: shown[i], last: i == shown.length - 1),
          if (items.length > 6)
            Center(
              child: TextButton(
                onPressed: () => setState(() => _all = !_all),
                child: Text(_all ? 'Réduire' : 'Voir tout l’historique'),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item, required this.last});

  final TimelineItem item;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = item.icon == Icons.flag_outlined ? HF.amber : (item.icon == Icons.place_outlined ? HF.terracotta : HF.sage);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Icon(item.icon, size: 14, color: Colors.white),
                ),
                if (!last) Expanded(child: Container(width: 2, color: HF.linen)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        formatRelative(item.date),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                      ),
                      if (item.pendingSync) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.cloud_upload_outlined, size: 13, color: HF.amber),
                      ],
                      const Spacer(),
                      if (item.author != null) Text(item.author!, style: const TextStyle(fontSize: 12, color: HF.muted)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (item.subtitle != null && item.subtitle!.isNotEmpty)
                    Text(item.subtitle!, style: const TextStyle(fontSize: 14, height: 1.45)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final c = contact;
    final wishes = [
      if (c.wantsServiceInvitation == true) 'Invitation au culte',
      if (c.wantsSpiritualSupport == true) 'Accompagnement spirituel',
      if (c.wantsHouseChurch == true) 'Église de maison',
    ];
    final rows = <(IconData, String, String?)>[
      (Icons.phone_outlined, 'Téléphone', c.phone),
      (Icons.forum_outlined, 'Moyen préféré', c.preferredChannel?.label),
      (Icons.alt_route, 'Origine', c.source.label),
      (Icons.event_outlined, 'Première rencontre', formatDate(c.firstMetAt)),
      (Icons.groups_outlined, 'Équipe', c.teamName),
      (Icons.edit_outlined, 'Enregistré par', c.createdByName),
      (Icons.signpost_outlined, 'Indication', c.addressHint),
      (Icons.person_outline, 'Profil', [c.gender?.label, c.ageRange?.label].whereType<String>().join(' · ').ifEmptyNull),
      (Icons.verified_user_outlined, 'Accord de contact', c.canBeContacted ? 'Donné' : 'Refusé ou retiré'),
      (Icons.cloud_outlined, 'Synchronisation', c.syncState.label),
    ];

    return HFCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.info_outline, title: 'Informations'),
          if (wishes.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final w in wishes) Pill(w, bg: HF.sageWash, fg: HF.sageDark, icon: Icons.check)],
            ),
            const SizedBox(height: 12),
          ],
          for (final (icon, label, value) in rows)
            if (value != null && value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: HF.muted),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 130,
                      child: Text(label, style: const TextStyle(color: HF.muted, fontSize: 14)),
                    ),
                    Expanded(
                      child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

extension on String {
  String? get ifEmptyNull => isEmpty ? null : this;
}

/// Conflit de synchronisation : on montre le choix, on n'écrase jamais en silence.
class _ConflictBanner extends ConsumerWidget {
  const _ConflictBanner({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: HF.redWash, borderRadius: BorderRadius.circular(HF.cardRadius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sync_problem, color: HF.red),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Fiche modifiée par quelqu’un d’autre',
                  style: TextStyle(fontWeight: FontWeight.w700, color: HF.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Vos modifications faites hors ligne et celles du serveur se contredisent. Laquelle garder ?'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => ref.read(syncControllerProvider.notifier).resolveConflict(contact, keepMine: false),
                  child: const Text('Version du serveur'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: () => ref.read(syncControllerProvider.notifier).resolveConflict(contact, keepMine: true),
                  child: const Text('Ma version'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
