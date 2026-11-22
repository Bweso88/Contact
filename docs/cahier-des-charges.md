Cahier des charges fonctionnel et technique — Application de gestion des contacts de l’église

Projet cadréApplication mobile uniquementUne seule église locale

Je recommande de concevoir cette solution comme un véritable outil de gestion de la relation avec les visiteurs et les personnes rencontrées pendant l’évangélisation, et non comme un simple répertoire téléphonique.

Son objectif principal sera de permettre à l’église de ne perdre aucun contact, d’assurer un suivi humain et organisé et de faciliter l’intégration des nouvelles personnes dans la vie de l’église.

Le périmètre retenu est donc :

* Une seule église locale.
* Une application mobile Android et iOS.
* Plusieurs utilisateurs avec des responsabilités différentes.
* Une base de données centralisée.
* Un fonctionnement même en cas de coupure Internet.
* Un suivi du premier contact jusqu’à l’intégration dans une église de maison.

Je te propose une conception basée sur Flutter + Laravel API + MySQL, avec une architecture suffisamment simple pour être développée progressivement et maintenue par une petite équipe.

1. Vision fonctionnelle

Nom provisoire : Église Connect

L’application devra répondre à quatre questions fondamentales :

* Qui avons-nous rencontré ?
* Qui est responsable de cette personne ?
* Quelles actions de suivi ont déjà été effectuées ?
* Où en est cette personne dans son parcours d’intégration ?

Les deux circuits d’enregistrement

Évangélisation

Personnes rencontrées hors de l’église, lors des campagnes et visites.

Accueil

Personnes qui viennent assister à un culte ou à une activité.

Base centrale des contacts

Un seul dossier par personne, même si elle est rencontrée plusieurs fois.

Suivi et accompagnement

Appels, invitations, visites, accompagnement et intégration.

2. Profils utilisateurs et habilitations

Il faut éviter que tous les utilisateurs puissent accéder à toutes les informations.

Profil	Droits principaux
Administrateur	Configuration générale, comptes et accès
Responsable de l’église	Vue globale, statistiques et supervision
Responsable évangélisation	Gestion des contacts et équipes d’évangélisation
Responsable accueil	Gestion des visiteurs
Responsable suivi	Gestion des relances et accompagnements
Évangéliste	Enregistrement et consultation de ses contacts
Agent d’accueil	Enregistrement des visiteurs

Un utilisateur pourra éventuellement cumuler plusieurs rôles.

Règle importante : un évangéliste ne doit pas pouvoir modifier librement les historiques de suivi d’un autre responsable. Les modifications sensibles doivent être tracées.

3. Description détaillée des modules

Module 1 — Authentification

Fonctionnalités :

* Connexion par identifiant et mot de passe.
* Réinitialisation du mot de passe.
* Gestion des sessions.
* Déconnexion.
* Attribution des rôles.
* Activation et désactivation des comptes.

L’administrateur crée les comptes des membres de l’équipe.

Module 2 — Tableau de bord

L’écran d’accueil présente les indicateurs de l’église.

Indicateur	Description
Contacts enregistrés	Total des personnes
Nouveaux contacts	Enregistrements de la période
Contacts évangélisation	Origine évangélisation
Nouveaux visiteurs	Origine accueil
Suivis en attente	Actions à effectuer
Personnes revenues	Deuxième visite ou plus
Personnes intégrées	Intégration confirmée

Filtres :

* Aujourd’hui.
* Cette semaine.
* Ce mois.
* Cette année.
* Par équipe.
* Par responsable.

Le tableau de bord doit présenter les données sous forme de cartes et de graphiques.

Module 3 — Enregistrement des contacts

C’est le module le plus important. Il doit permettre un enregistrement en moins d’une minute.

A. Identité

* Nom.
* Prénom.
* Numéro de téléphone.
* Sexe (facultatif).
* Tranche d’âge (facultative).

B. Localisation

