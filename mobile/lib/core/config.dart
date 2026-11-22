/// Configuration passée à la compilation :
///
///   flutter run --dart-define=API_BASE_URL=https://api.mon-eglise.org
///
/// Sans API_BASE_URL, l'application démarre en **mode démonstration** :
/// tout fonctionne en local avec des données fictives, sans serveur.
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static bool get isDemo => apiBaseUrl.isEmpty;

  /// Indicatif ajouté aux numéros locaux (doit correspondre au réglage serveur).
  static const defaultCountryCode = String.fromEnvironment('COUNTRY_CODE', defaultValue: '242');

  /// Intervalle de synchronisation automatique quand l'application est ouverte.
  static const syncInterval = Duration(minutes: 5);

  /// Nombre d'opérations envoyées par appel à /api/sync.
  static const syncBatchSize = 50;
}
