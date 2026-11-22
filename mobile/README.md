# Église Connect — application mobile (Flutter)

Application Android / iOS conçue pour fonctionner **d'abord hors connexion** : tout est
enregistré sur le téléphone (SQLite), puis envoyé au serveur Laravel dès que le réseau revient.

Design : système « Harvest Field » (maquette Stitch, voir `docs/design/`).

## Démarrer

Ce dossier contient `lib/`, `test/` et `pubspec.yaml`. Les dossiers natifs (`android/`, `ios/`)
se génèrent avec Flutter :

```bash
cd mobile
flutter create --org org.egliseconnect --platforms android,ios --project-name eglise_connect .
flutter pub get
flutter test
flutter run                  # mode démonstration (pas de serveur)
```

`flutter create .` ne remplace pas les fichiers existants : il ajoute seulement ce qui manque.

### Mode démonstration

Sans `API_BASE_URL`, l'application démarre en mode démo : n'importe quel identifiant
fonctionne, 10 contacts fictifs sont créés sur le téléphone et rien n'est envoyé.
Pratique pour montrer l'application aux responsables avant que l'API soit prête.

### Avec le serveur Laravel

```bash
flutter run --dart-define=API_BASE_URL=https://api.mon-eglise.org
```

## Réglages natifs à ajouter après `flutter create`

**Android** — `android/app/src/main/AndroidManifest.xml`, avant `<application>` :

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<queries>
  <intent><action android:name="android.intent.action.DIAL" /><data android:scheme="tel" /></intent>
  <intent><action android:name="android.intent.action.SENDTO" /><data android:scheme="sms" /></intent>
  <intent><action android:name="android.intent.action.VIEW" /><data android:scheme="https" /></intent>
</queries>
```

Et dans `android/app/build.gradle(.kts)` : `minSdk = 23` (exigé par flutter_secure_storage).

**iOS** — `ios/Runner/Info.plist` :

```xml
<key>LSApplicationQueriesSchemes</key>
<array><string>tel</string><string>sms</string><string>whatsapp</string></array>
```

## Polices de la maquette (facultatif)

Télécharger **Plus Jakarta Sans** et **Inter** sur fonts.google.com, placer les `.ttf` dans
`assets/fonts/`, puis ajouter dans `pubspec.yaml` sous `flutter:` :

```yaml
  fonts:
    - family: PlusJakartaSans
      fonts:
        - asset: assets/fonts/PlusJakartaSans-Regular.ttf
        - asset: assets/fonts/PlusJakartaSans-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/PlusJakartaSans-Bold.ttf
          weight: 700
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
        - asset: assets/fonts/Inter-SemiBold.ttf
          weight: 600
