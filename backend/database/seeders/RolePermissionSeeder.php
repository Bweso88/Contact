<?php

namespace Database\Seeders;

use App\Enums\RoleSlug;
use App\Models\Permission;
use App\Models\Role;
use Illuminate\Database\Seeder;

/**
 * Profils et habilitations (section 2 du cahier des charges).
 * Idempotent : on peut le relancer après avoir ajouté une permission.
 */
class RolePermissionSeeder extends Seeder
{
    /** slug => [libellé, groupe] */
    private const PERMISSIONS = [
        'users.manage' => ['Gérer les comptes utilisateurs', 'administration'],
        'roles.manage' => ['Attribuer les rôles', 'administration'],
        'settings.manage' => ['Modifier les réglages de l’église', 'administration'],
        'audit_logs.view' => ['Consulter le journal des modifications', 'administration'],

        'dashboard.view_global' => ['Tableau de bord de toute l’église', 'tableau_de_bord'],
        'dashboard.view_team' => ['Tableau de bord de ses équipes', 'tableau_de_bord'],
        'reports.view' => ['Consulter les rapports', 'tableau_de_bord'],

        'contacts.create' => ['Enregistrer un contact', 'contacts'],
        'contacts.view_own' => ['Voir ses propres contacts', 'contacts'],
        'contacts.view_team' => ['Voir les contacts de ses équipes', 'contacts'],
        'contacts.view_all' => ['Voir tous les contacts', 'contacts'],
        'contacts.update' => ['Modifier les contacts visibles', 'contacts'],
        'contacts.assign' => ['Changer le responsable du suivi', 'contacts'],
        'contacts.delete' => ['Supprimer un contact', 'contacts'],
        'contacts.export' => ['Exporter des contacts', 'contacts'],

        'follow_ups.create' => ['Ajouter un suivi', 'suivi'],
        'follow_ups.update_own' => ['Modifier ses propres suivis', 'suivi'],
        'follow_ups.update_all' => ['Modifier les suivis des autres', 'suivi'],
        'consents.manage' => ['Enregistrer / retirer un consentement', 'suivi'],

        'teams.view' => ['Voir les équipes', 'organisation'],
        'teams.manage' => ['Gérer les équipes', 'organisation'],
        'house_churches.view' => ['Voir les églises de maison', 'organisation'],
        'house_churches.manage' => ['Gérer les églises de maison', 'organisation'],
        'integrations.propose' => ['Proposer une intégration', 'organisation'],
        'integrations.confirm' => ['Confirmer une intégration', 'organisation'],

        'prayer.access' => ['Participer à la chaîne de prière', 'priere'],
        'prayer.manage' => ['Planifier les chaînes de prière', 'priere'],
    ];

    private function matrix(): array
    {
        $responsableEquipe = [
            'dashboard.view_team', 'reports.view',
            'contacts.create', 'contacts.view_own', 'contacts.view_team', 'contacts.update', 'contacts.assign',
            'follow_ups.create', 'follow_ups.update_own', 'consents.manage',
            'teams.view', 'house_churches.view', 'integrations.propose',
        ];

        return [
            // L'administrateur passe tous les contrôles (Gate::before),
            // on lui donne quand même tout pour que la liste soit lisible.
            RoleSlug::Administrateur->value => array_keys(self::PERMISSIONS),

            RoleSlug::ResponsableEglise->value => array_values(array_diff(
                array_keys(self::PERMISSIONS),
                ['users.manage', 'roles.manage', 'settings.manage', 'contacts.delete']
            )),

            RoleSlug::ResponsableEvangelisation->value => $responsableEquipe,
            RoleSlug::ResponsableAccueil->value => $responsableEquipe,

            RoleSlug::ResponsableSuivi->value => [
                'dashboard.view_global', 'reports.view',
                'contacts.view_all', 'contacts.update', 'contacts.assign',
                'follow_ups.create', 'follow_ups.update_own', 'follow_ups.update_all', 'consents.manage',
                'teams.view', 'house_churches.view', 'integrations.propose', 'integrations.confirm',
            ],

            RoleSlug::Evangeliste->value => [
                'contacts.create', 'contacts.view_own',
                'follow_ups.create', 'follow_ups.update_own', 'consents.manage',
                'house_churches.view',
            ],

            RoleSlug::AgentAccueil->value => [
                'contacts.create', 'contacts.view_own', 'consents.manage',
            ],

            // Module à part : un intercesseur ne voit pas les contacts.
            RoleSlug::ResponsablePriere->value => ['prayer.access', 'prayer.manage'],
            RoleSlug::Intercesseur->value => ['prayer.access'],
        ];
    }

    public function run(): void
    {
        foreach (self::PERMISSIONS as $slug => [$name, $group]) {
            Permission::updateOrCreate(['slug' => $slug], ['name' => $name, 'group' => $group]);
        }

        $ids = Permission::pluck('id', 'slug');

        foreach ($this->matrix() as $roleSlug => $permissions) {
            $role = Role::updateOrCreate(
                ['slug' => $roleSlug],
                ['name' => RoleSlug::from($roleSlug)->label()]
            );
            $role->permissions()->sync($ids->only($permissions)->values());
        }
    }
}
