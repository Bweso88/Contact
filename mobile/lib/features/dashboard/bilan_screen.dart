import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/database.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/enums.dart';
import '../../repositories/contact_repository.dart';
import '../../services/auth_controller.dart';
import '../../services/sync_service.dart';

enum Period {
  today('Aujourd’hui'),
  week('Semaine'),
  month('Mois'),
  year('Année');

  const Period(this.label);
  final String label;

  DateTime get since {
    final now = DateTime.now();
    return switch (this) {
      Period.today => startOfDay(now),
      Period.week => startOfDay(now).subtract(Duration(days: now.weekday - 1)),
      Period.month => DateTime(now.year, now.month),
      Period.year => DateTime(now.year),
    };
  }
}

final statsProvider = FutureProvider.family<DashboardStats, Period>((ref, p) {
  ref.watch(dataRevisionProvider);
  return ref.watch(contactRepositoryProvider).stats(p.since);
});

/// Tableau de bord, mis en forme comme le « Bilan de session terrain » de la maquette.
/// Calculé sur les données présentes sur le téléphone (donc aussi hors ligne).
class BilanScreen extends ConsumerStatefulWidget {
  const BilanScreen({super.key});

  @override
  ConsumerState<BilanScreen> createState() => _BilanScreenState();
}

class _BilanScreenState extends ConsumerState<BilanScreen> {
  Period _period = Period.week;

  String get _greeting {
    final h = DateTime.now().hour;
    return h < 12 ? 'Bonjour' : (h < 18 ? 'Bon après-midi' : 'Bonsoir');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final stats = ref.watch(statsProvider(_period));
    final sync = ref.watch(syncControllerProvider);

    return Scaffold(
      appBar: const HFTopBar(),
      body: RefreshIndicator(
        color: HF.terracotta,
        onRefresh: () => ref.read(syncControllerProvider.notifier).syncNow(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$_greeting ',
                    style: HF.heading(28, weight: FontWeight.w500),
                  ),
                  TextSpan(
                    text: '${user?.name.split(' ').first ?? ''},',
                    style: HF.heading(28, color: HF.terracotta),
                  ),
                ],
              ),
            ),
            const Text('Voici où en est l’accompagnement.', style: TextStyle(color: HF.muted, fontSize: 15)),
            const SizedBox(height: 16),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final p in Period.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: QuickChip(label: p.label, selected: _period == p, onTap: () => setState(() => _period = p)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            stats.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: HF.terracotta)),
              ),
              error: (e, _) => EmptyState(icon: Icons.error_outline, title: 'Erreur', message: '$e'),
              data: (s) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.insights, color: HF.terracotta, size: 20),
                      const SizedBox(width: 8),
                      Text('Impact de la période', style: HF.heading(17, weight: FontWeight.w600)),
                      const Spacer(),
                      if (sync.lastSyncAt != null)
                        Text(
                          'Màj ${formatRelative(sync.lastSyncAt!)}',
                          style: const TextStyle(fontSize: 12, color: HF.sage, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.25,
                    children: [
                      _Kpi(
                        label: 'NOUVEAUX',
                        value: s.newContacts,
                        caption: 'Contacts enregistrés',
                        icon: Icons.person_add_alt,
                        color: HF.terracottaDark,
                      ),
                      _Kpi(
                        label: 'ÉVANGÉLISATION',
                        value: s.evangelisation,
                        caption: 'Rencontrés dehors',
                        icon: Icons.campaign_outlined,
                        color: HF.sageDark,
                      ),
                      _Kpi(
                        label: 'VISITEURS',
                        value: s.newVisitors,
                        caption: 'Venus au culte',
                        icon: Icons.church_outlined,
                        color: HF.charcoal,
                      ),
                      _Kpi(
                        label: 'SUIVIS À FAIRE',
                        value: s.pendingFollowUps,
                        caption: 'Actions en attente',
                        icon: Icons.pending_actions_outlined,
                        color: HF.amber,
                      ),
                      _Kpi(
                        label: 'REVENUS',
                        value: s.returned,
                        caption: '2 visites ou plus',
                        icon: Icons.replay,
                        color: HF.sageDark,
                      ),
                      _Kpi(
                        label: 'INTÉGRÉS',
                        value: s.integrated,
                        caption: 'En église de maison',
                        icon: Icons.cottage_outlined,
                        color: HF.terracottaDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _StatusBreakdown(stats: s),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: sync.running ? null : () => ref.read(syncControllerProvider.notifier).syncNow(),
                    icon: sync.running
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_sync_outlined),
                    label: Text(sync.pending > 0 ? 'Synchroniser (${sync.pending})' : 'Synchroniser'),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 52,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(backgroundColor: HF.sageWash, foregroundColor: HF.sageDark),
                      onPressed: () => _shareReport(s),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Partager le bilan sur WhatsApp'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bilan chiffré uniquement : aucun nom ni information personnelle n'est partagé.
  void _shareReport(DashboardStats s) {
    final text =
        '''
Bilan Église Connect — ${_period.label.toLowerCase()} (${formatDate(DateTime.now())})
• Nouveaux contacts : ${s.newContacts}
• Évangélisation : ${s.evangelisation}
• Nouveaux visiteurs : ${s.newVisitors}
• Suivis en attente : ${s.pendingFollowUps}
• Personnes revenues : ${s.returned}
• Personnes intégrées : ${s.integrated}''';
    unawaited(launchUrl(Uri.https('wa.me', '/', {'text': text}), mode: LaunchMode.externalApplication));
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.caption, required this.icon, required this.color});

  final String label;
  final int value;
  final String caption;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return HFCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: color),
                ),
              ),
              Icon(icon, size: 20, color: color),
            ],
          ),
          const Spacer(),
          Text('$value', style: HF.heading(34, color: color)),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: HF.muted),
          ),
        ],
      ),
    );
  }
}

class _StatusBreakdown extends StatelessWidget {
  const _StatusBreakdown({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final total = stats.total == 0 ? 1 : stats.total;
    final entries = ContactStatus.values.where((s) => (stats.byStatus[s] ?? 0) > 0).toList();

    return HFCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.stacked_bar_chart,
            title: 'Où en sont les personnes',
            trailing: Pill('${stats.total} au total', bg: HF.sand),
          ),
          if (entries.isEmpty) const Text('Aucun contact pour l’instant.', style: TextStyle(color: HF.muted)),
          for (final s in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 128,
                    child: Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: (stats.byStatus[s] ?? 0) / total,
                        minHeight: 10,
                        backgroundColor: HF.sand,
                        color: statusColors(s).fg,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${stats.byStatus[s]}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