```

Les polices sont embarquées (et non chargées depuis Internet) parce que l'application
doit fonctionner hors ligne. Sans elles, la police système est utilisée.

## Organisation

```
lib/
├── main.dart, app.dart        Démarrage, routes (go_router), redirection connexion
├── core/                      Config, thème Harvest Field, base SQLite, file de sync, widgets communs
├── models/                    Contact, FollowUp, AppUser, enums (mêmes valeurs que les enums PHP)
├── repositories/              Lecture / écriture locales (contacts, suivis, statistiques)
├── services/                  API (dio), authentification, synchronisation, données de démo
└── features/
    ├── authentication/        Connexion
    ├── shell/                 Barre de navigation : Nouveau · Contacts · Suivi · Bilan
    ├── contacts/              Saisie rapide, répertoire, fiche contact
    ├── suivi/                 Relances (en retard / aujourd'hui / à venir) et feuilles d'action
    ├── dashboard/             Bilan (indicateurs du cahier des charges)
    └── profile/               Profil, état de la synchronisation, déconnexion
```

État : **Riverpod** (sans génération de code). Chaque écriture locale incrémente
`dataRevisionProvider`, ce qui recharge automatiquement les écrans concernés.

## Écrans et choix par rapport à la maquette

| Maquette | Application |
|---|---|
| Saisie rapide terrain | `Nouveau` : prénom, nom, téléphone (+242), quartier en puces 1-tap, origine, souhaits, accord de contact, notes. **Enregistrer (+ Relance J+2)** ou **Sauvegarder et enchaîner** (garde l'origine et le quartier). |
| Répertoire suivi | `Contacts` : recherche, filtres avec compteurs, bandeau « Relances prioritaires », cartes avec WhatsApp / appel / note. |
| Fiche détaillée | Fiche : actions rapides, frise du parcours (Rencontre → Intégré), prochaine action, historique, informations. |
| Bilan de session | `Bilan` : indicateurs par période, répartition par statut, synchronisation, partage WhatsApp (chiffres seulement). |

Volontairement non repris : la « posture spirituelle ressentie », les étiquettes de santé
et les photos des personnes (section 8 du cahier des charges : ne pas enregistrer de détails
personnels ou spirituels non nécessaires). Carte, binômes, témoignages et mémo vocal sont
prévus pour la V1.1.

## Contrats d'API attendus du backend

### `POST /api/login`

```json
// requête
{ "username": "marc", "password": "…", "device_name": "mobile" }
// réponse 200
{ "token": "1|abc…",
  "user": { "id": 4, "name": "Marc D.", "username": "marc",
            "roles": ["evangeliste"], "permissions": ["contacts.create", "…"],
            "teams": [{ "id": 1, "name": "Équipe évangélisation A", "is_leader": false }] } }
```

### `POST /api/sync` (authentifié)

Le téléphone envoie sa file d'opérations, dans l'ordre, et reçoit ce qui a changé depuis son dernier passage.

```json
// requête
{
  "last_pulled_at": "2026-11-22T09:00:00Z",          // null au premier passage
  "operations": [
    { "id": 12, "entity": "contact", "uuid": "9b1…", "operation": "create", "base_version": null,
      "payload": { "uuid": "9b1…", "first_name": "Grâce", "last_name": "Mabiala", "phone": "06 123 45 67",
                   "source": "evangelisation", "first_met_at": "2026-11-22", "team_id": 1, "wants_contact": true,
                   "first_event": { "uuid": "…", "type": "premiere_rencontre", "occurred_at": "…", "notes": null },
                   "consent": { "purpose": "suivi", "granted": true, "method": "oral", "channel": "whatsapp" } } },
    { "id": 13, "entity": "contact", "uuid": "9b1…", "operation": "status_change", "base_version": 1,
      "payload": { "status": "contacte", "reason": "Premier appel", "changed_at": "…" } },
    { "id": 14, "entity": "follow_up", "uuid": "c42…", "operation": "create",
      "payload": { "uuid": "c42…", "contact_uuid": "9b1…", "action_type": "appel", "scheduled_at": "…" } },
    { "id": 15, "entity": "follow_up", "uuid": "c42…", "operation": "update",
      "payload": { "completed_at": "…", "result": "joint", "description": "…" } },
    { "id": 16, "entity": "contact_event", "uuid": "e77…", "operation": "create",
      "payload": { "uuid": "e77…", "contact_uuid": "9b1…", "type": "visite_culte", "occurred_at": "…" } }
  ]
}

// réponse 200
{
  "results": [
    { "id": 12, "status": "ok", "version": 1 },
    { "id": 13, "status": "conflict", "server": { /* ContactResource complet */ } },
    { "id": 14, "status": "error", "message": "Le contact refuse d'être recontacté." }
  ],
  "changes": {
    "contacts":       [ /* ContactResource, ou { "uuid": "…", "deleted": true } */ ],
    "follow_ups":     [ /* FollowUpResource avec contact_uuid et user { id, name } */ ],
    "contact_events": [ /* ContactEventResource avec contact_uuid et recorded_by { name } */ ]
  },
  "cursor": "2026-11-22T10:15:03Z"
}
```

Règles côté serveur :
- **Idempotence** : une création dont l'`uuid` existe déjà renvoie `ok` sans rien créer (réponse perdue puis renvoyée).
- **Conflit** : si `base_version` ≠ `contacts.version`, renvoyer `conflict` avec la version serveur. Le téléphone demande alors à l'utilisateur laquelle garder.
- **Permissions** : chaque opération est vérifiée comme un appel normal ; `changes` ne contient que ce que l'utilisateur a le droit de voir.
- `status_change` vers `integre` est toujours refusé (il passe par la confirmation d'intégration).

## Export Excel

Bouton ⬇ dans la barre du haut : le fichier `.xlsx` s'ouvre dans le partage du téléphone
(WhatsApp, e-mail, Google Drive, Fichiers…).

| Liste | Contenu | Permission |
|---|---|---|
| Contacts | La liste affichée (même recherche, même filtre), toutes colonnes utiles | `contacts.export` |
| Suivi | Relances en retard, du jour et à venir | `contacts.export` |
| Bilan | Indicateurs de la période + répartition par statut | `reports.view` |
| Chaîne de prière | Planning, tours (feu/eau, durées), messages | `prayer.manage` |

Les exports contiennent des données personnelles : ils restent réservés à ces rôles (cahier des charges, section 8).

## Chaîne de prière

Module à part pour les intercesseurs, qui prient chacun chez soi, l'un après l'autre.

- Le **responsable prière** planifie une chaîne : créneaux consécutifs attribués aux intercesseurs (bouton « Planifier »).
- Pendant son créneau (dès 10 min avant), l'intercesseur touche **Je prends la main** et choisit **feu** ou **eau**.
- Tout le monde voit l'animation, son nom et depuis combien de temps il prie. Aucun son n'est transmis.
- Il touche **Je rends la main** ; le suivant prend le relais. Une seule main à la fois (garanti par la base de données).
- Mur de messages dans la session, avec partage vers WhatsApp (ou ouverture du groupe si son lien est renseigné).
- Un compte **intercesseur** ne voit que ce module, pas les contacts.

Mode démo : se connecter avec l'identifiant `intercesseur` pour voir l'expérience d'un compte intercesseur ;
avec un autre identifiant, l'onglet **Prière** apparaît à côté des contacts. Dans la chaîne « ce soir »,
c'est votre créneau : prenez la main, rendez-la, et Prisca prend le relais.

**Alertes sonores** (programmées sur le téléphone, elles sonnent même application fermée) :
10 min avant mon créneau ; au début puis à +2, +5 et +10 min « Veuillez prendre la main » tant que je ne l'ai pas prise ;
« Votre temps finit dans X min » (X réglé par l'organisateur dans le planning) ; fin du temps.
À la fin du créneau, le tour se clôt tout seul (« a fini de prier ») et le bandeau « Veuillez prendre la main »
clignote pour tous tant que le suivant n'a pas pris la main. Le nom de l'assemblée s'affiche sous celui de la personne qui prie.

Une alerte n'est programmée qu'après une ouverture du module par l'intercesseur. Pour prévenir aussi ceux qui
n'ouvrent pas l'appli, il faudra des notifications push (Firebase Cloud Messaging, prévu au cahier des charges).

Ce module fonctionne **en direct** : il faut Internet. L'application interroge le serveur toutes les 4 secondes
(passage aux WebSockets avec Laravel Reverb possible plus tard).

### API attendue

| Méthode | Endpoint | Rôle |
|---|---|---|
| GET | `/api/prayer-sessions` | `{ data: [ { uuid, title, description, starts_at, ends_at, end_warning_minutes, whatsapp_group_url, current_turn } ] }` |
| GET | `/api/prayer-sessions/{uuid}/live` | `{ server_time, session, slots: [ { uuid, user: {id,name,assembly}, starts_at, ends_at } ], turns: [ { uuid, user, visual, started_at, ended_at, auto_ended, slot_uuid } ], messages: [ { uuid, user, body, created_at } ] }` (50 derniers messages, du plus récent au plus ancien) — appeler `closeExpiredTurn()` avant de répondre |
| POST | `/api/prayer-sessions/{uuid}/take` | `{ visual: "feu" \| "eau" }` → `PrayerTurn::take()` ; 422 avec `message` si refusé |
| POST | `/api/prayer-sessions/{uuid}/release` | → `PrayerTurn::release()` |
| POST | `/api/prayer-sessions/{uuid}/messages` | `{ body }` |
| GET | `/api/prayer-sessions/intercessors` | `{ data: [ { id, name } ] }` (permission `prayer.manage`) |
| POST | `/api/prayer-sessions` | `{ title, description, whatsapp_group_url, end_warning_minutes, slots: [ { user_id, starts_at, ends_at } ] }` → `{ data: { uuid } }` |

## Ce qu'il faut vérifier à la première compilation

Le code a été écrit sans pouvoir lancer Flutter. Les modèles, les enums et la normalisation
des numéros ont été compilés et testés avec Dart 3.14, mais les écrans n'ont jamais été compilés.
Les points à surveiller :
- versions des paquets : si `flutter pub get` signale un conflit, `flutter pub upgrade --major-versions` ;
- avertissements de dépréciation (`activeColor`, `groupValue` des boutons radio) selon ta version de Flutter : sans conséquence ;
- toute erreur restante sera localisée et simple à corriger : envoie-moi la sortie de `flutter analyze`.
