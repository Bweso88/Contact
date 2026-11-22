import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/prayer.dart';
import '../../repositories/prayer_repository.dart';
import '../../services/auth_controller.dart';

/// Liste des chaînes de prière (en cours, à venir).
/// [standalone] : écran d'accueil des comptes intercesseurs, qui n'ont pas accès aux contacts.
class PrayerHomeScreen extends ConsumerWidget {
  const PrayerHomeScreen({super.key, this.standalone = false});

  final bool standalone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(prayerSessionsProvider);
    final user = ref.watch(currentUserProvider);
    final now = DateTime.now();

    if (user != null && !user.can('prayer.access')) {
      return const Scaffold(
        appBar: HFTopBar(),
        body: EmptyState(
          icon: Icons.lock_outline,
          title: 'Réservé aux intercesseurs',
          message: 'Demandez au responsable prière de vous ajouter.',
        ),
      );
    }

    return Scaffold(
      appBar: HFTopBar(title: standalone ? 'Chaîne de prière' : null),
      floatingActionButton: (user?.can('prayer.manage') ?? false)
          ? FloatingActionButton.extended(
              backgroundColor: HF.terracotta,
              foregroundColor: Colors.white,
              onPressed: () async {
                await context.push('/planifier-priere');
                ref.invalidate(prayerSessionsProvider);
              },
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('Planifier'),
            )
          : null,
      body: RefreshIndicator(
        color: HF.terracotta,
        onRefresh: () async => ref.invalidate(prayerSessionsProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            Text('Chaîne de prière', style: HF.heading(26)),
            const SizedBox(height: 4),
            const Text('Chacun chez soi, l’un après l’autre : la flamme ne s’éteint pas.', style: TextStyle(color: HF.muted)),
            const SizedBox(height: 18),
            ...sessions.when<List<Widget>>(
              loading: () => [
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(color: HF.terracotta)),
                ),
              ],
              error: (e, _) => [
                const EmptyState(
                  icon: Icons.wifi_off,
                  title: 'Connexion nécessaire',
                  message: 'La chaîne de prière se vit en direct : connectez-vous à Internet.',
                ),
              ],
              data: (list) => list.isEmpty
                  ? [
                      const EmptyState(
                        icon: Icons.local_fire_department_outlined,
                        title: 'Aucune chaîne prévue',
                        message: 'Le responsable prière publiera le prochain planning.',
                      ),
                    ]
                  : [
                      for (final s in list) ...[
                        _SessionCard(session: s, live: s.isLive(now), onTap: () => context.push('/session-priere/${s.uuid}')),
                        const SizedBox(height: 14),
                      ],
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.live, required this.onTap});

  final PrayerSession session;
  final bool live;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final turn = session.liveTurn;
    final fire = turn?.visual != PrayerVisual.eau;

    return Material(
      color: live ? const Color(0xFF1F2940) : HF.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HF.cardRadius),
        side: BorderSide(color: live ? Colors.transparent : HF.linen),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: live
                      ? (turn == null ? const Color(0xFF2E3A55) : (fire ? const Color(0xFF4A2A1A) : const Color(0xFF16384D)))
                      : HF.terracottaWash,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  turn == null ? Icons.local_fire_department_outlined : (fire ? Icons.local_fire_department : Icons.water_drop),
                  color: turn == null
                      ? (live ? const Color(0xFF94A3B8) : HF.terracotta)
                      : (fire ? const Color(0xFFFF8A3D) : const Color(0xFF4FC3F7)),
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (live) ...[
                          const Pill('En direct', bg: Color(0xFFE65100), fg: Colors.white, dot: true),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    if (live) const SizedBox(height: 6),
                    Text(session.title, style: HF.heading(17, color: live ? Colors.white : HF.charcoal)),
                    const SizedBox(height: 2),
                    Text(
                      '${formatDate(session.startsAt)} · ${formatTime(session.startsAt)} – ${formatTime(session.endsAt)}',
                      style: TextStyle(fontSize: 13, color: live ? const Color(0xFF94A3B8) : HF.muted),
                    ),
                    if (live) ...[
                      const SizedBox(height: 6),
                      Text(
                        turn == null ? 'La main est libre' : '${turn.person.name} prie en ce moment',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: turn == null
                              ? const Color(0xFFFFCA28)
                              : (fire ? const Color(0xFFFF8A3D) : const Color(0xFF4FC3F7)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: live ? Colors.white54 : HF.muted),
            ],
          ),
        ),
      ),
    );
  }
}
