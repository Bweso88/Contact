<?php

namespace Database\Seeders;

use App\Enums\ContactEventType;
use App\Enums\ContactSource;
use App\Enums\ContactStatus;
use App\Enums\FollowUpActionType;
use App\Enums\FollowUpResult;
use App\Enums\RoleSlug;
use App\Enums\TeamType;
use App\Models\Contact;
use App\Models\HouseChurch;
use App\Models\Integration;
use App\Models\Role;
use App\Models\Team;
use App\Models\User;
use Illuminate\Database\Seeder;

/**
 * Jeu de démonstration (environnement local uniquement).
 * Mot de passe de tous les comptes de démo : « password ».
 */
class DemoSeeder extends Seeder
{
    public function run(): void
    {
        $roles = Role::pluck('id', 'slug');
        $user = function (string $username, string $name, RoleSlug ...$slugs) use ($roles): User {
            $u = User::factory()->create(['username' => $username, 'name' => $name]);
            $u->roles()->attach($roles->only(array_map(fn ($s) => $s->value, $slugs))->values());

            return $u;
        };

        $pasteur = $user('pasteur', 'Pasteur Démo', RoleSlug::ResponsableEglise);
        $respEvang = $user('resp.evang', 'Responsable Évangélisation', RoleSlug::ResponsableEvangelisation);
        $respAccueil = $user('resp.accueil', 'Responsable Accueil', RoleSlug::ResponsableAccueil);
        $respSuivi = $user('resp.suivi', 'Responsable Suivi', RoleSlug::ResponsableSuivi);
        $evangelistes = collect(range(1, 4))->map(fn ($i) => $user("evangeliste{$i}", "Évangéliste {$i}", RoleSlug::Evangeliste));
        $agents = collect(range(1, 2))->map(fn ($i) => $user("accueil{$i}", "Agent d’accueil {$i}", RoleSlug::AgentAccueil));

        // ── Équipes ──
        $teamA = Team::create(['name' => 'Équipe évangélisation A', 'type' => TeamType::Evangelisation, 'leader_id' => $respEvang->id]);
        $teamB = Team::create(['name' => 'Équipe évangélisation B', 'type' => TeamType::Evangelisation, 'leader_id' => $respEvang->id]);
        $teamAccueil = Team::create(['name' => 'Équipe accueil dimanche', 'type' => TeamType::Accueil, 'leader_id' => $respAccueil->id]);
        Team::create(['name' => 'Équipe de suivi', 'type' => TeamType::Suivi, 'leader_id' => $respSuivi->id])
            ->members()->attach($respSuivi->id, ['is_leader' => true, 'joined_at' => now()]);

        $teamA->members()->attach($respEvang->id, ['is_leader' => true, 'joined_at' => now()]);
        $teamA->members()->attach($evangelistes->take(2)->pluck('id'), ['joined_at' => now()]);
        $teamB->members()->attach($evangelistes->slice(2)->pluck('id'), ['joined_at' => now()]);
        $teamAccueil->members()->attach($respAccueil->id, ['is_leader' => true, 'joined_at' => now()]);
        $teamAccueil->members()->attach($agents->pluck('id'), ['joined_at' => now()]);

        // ── Églises de maison ──
        $maisons = collect([
            ['Église de maison Mafouta 1', 'Mafouta', 'Djiri', 3, '18:30'],
            ['Église de maison Mansimou', 'Mansimou', 'Madibou', 4, '18:00'],
            ['Église de maison Kinsoundi', 'Kinsoundi', 'Makélékélé', 5, '18:30'],
        ])->map(fn ($m) => HouseChurch::create([
            'name' => $m[0], 'neighborhood' => $m[1], 'arrondissement' => $m[2],
            'leader_id' => $pasteur->id, 'meeting_day' => $m[3], 'meeting_time' => $m[4],
        ]));

        // ── Contacts ──
        $recorders = [
            [$teamA, $evangelistes->take(2), ContactSource::Evangelisation],
            [$teamB, $evangelistes->slice(2), ContactSource::Evangelisation],
            [$teamAccueil, $agents, ContactSource::Accueil],
        ];

        $statuses = [ContactStatus::AContacter, ContactStatus::Contacte, ContactStatus::Invite, ContactStatus::PremiereVisite, ContactStatus::EnAccompagnement];

        foreach ($recorders as [$team, $members, $source]) {
            foreach (range(1, 12) as $_) {
                $by = $members->random();
                $contact = Contact::factory()->create([
                    'team_id' => $team->id,
                    'created_by' => $by->id,
                    'source' => $source,
                ]);

                $contact->events()->create([
                    'type' => $source === ContactSource::Accueil ? ContactEventType::VisiteCulte : ContactEventType::PremiereRencontre,
                    'occurred_at' => $contact->first_met_at,
                    'team_id' => $team->id,
                    'recorded_by' => $by->id,
                ]);

                if ($contact->do_not_contact) {
                    $contact->changeStatus(ContactStatus::NePlusContacter, $by, 'Ne souhaite pas être recontacté');
                    continue;
                }

                $contact->consents()->create([
                    'purpose' => 'suivi', 'method' => 'oral',
                    'granted_at' => $contact->first_met_at, 'collected_by' => $by->id,
                ]);

                $status = fake()->randomElement($statuses);
                $contact->changeStatus($status, $respSuivi, 'Données de démonstration');

                if ($status !== ContactStatus::AContacter) {
                    $contact->followUps()->create([
                        'user_id' => $contact->assigned_user_id ?? $respSuivi->id,
                        'action_type' => FollowUpActionType::Appel,
                        'result' => FollowUpResult::Joint,
                        'description' => 'Premier appel de suivi.',
                        'completed_at' => now()->subDays(random_int(1, 20)),
                    ]);
                } else {
                    $contact->followUps()->create([
                        'user_id' => $contact->assigned_user_id ?? $respSuivi->id,
                        'action_type' => FollowUpActionType::Appel,
                        'scheduled_at' => now()->addDays(random_int(0, 3)),
                    ]);
                }

                if (in_array($status, [ContactStatus::PremiereVisite, ContactStatus::EnAccompagnement], true)) {
                    $contact->events()->create([
                        'type' => ContactEventType::VisiteCulte,
                        'occurred_at' => now()->subDays(random_int(1, 14)),
                        'recorded_by' => $agents->random()->id,
                    ]);
                }
            }
        }

        // Quelques intégrations : une proposée, deux confirmées.
        Contact::where('status', ContactStatus::EnAccompagnement->value)->take(3)->get()
            ->each(function (Contact $c, int $i) use ($maisons, $respSuivi, $pasteur) {
                $integration = Integration::create([
                    'contact_id' => $c->id,
                    'house_church_id' => $maisons->random()->id,
                    'proposed_by' => $respSuivi->id,
                ]);
                if ($i > 0) {
                    $integration->confirm($pasteur);
                }
            });
    }
}
