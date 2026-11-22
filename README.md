# Église Connect

Application de gestion des contacts de l'église : ne perdre aucune personne rencontrée,
assurer un suivi humain et organisé, et accompagner chacun jusqu'à l'intégration dans
une église de maison.

| Dossier | Contenu |
|---|---|
| [`backend/`](backend/) | Laravel + MySQL : migrations, modèles, permissions, données initiales, tests des règles métier |
| [`mobile/`](mobile/) | Flutter (Android / iOS) : hors connexion d'abord, synchronisation, design Harvest Field |
| [`docs/`](docs/) | Cahier des charges et maquette Stitch (`docs/design/`) |

## Avancement

| Phase | État |
|---|---|
| 1. Architecture et base de données | ✅ `backend/` (à copier dans un projet Laravel neuf) |
| 2. Authentification et habilitations | 🟡 rôles et permissions prêts ; endpoints `/api/login` à écrire |
| 3–5. Contacts, fiches, suivi | 🟡 côté mobile prêt ; API REST à écrire |
| 6. Équipes et églises de maison | 🟡 schéma prêt |
| 7. Tableau de bord | 🟡 écran Bilan (données locales) |
| 8. Hors connexion | 🟡 mobile prêt ; `/api/sync` à écrire (contrat dans `mobile/README.md`) |
| 9–10. Notifications, tests, déploiement | ⬜ |

## Essayer tout de suite

L'application mobile fonctionne sans serveur en **mode démonstration** :

```bash
cd mobile
flutter create --org org.egliseconnect --platforms android,ios --project-name eglise_connect .
flutter pub get
flutter run
```

Voir [`backend/README.md`](backend/README.md) et [`mobile/README.md`](mobile/README.md) pour le détail.
