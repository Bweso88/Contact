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
import 'features/priere/prayer_home_screen.dart';
import 'features/priere/prayer_plan_screen.dart';
import 'features/priere/prayer_session_screen.dart';
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
      final user = auth.valueOrNull;
      if (user == null) return loc == '/login' ? null : '/login';

      // Comptes intercesseurs : uniquement la chaîne de prière et le profil.
      if (user.isIntercessorOnly) {
        const allowed = ['/priere-seul', '/session-priere', '/planifier-priere', '/profil'];
        return allowed.any(loc.startsWith) ? null : '/priere-seul';
      }
      if (loc == '/login' || loc == '/splash' || loc == '/priere-seul') return '/contacts';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _Splash()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/profil', parentNavigatorKey: _rootKey, builder: (_, __) => const ProfileScreen()),
      // Chaîne de prière : salle en plein écran (sans barre de navigation) pour tous.
      GoRoute(
        path: '/session-priere/:uuid',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => PrayerSessionScreen(uuid: s.pathParameters['uuid']!),
      ),
      GoRoute(path: '/planifier-priere', parentNavigatorKey: _rootKey, builder: (_, __) => const PrayerPlanScreen()),
      GoRoute(path: '/priere-seul', builder: (_, __) => const PrayerHomeScreen(standalone: true)),
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
            routes: [GoRoute(path: '/priere', builder: (_, __) => const PrayerHomeScreen())],
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
