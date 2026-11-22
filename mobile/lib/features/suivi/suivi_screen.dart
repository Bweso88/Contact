import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database.dart';
import '../../core/excel_export.dart';
import '../../core/formatters.dart';
import '../../core/launcher.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/enums.dart';
import '../../models/follow_up.dart';
import '../../repositories/follow_up_repository.dart';
import '../../services/auth_controller.dart';
import 'follow_up_sheets.dart';

typedef DueQuery = ({FollowUpBucket bucket, bool mineOnly});

final dueFollowUpsProvider = FutureProvider.family<List<FollowUp>, DueQuery>((ref, q) {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(currentUserProvider);
  return ref.watch(followUpRepositoryProvider).due(q.bucket, userId: q.mineOnly ? user?.id : null);
});

/// Relances à faire : en retard, aujourd'hui, à venir.
class SuiviScreen extends ConsumerStatefulWidget {
  const SuiviScreen({super.key});

  @override
  ConsumerState<SuiviScreen> createState() => _SuiviScreenState();
}

class _SuiviScreenState extends ConsumerState<SuiviScreen> {
  bool _mineOnly = true;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final canSeeAll = user?.can('follow_ups.update_all') ?? false;
    final mine = _mineOnly || !canSeeAll;

    final overdue = ref.watch(dueFollowUpsProvider((bucket: FollowUpBucket.overdue, mineOnly: mine))).valueOrNull ?? const [];
    final today = ref.watch(dueFollowUpsProvider((bucket: FollowUpBucket.today, mineOnly: mine))).valueOrNull ?? const [];
    final upcoming = ref.watch(dueFollowUpsProvider((bucket: FollowUpBucket.upcoming, mineOnly: mine))).valueOrNull ?? const [];

    Future<void> export() => ExcelExport.share(
      context,
      fileName: 'Relances',
      sheets: [
        ExportSheet(
          'Relances',
          const ['Échéance', 'Situation', 'Personne', 'Téléphone', 'Action', 'Responsable', 'Commentaire'],
          [
            for (final (label, list) in [('En retard', overdue), ('Aujourd’hui', today), ('À venir', upcoming)])
              for (final f in list)
                [f.scheduledAt, label, f.contactName, f.contactPhone, f.actionType.label, f.userName, f.description],
          ],
        ),
      ],
    );

    return Scaffold(
      appBar: HFTopBar(actions: [if (user?.can('contacts.export') ?? false) ExportButton(onPressed: export)]),
      body: RefreshIndicator(
        color: HF.terracotta,
        onRefresh: () async => ref.read(dataRevisionProvider.notifier).bump(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Text('Suivi', style: HF.heading(26)),
            const SizedBox(height: 4),
            Text(
              overdue.isEmpty && today.isEmpty
                  ? 'Rien d’urgent. Bravo pour la fidélité du suivi !'
                  : '${overdue.length + today.length} relance(s) à faire',
              style: const TextStyle(color: HF.muted),
            ),
            if (canSeeAll) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: [
                  QuickChip(label: 'Mes actions', selected: _mineOnly, onTap: () => setState(() => _mineOnly = true)),
                  QuickChip(label: 'Toute l’église', selected: !_mineOnly, onTap: () => setState(() => _mineOnly = false)),
                ],
              ),
            ],
            const SizedBox(height: 18),
            _Section(title: 'En retard', color: HF.red, wash: HF.redWash, icon: Icons.error_outline, items: overdue),
            _Section(title: 'Aujourd’hui', color: HF.amber, wash: HF.amberWash, icon: Icons.today_outlined, items: today),
            _Section(title: 'À venir', color: HF.sage, wash: HF.sageWash, icon: Icons.event_outlined, items: upcoming),
            if (overdue.isEmpty && today.isEmpty && upcoming.isEmpty)
              const EmptyState(
                icon: Icons.volunteer_activism_outlined,
                title: 'Aucune relance programmée',
                message: 'Les relances J+2 sont créées automatiquement à chaque enregistrement.',
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.color, required this.wash, required this.icon, required this.items});

  final String title;
  final Color color;
  final Color wash;
  final IconData icon;
  final List<FollowUp> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: HF.heading(17, weight: FontWeight.w600)),
              const SizedBox(width: 8),
              Pill('${items.length}', bg: wash, fg: color),
            ],
          ),
          const SizedBox(height: 10),
          for (final f in items) ...[
            _FollowUpCard(followUp: f, color: color, wash: wash, icon: icon, badge: title),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

/// Carte à bandeau coloré (inspiration : cartes « In progress / Overdue »).
class _FollowUpCard extends ConsumerWidget {
  const _FollowUpCard({required this.followUp, required this.color, required this.wash, required this.icon, required this.badge});

  final FollowUp followUp;
  final Color color;
  final Color wash;
  final IconData icon;
  final String badge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = followUp;
    final name = f.contactName ?? '';
    final initials = name.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join().toUpperCase();
    final phone = f.contactPhone;

    return Container(
      decoration: BoxDecoration(
        color: HF.card,
        borderRadius: BorderRadius.circular(HF.cardRadius),
        border: Border.all(color: HF.linen),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 5, color: color),
          InkWell(
            onTap: () => context.go('/contacts/${f.contactUuid}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        f.scheduledAt == null ? '' : formatDateTime(f.scheduledAt!),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Pill(badge, bg: wash, fg: color, icon: icon),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      InitialsAvatar(initials.isEmpty ? '?' : initials, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: HF.heading(17, weight: FontWeight.w600)),
                            Text(
                              f.actionType.label,
                              style: const TextStyle(color: HF.sage, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (f.description != null) ...[
                    const SizedBox(height: 10),
                    Text(f.description!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ActionTile(
                    icon: f.actionType == FollowUpActionType.appel ? Icons.call_outlined : Icons.chat_outlined,
                    label: f.actionType == FollowUpActionType.appel ? 'Appeler' : 'WhatsApp',
                    bg: HF.sageWash,
                    fg: HF.sageDark,
                    onTap: phone == null
                        ? null
                        : () => f.actionType == FollowUpActionType.appel
                              ? Launcher.call(context, phone)
                              : Launcher.whatsapp(context, phone),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ActionTile(
                    icon: Icons.task_alt,
                    label: 'Clôturer',
                    fg: HF.terracottaDark,
                    onTap: () => showCompleteSheet(context, ref, f),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