* Quartier.
* Arrondissement.
* Indication complémentaire (facultative).

C. Origine

* Évangélisation.
* Accueil.
* Invitation par un membre.
* Autre activité de l’église.

D. Informations de suivi

* Date de rencontre.
* Nom de l’enregistreur.
* Équipe concernée.
* Responsable du suivi.
* Souhaite-t-il être recontacté ?
* Moyen de contact préféré.

E. Informations spirituelles facultatives

* Souhaite-t-il être accompagné spirituellement ?
* Souhaite-t-il recevoir une invitation au culte ?
* Souhaite-t-il découvrir une église de maison ?

Il ne faut pas transformer l’enregistrement en interrogatoire : les champs non essentiels restent facultatifs.

Gestion des doublons

Un numéro de téléphone déjà enregistré doit déclencher une alerte.

Exemple :

« Ce numéro existe déjà dans la base. Voulez-vous consulter le dossier existant ou enregistrer une nouvelle rencontre ? »

Cela permet de conserver un seul dossier par personne et plusieurs événements de rencontre.

Module 4 — Fiche individuelle du contact

Chaque personne possède une fiche comprenant :

* Ses informations personnelles.
* La date de son premier contact.
* L’origine du contact.
* L’équipe qui l’a rencontrée.
* Le responsable chargé du suivi.
* Son statut actuel.
* L’historique des appels et messages.
* Les visites effectuées.
* Les rendez-vous programmés.
* Les observations autorisées.

Actions rapides :

* Appeler.
* Envoyer un SMS.
* Ouvrir WhatsApp.
* Ajouter une note.
* Programmer un suivi.
* Modifier le responsable.

Module 5 — Suivi et accompagnement

C’est ici que l’application apporte le plus de valeur.

Je propose les statuts suivants :

Statut	Signification
Nouveau	Contact enregistré
À contacter	Premier suivi à réaliser
Contacté	Premier échange effectué
Invité	Invitation au culte envoyée
Première visite	Première présence au culte confirmée
En accompagnement	Accompagnement en cours
Intégré	Intégration confirmée dans une église de maison
En pause	Suivi temporairement suspendu
Injoignable	Plusieurs tentatives infructueuses
Ne souhaite plus être contacté	Suivi arrêté à sa demande

Chaque changement de statut doit enregistrer la date, l’utilisateur et le motif éventuel.

Attention : l’acceptation de Jésus-Christ ne doit pas être assimilée automatiquement à l’intégration dans l’église. Ce sont deux événements distincts.

Module 6 — Gestion des équipes

Fonctionnalités :

* Création des équipes.
* Affectation des membres.
* Désignation des responsables.
* Consultation des contacts par équipe.
* Statistiques individuelles et collectives.

Exemple :

* Équipe évangélisation A.
* Équipe évangélisation B.
* Équipe accueil dimanche.
* Équipe de suivi.

Module 7 — Gestion des églises de maison

Ce module permettra de gérer les affectations.

Informations :

* Nom ou identifiant de l’église de maison.
* Quartier.
* Responsable.
* Jour et heure de rencontre.
* Liste des personnes intégrées.

Un contact ne sera considéré comme intégré que lorsque l’affectation aura été confirmée.

Module 8 — Notifications et rappels

Exemples :

* Contacts à rappeler aujourd’hui.
* Personnes sans suivi depuis plusieurs jours.
* Visiteurs attendus au prochain culte.
* Nouveaux contacts non affectés.
* Rendez-vous de suivi à venir.

Les notifications seront personnalisées selon les responsabilités des utilisateurs.

Module 9 — Rapports et statistiques

L’application devra produire :

* Rapport hebdomadaire d’évangélisation.
* Rapport mensuel d’accueil.
* Nombre de contacts par équipe.
* Nombre de personnes contactées.
* Nombre de personnes revenues.
* Nombre de personnes intégrées.
* Taux de suivi effectué.

