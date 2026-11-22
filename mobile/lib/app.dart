import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'features/authentication/login_screen.dart';
import 'features/contacts/add_contact_screen.dart';
import 'features/contacts/contact_detail_screen.dart';
import 'features/contacts/contacts_screen.dart';
import 'features/dashboard/bilan_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/shell/home_shell.dart';
import 'features/suivi/suivi_screen.dart';
import 'services/auth_controller.dart';
import 'services/sync_service.dart';

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // Relance la redirection à chaque connexion / déconnexion.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/contacts',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      if (!auth.hasValue && auth.isLoading) return loc == '/splash' ? null : '/splash';
      final loggedIn = auth.valueOrNull != null;
      if (!loggedIn) return loc == '/login' ? null : '/login';
      if (loc == '/login' || loc == '/splash') return '/contacts';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _Splash()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/profil', parentNavigatorKey: _rootKey, builder: (_, __) => const ProfileScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/nouveau', builder: (_, __) => const AddContactScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/contacts',
                builder: (_, __) => const ContactsScreen(),
                routes: [
                  GoRoute(
                    path: ':uuid',
                    builder: (_, s) => ContactDetailScreen(uuid: s.pathParameters['uuid']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/suivi', builder: (_, __) => const SuiviScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/bilan', builder: (_, __) => const BilanScreen())],
          ),
        ],
      ),
    ],
  );
});

class EgliseConnectApp extends ConsumerWidget {
  const EgliseConnectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Démarre la synchronisation automatique sans reconstruire l'application à chaque changement.
    ref.listen(syncControllerProvider, (_, __) {});

    return MaterialApp.router(
      title: 'Église Connect',
      debugShowCheckedModeBanner: false,
      theme: HF.theme(),
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator(color: HF.terracotta)),
  );
}
