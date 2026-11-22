import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../services/auth_controller.dart';
import '../../services/sync_service.dart';

/// Profil : compte, état de la synchronisation, déconnexion.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref, int pending) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: Text(
          pending > 0
              ? 'Attention : $pending enregistrement(s) ne sont pas encore envoyés au serveur. Ils seront perdus. Synchronisez d’abord si possible.'
              : 'Les données seront effacées de ce téléphone. Elles restent sur le serveur.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: pending > 0 ? HF.red : HF.terracottaDark),
            child: Text(pending > 0 ? 'Perdre et se déconnecter' : 'Se déconnecter'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final sync = ref.watch(syncControllerProvider);
    if (user == null) return const Scaffold();

    final initials = user.name.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join().toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          HFCard(
            child: Row(
              children: [
                InitialsAvatar(initials, size: 60),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: HF.heading(20)),
                      Text('@${user.username}', style: const TextStyle(color: HF.muted)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final r in user.roles) Pill(_roleLabel(r), bg: HF.terracottaWash, fg: HF.terracottaDark),
                          for (final t in user.teams) Pill(t.name, bg: HF.sageWash, fg: HF.sageDark, icon: Icons.groups_outlined),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          HFCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  icon: Icons.cloud_sync_outlined,
                  title: 'Synchronisation',
                  trailing: Pill(
                    sync.online ? 'En ligne' : 'Hors ligne',
                    bg: sync.online ? HF.sageWash : HF.amberWash,
                    fg: sync.online ? HF.sageDark : const Color(0xFFB45309),
                    dot: true,
                  ),
                ),
                if (AppConfig.isDemo)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Mode démonstration : les données restent sur ce téléphone, aucun serveur n’est configuré.',
                      style: TextStyle(color: HF.muted),
                    ),
                  ),
                _line('En attente d’envoi', '${sync.pending}', sync.pending > 0 ? HF.amber : HF.sage),
                _line('Conflits à résoudre', '${sync.conflicts}', sync.conflicts > 0 ? HF.red : HF.sage),
                if (sync.failed > 0) _line('Refusés par le serveur', '${sync.failed}', HF.red),
                _line(
                  'Dernière synchronisation',
                  sync.lastSyncAt == null ? 'jamais' : formatRelative(sync.lastSyncAt!),
                  HF.charcoal,
                ),
                if (sync.lastError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    sync.lastError!,
                    style: const TextStyle(color: HF.red, fontWeight: FontWeight.w600),
                  ),
                ],
                if (sync.conflicts > 0) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Ouvrez les fiches marquées d’un nuage rouge dans Contacts › Non synchronisés pour choisir la version à garder.',
                    style: TextStyle(fontSize: 13, color: HF.muted),
                  ),
                ],
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: sync.running ? null : () => ref.read(syncControllerProvider.notifier).syncNow(),
                  icon: const Icon(Icons.sync),
                  label: Text(sync.running ? 'Synchronisation…' : 'Synchroniser maintenant'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          HFCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.shield_outlined, color: HF.sage),
                  title: Text('Confidentialité'),
                  subtitle: Text('Les données des personnes sont confidentielles. Ne faites pas de captures d’écran des fiches.'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: HF.red),
                  title: const Text(
                    'Se déconnecter',
                    style: TextStyle(color: HF.red, fontWeight: FontWeight.w600),
                  ),
                  onTap: () => _logout(context, ref, sync.pending),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text('Église Connect · version 0.1.0', style: TextStyle(fontSize: 12, color: HF.muted)),
          ),
        ],
      ),
    );
  }

  static Widget _line(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: HF.muted)),
        ),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w700, color: color),
        ),
      ],
    ),
  );

  static String _roleLabel(String slug) => switch (slug) {
    'administrateur' => 'Administrateur',
    'responsable_eglise' => 'Responsable de l’église',
    'responsable_evangelisation' => 'Resp. évangélisation',
    'responsable_accueil' => 'Resp. accueil',
    'responsable_suivi' => 'Resp. suivi',
    'evangeliste' => 'Évangéliste',
    'agent_accueil' => 'Agent d’accueil',
    'responsable_priere' => 'Responsable prière',
    'intercesseur' => 'Intercesseur / intercesseuse',
    _ => slug,
  };
}