Les exports Excel et PDF pourront être ajoutés dans une version ultérieure si nécessaire.

4. Architecture technique

4.1 Architecture générale

Application mobile Flutter

Android et iOS · Interface · Stockage local · Synchronisation

API REST Laravel

Authentification · Permissions · Validation · Logique métier

Base de données MySQL

Contacts · Utilisateurs · Équipes · Suivis · Historique

Firebase Cloud Messaging : notifications push

OpenStreetMap : cartographie facultative

Je recommande les technologies suivantes :

Couche	Technologie
Mobile	Flutter / Dart
Backend	Laravel
API	REST / JSON
Base de données	MySQL 8
Stockage local	SQLite
Authentification	Laravel Sanctum
Notifications	Firebase
Cartographie	OpenStreetMap
Hébergement	VPS Linux
Versionnement	Git / GitHub

Pourquoi Flutter ? Une seule base de code permettra de produire les versions Android et iOS.

4.2 Organisation du projet

Le projet sera organisé en deux dépôts ou deux répertoires distincts.

eglise-connect/
│
├── backend/
│   ├── app/
│   │   ├── Models/
│   │   ├── Http/
│   │   │   ├── Controllers/
│   │   │   ├── Requests/
│   │   │   └── Resources/
│   │   ├── Services/
│   │   └── Policies/
│   ├── database/
│   │   ├── migrations/
│   │   └── seeders/
│   ├── routes/
│   │   └── api.php
│   └── tests/
│
└── mobile/
    ├── lib/
    │   ├── core/
    │   ├── models/
    │   ├── services/
    │   ├── repositories/
    │   ├── features/
    │   │   ├── authentication/
    │   │   ├── dashboard/
    │   │   ├── contacts/
    │   │   ├── evangelisation/
    │   │   ├── accueil/
    │   │   ├── suivi/
    │   │   ├── equipes/
    │   │   ├── eglises_maison/
    │   │   └── notifications/
    │   └── main.dart
    └── test/

Cette organisation évitera de mélanger les fonctionnalités et facilitera les évolutions.

5. Modèle relationnel de la base de données

Je recommande une base de données structurée autour de 12 tables principales.

5.1 Tables et responsabilités

Table	Rôle
users	Comptes des utilisateurs
roles	Profils et rôles
user_roles	Attribution des rôles
contacts	Dossiers des personnes
contact_events	Rencontres et visites
teams	Équipes de l’église
team_members	Membres des équipes
follow_ups	Actions de suivi
house_churches	Églises de maison
integrations	Affectations aux églises de maison
notifications	Notifications
audit_logs	Traçabilité des actions

Il faudra également prévoir une table consents pour conserver les autorisations de contact, leur date, leur objet et leur éventuel retrait.

5.2 Relations entre les tables

Schéma simplifié

