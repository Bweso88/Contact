import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database.dart';
import '../../core/theme.dart';
import '../../repositories/follow_up_repository.dart';
import '../../services/auth_controller.dart';

/// Nombre de relances en retard ou du jour : badge de l'onglet Suivi.
final dueCountProvider = FutureProvider<int>((ref) async {
  ref.watch(dataRevisionProvider);
  final repo = ref.watch(followUpRepositoryProvider);
  final userId = ref.watch(currentUserProvider)?.id;
  final overdue = await repo.due(FollowUpBucket.overdue, userId: userId);
  final today = await repo.due(FollowUpBucket.today, userId: userId);
  return overdue.length + today.length;
});

/// Barre de navigation : Nouveau · Contacts · Suivi · Prière · Bilan.
/// L'onglet Prière n'apparaît que pour les comptes qui y ont accès.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  /// Index des branches déclarées dans app.dart.
  static const _prayerBranch = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(dueCountProvider).valueOrNull ?? 0;
    final canPray = ref.watch(currentUserProvider)?.can('prayer.access') ?? false;

    Widget dueBadge(IconData icon) =>
        Badge(isLabelVisible: due > 0, label: Text('$due'), backgroundColor: HF.terracotta, child: Icon(icon));

    final all = <(int, NavigationDestination)>[
      (
        0,
        const NavigationDestination(
          icon: Icon(Icons.person_add_alt_outlined),
          selectedIcon: Icon(Icons.person_add_alt_1),
          label: 'Nouveau',
        ),
      ),
      (
        1,
        const NavigationDestination(icon: Icon(Icons.contacts_outlined), selectedIcon: Icon(Icons.contacts), label: 'Contacts'),
      ),
      (
        2,
        NavigationDestination(
          icon: dueBadge(Icons.volunteer_activism_outlined),
          selectedIcon: dueBadge(Icons.volunteer_activism),
          label: 'Suivi',
        ),
      ),
      if (canPray)
        (
          _prayerBranch,
          const NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department),
            label: 'Prière',
          ),
        ),
      (4, const NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Bilan')),
    ];
    final branches = [for (final (b, _) in all) b];
    final selected = branches.indexOf(shell.currentIndex);

    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: HF.linen)),
        ),
        child: NavigationBar(
          selectedIndex: selected < 0 ? 0 : selected,
          onDestinationSelected: (i) {
            final branch = branches[i];
            shell.goBranch(branch, initialLocation: branch == shell.currentIndex);
          },
          destinations: [for (final (_, d) in all) d],
        ),
      ),
    );
  }
}
