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

/// Barre de navigation de la maquette : Nouveau · Contacts · Suivi · Bilan.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(dueCountProvider).valueOrNull ?? 0;

    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: HF.linen)),
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.person_add_alt_outlined),
              selectedIcon: Icon(Icons.person_add_alt_1),
              label: 'Nouveau',
            ),
            const NavigationDestination(
              icon: Icon(Icons.contacts_outlined),
              selectedIcon: Icon(Icons.contacts),
              label: 'Contacts',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: due > 0,
                label: Text('$due'),
                backgroundColor: HF.terracotta,
                child: const Icon(Icons.volunteer_activism_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: due > 0,
                label: Text('$due'),
                backgroundColor: HF.terracotta,
                child: const Icon(Icons.volunteer_activism),
              ),
              label: 'Suivi',
            ),
            const NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Bilan'),
          ],
        ),
      ),
    );
  }
}