erDiagram
    USERS ||--o{ USER_ROLES : possede
    ROLES ||--o{ USER_ROLES : attribue
    USERS ||--o{ CONTACTS : enregistre
    CONTACTS ||--o{ CONTACT_EVENTS : genere
    CONTACTS ||--o{ FOLLOW_UPS : concerne
    USERS ||--o{ FOLLOW_UPS : effectue
    TEAMS ||--o{ TEAM_MEMBERS : comprend
    USERS ||--o{ TEAM_MEMBERS : appartient
    HOUSE_CHURCHES ||--o{ INTEGRATIONS : accueille
    CONTACTS ||--o{ INTEGRATIONS : integre
    USERS ||--o{ AUDIT_LOGS : effectue

5.3 Champs importants

Table contacts

Champ	Type
id	BIGINT
uuid	UUID
first_name	VARCHAR(100)
last_name	VARCHAR(100)
phone	VARCHAR(30), nullable
gender	VARCHAR(20), nullable
age_range	VARCHAR(30), nullable
neighborhood	VARCHAR(150), nullable
arrondissement	VARCHAR(100), nullable
source	ENUM
status	ENUM
assigned_user_id	BIGINT, nullable
created_by	BIGINT
created_at	TIMESTAMP
updated_at	TIMESTAMP

Table follow_ups

Champ	Type
id	BIGINT
contact_id	BIGINT
user_id	BIGINT
action_type	VARCHAR(50)
description	TEXT
result	VARCHAR(100)
scheduled_at	DATETIME, nullable
completed_at	DATETIME, nullable
created_at	TIMESTAMP

Table contact_events

Elle permettra de conserver les différentes rencontres avec une même personne :

* Première rencontre.
* Visite à l’église.
* Participation à une activité.
* Nouvelle rencontre pendant une campagne.
* Visite dans une église de maison.

Il ne faut surtout pas créer un nouveau contact à chaque rencontre.

5.4 Règles métier importantes

* Un contact peut exister sans numéro de téléphone.
* Un numéro existant déclenche une vérification, pas un rejet automatique.
* Un contact peut avoir plusieurs événements.
* Chaque suivi est rattaché à un utilisateur.
* Une intégration doit être confirmée par un responsable habilité.
* Une personne qui refuse d’être contactée doit être exclue des relances.
* La suppression et la modification des données sensibles doivent être contrôlées et tracées.

6. API REST Laravel

Voici les principaux endpoints à développer.

Méthode	Endpoint	Fonction
POST	/api/login	Connexion
POST	/api/logout	Déconnexion
GET	/api/dashboard	Statistiques
GET	/api/contacts	Liste des contacts
POST	/api/contacts	Création
GET	/api/contacts/{id}	Détail
PUT	/api/contacts/{id}	Modification
GET	/api/contacts/{id}/events	Historique des rencontres
POST	/api/contacts/{id}/events	Ajouter une rencontre
GET	/api/contacts/{id}/follow-ups	Historique de suivi
POST	/api/contacts/{id}/follow-ups	Ajouter un suivi
GET	/api/teams	Liste des équipes
POST	/api/teams	Créer une équipe
GET	/api/house-churches	Églises de maison
POST	/api/integrations	Enregistrer une intégration
POST	/api/sync	Synchronisation mobile

L’API /api/sync sera particulièrement importante pour le mode hors connexion.

7. Fonctionnement hors connexion

Je considère cette fonctionnalité comme indispensable pour les campagnes d’évangélisation.

Scénario :

Un évangéliste se trouve dans un quartier où la connexion Internet est indisponible.

* Il ouvre l’application.
* Il enregistre une nouvelle personne.
* Le contact est sauvegardé dans SQLite sur son téléphone.
* L’application marque le contact comme « En attente de synchronisation ».
* Lorsque la connexion revient, l’application transmet automatiquement les informations au serveur.
* Le serveur confirme l’enregistrement.
* Le contact devient visible pour les responsables habilités.

Cycle de synchronisation

* Enregistrement local sur le téléphone
* Ajout dans la file d’attente
* Détection de la connexion
* Transmission à l’API Laravel
* Vérification et validation serveur
* Confirmation et mise à jour locale

Chaque enregistrement devra avoir un UUID généré sur le téléphone afin d’éviter les doublons lors des tentatives de synchronisation.

En cas de modification simultanée d’une fiche, il faudra prévoir une règle de résolution des conflits, sans écraser silencieusement les informations.

8. Sécurité et confidentialité

Les données personnelles et les informations relatives aux convictions religieuses nécessitent une protection renforcée.

Je recommande :

* HTTPS obligatoire.
* Mots de passe hachés.
* Tokens d’accès avec expiration et révocation.
* Permissions vérifiées côté serveur.
* Chiffrement du stockage local lorsque nécessaire.
* Sauvegardes régulières et testées.
* Journalisation des modifications.
* Limitation des exports.
* Politique de conservation et de suppression des données.
* Consentement explicite avant les appels, SMS ou messages WhatsApp de suivi.
* Possibilité de retirer son accord et de demander la suppression de ses données.

Il faudra éviter d’enregistrer des détails personnels ou spirituels qui ne sont pas nécessaires à l’accompagnement.

9. Conception de l’interface mobile

Je recommande une interface sobre, moderne et chaleureuse, avec une identité visuelle inspirée de l’univers de l’église, sans tomber dans un design trop religieux ou chargé.

Navigation principale

Je recommande une barre de navigation inférieure avec cinq rubriques :

Accueil

Contacts

Ajouter

Suivi

Profil

Illustration de la navigation prévue dans l’application.

L’action « Ajouter » sera centrale et facilement accessible, notamment pendant les campagnes d’évangélisation.

10. Plan de développement

Je te conseille de procéder par étapes pour obtenir rapidement une première application fonctionnelle.

Phase	Travaux	Livrable
1	Architecture et base de données	Backend initialisé
2	Authentification et habilitations	Comptes fonctionnels
3	Enregistrement des contacts	Module opérationnel
4	Fiches et historique	Gestion des contacts
5	Suivi et relances	Workflow complet
6	Équipes et églises de maison	Gestion organisationnelle
7	Tableau de bord	Statistiques
8	Mode hors connexion	Synchronisation
9	Notifications et tests	Version bêta
10	Déploiement	Application opérationnelle

Mon conseil : ne commence pas par la cartographie, les notifications complexes ou les graphiques. Il faut d’abord réussir le cycle complet : enregistrer une personne, la retrouver, la recontacter et confirmer son intégration.

11. Périmètre de la première version (MVP)

Pour éviter de développer trop de choses simultanément, voici ce que je retiendrais pour la V1.

Version 1.0

Prioritaire

Périmètre de développement

0/11

Connexion et gestion des utilisateurs

Gestion des rôles et permissions

Enregistrement des contacts

Gestion des doublons

Liste et recherche des contacts

Fiche individuelle et historique

Gestion des suivis

Gestion des équipes

Tableau de bord statistique

Mode hors connexion et synchronisation

Protection et traçabilité des données

Version 1.1 : QR Code visiteurs, cartographie, notifications avancées, rapports PDF/Excel et gestion approfondie des églises de maison.

12. Critères de validation avant lancement

L’application sera considérée comme prête lorsque les tests auront confirmé que :

* Deux utilisateurs peuvent enregistrer des contacts simultanément.
* Un même contact n’est pas créé plusieurs fois accidentellement.
* Les permissions sont respectées.
* Les historiques sont conservés.
* Les responsables voient les statistiques correspondant à leurs habilitations.
* Les contacts enregistrés hors connexion sont synchronisés sans perte.
* Les personnes ayant refusé les relances ne sont plus sollicitées.
* Les sauvegardes peuvent être restaurées.

13. Les décisions à prendre avant de commencer le code

Il reste quatre décisions métier qui vont influencer directement la base de données et les interfaces.

1. Identité de l’église

ICC Mafouta / Mansimou

Autre église locale

Nom et logo configurables

2. Qui peut enregistrer un contact ?

Tous les membres autorisés (accueil et évangélisation)

Uniquement les responsables d’équipe

Évangélistes et agents d’accueil uniquement

3. Qui doit assurer le suivi ?

Un responsable est automatiquement affecté au contact

La personne qui enregistre assure le suivi

Une équipe centrale de suivi gère tous les contacts

4. Langue de l’application

Français uniquement

Français et anglais

Valider les décisions

Ma recommandation pour la suite : commencer par le schéma SQL complet et les migrations Laravel, puis construire l’API et enfin les écrans Flutter. Cela permettra de disposer rapidement d’un socle technique propre et évolutif.

Je peux également préparer le prochain livrable : le schéma SQL complet, les migrations Laravel et les données initiales de l’application.

Préparer le dossier technique demain

Architecture proposée : Flutter, Laravel et MySQL. Les choix techniques restent à valider avant implémentation.