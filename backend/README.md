# Église Connect — socle base de données (backend Laravel)

Livrable n°1 du plan de développement : migrations, enums, modèles Eloquent,
habilitations, données initiales et tests des règles métier.

## Installation

Ces fichiers se déposent dans un projet Laravel neuf (Laravel 11 ou plus récent, PHP 8.2+).

```bash
composer create-project laravel/laravel backend
cd backend
php artisan install:api          # installe Sanctum + routes/api.php

# Copier le contenu de cette archive par-dessus le projet
# (remplace la migration users, User.php, UserFactory.php et DatabaseSeeder.php).
```

Déclarer le fournisseur de permissions dans `bootstrap/providers.php` :

```php
return [
    App\Providers\AppServiceProvider::class,
    App\Providers\PermissionServiceProvider::class,
];
```

Configurer `.env` (MySQL 8) :

```dotenv
APP_LOCALE=fr
APP_FAKER_LOCALE=fr_FR
DB_CONNECTION=mysql
DB_DATABASE=eglise_connect
DB_USERNAME=...
DB_PASSWORD=...

CHURCH_NAME="Nom de l'église"
ADMIN_USERNAME=admin
ADMIN_PASSWORD=un-mot-de-passe-solide
```

Puis :

```bash
php artisan migrate --seed       # en local : ajoute aussi les données de démo
php artisan test --filter=ContactRulesTest
```

Lance le seeding **avant** `php artisan config:cache` : une fois la config en cache,
`env()` renvoie null et les seeders utilisent leurs valeurs par défaut.

Comptes de démo (environnement `local` seulement, mot de passe `password`) :
`pasteur`, `resp.evang`, `resp.accueil`, `resp.suivi`, `evangeliste1..4`, `accueil1..2`.

## Les quatre décisions du cahier des charges

Aucune n'est figée dans le schéma : elles sont dans la table `settings`.

| Décision | Choix par défaut | Où le changer |
|---|---|---|
| 1. Identité | Nom et logo configurables | `church.name`, `church.logo_path` |
| 2. Qui enregistre | Tous les membres autorisés (évangélistes, accueil, responsables) | permission `contacts.create` dans `RolePermissionSeeder` |
| 3. Qui suit | Le responsable de l'équipe qui a rencontré la personne | `follow_up.assignment_mode` : `team_leader`, `creator` ou `central_team` |
| 4. Langue | Français, prêt pour l'anglais | `app.locale`, `app.available_locales` |

## Tables

| Table | Rôle |
|---|---|
| `users` | Comptes (connexion par identifiant, e-mail facultatif) |
| `roles`, `permissions`, `permission_role`, `user_roles` | Profils et habilitations, cumul de rôles possible |
| `settings` | Réglages de l'église |
| `teams`, `team_members` | Équipes et leurs membres |
| `house_churches` | Églises de maison |
| `contacts` | Un dossier par personne |
| `contact_events` | Rencontres successives (dont « décision de foi », distincte de l'intégration) |
| `contact_status_changes` | Historique des statuts : date, auteur, motif (ajout seul) |
| `follow_ups` | Actions de suivi programmées ou réalisées |
| `integrations` | Affectations aux églises de maison, avec confirmation |
| `consents` | Autorisations de contact et leur retrait |
| `audit_logs` | Traçabilité des modifications |
| `notifications`, `devices` | Notifications Laravel et jetons Firebase |

## Choix techniques à connaître

- **VARCHAR + enums PHP plutôt qu'ENUM MySQL.** Les valeurs autorisées sont dans
  `app/Enums`. Ajouter un statut = une ligne de PHP, sans `ALTER TABLE`. Eloquent
  convertit automatiquement : `$contact->status` est un `ContactStatus`, pas une chaîne.
- **UUID générés sur le téléphone.** Chaque table synchronisée a un `uuid` unique :
  renvoyer deux fois le même enregistrement après une coupure ne crée pas de doublon.
  L'API exposera l'UUID, jamais l'id.
- **`contacts.version`** (verrou optimiste) : le mobile renvoie la version qu'il a
  modifiée ; si le serveur a avancé entre-temps, c'est un conflit à résoudre, pas un écrasement.
- **`phone_normalized`** indexé mais non unique : « 06 123 45 67 » et « +242061234567 »
  sont reconnus comme le même numéro, et un doublon déclenche une vérification, pas un rejet.
- **Statut « Intégré »** : impossible à poser à la main. Il découle de
  `Integration::confirm()`, réservé à la permission `integrations.confirm`.
- **Refus de contact** : `wants_contact = false`, statut « Ne souhaite plus être contacté »
  ou retrait du consentement « suivi » → `do_not_contact = true` → exclu par le scope `reachable()`.
- **Soft deletes** sur les données métier : une suppression reste récupérable et tracée.

## Utilisation dans le code

```php
// Contacts visibles par l'utilisateur connecté, à relancer, sans suivi depuis 7 jours
Contact::visibleTo($user)->reachable()->withoutFollowUpSince(7)->get();

// Vérification des doublons avant enregistrement
$existants = Contact::samePhoneAs($request->phone)->get();

// Changement de statut historisé
$contact->changeStatus(ContactStatus::Contacte, $user, 'Premier appel');

// Permissions
$user->can('contacts.assign');
Route::post('/integrations/{integration}/confirm', ...)->middleware('can:integrations.confirm');
```

## Prochaine étape

Phase 2–3 : authentification Sanctum (login par identifiant), Form Requests,
API Resources et endpoints `/api/contacts` avec contrôle des doublons.
