import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../core/database.dart';
import '../models/app_user.dart';
import 'api_client.dart';
import 'demo_data.dart';

/// Utilisateur connecté (null = déconnecté). Restauré au démarrage
/// depuis le stockage sécurisé : on reste connecté même hors ligne.
class AuthController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    final raw = await ref.read(tokenStoreProvider).readUser();
    if (raw == null) return null;
    return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Lève une ApiException en cas d'échec : l'écran de connexion l'affiche
  /// sans perdre ce qui a été saisi.
  Future<void> login(String username, String password) async {
    if (AppConfig.isDemo) {
      final user = DemoData.user(username);
      await ref.read(tokenStoreProvider).save(token: 'demo', userJson: jsonEncode(user.toJson()));
      await DemoData.seed(ref.read(databaseProvider), user);
      ref.read(dataRevisionProvider.notifier).bump();
      state = AsyncData(user);
      return;
    }

    // Contrat attendu de Laravel : { token, user: { id, name, username, roles, permissions, teams } }
    final res = await ref.read(apiClientProvider).post('/api/login', {
      'username': username.trim(),
      'password': password,
      'device_name': 'mobile',
    });
    final user = AppUser.fromJson(res['user'] as Map<String, dynamic>);
    await ref.read(tokenStoreProvider).save(token: res['token'] as String, userJson: jsonEncode(user.toJson()));
    state = AsyncData(user);
  }

  /// Déconnexion : révoque le jeton et efface les données locales du téléphone.
  /// L'écran Profil prévient avant si des enregistrements ne sont pas synchronisés.
  Future<void> logout() async {
    if (!AppConfig.isDemo) {
      try {
        await ref.read(apiClientProvider).post('/api/logout');
      } catch (_) {
        // Hors ligne : le jeton expirera côté serveur.
      }
    }
    await ref.read(tokenStoreProvider).clear();
    await ref.read(databaseProvider).wipe();
    ref.read(dataRevisionProvider.notifier).bump();
    state = const AsyncData(null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(AuthController.new);

/// Raccourci pour les écrans : l'utilisateur connecté (non nul une fois connecté).
final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(authControllerProvider).valueOrNull);
