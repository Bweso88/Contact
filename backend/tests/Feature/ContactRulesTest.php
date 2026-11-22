<?php

namespace Tests\Feature;

use App\Enums\ContactSource;
use App\Enums\ContactStatus;
use App\Enums\RoleSlug;
use App\Models\Contact;
use App\Models\HouseChurch;
use App\Models\Integration;
use App\Models\Role;
use App\Models\User;
use Database\Seeders\RolePermissionSeeder;
use Database\Seeders\SettingsSeeder;
use DomainException;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Règles métier de la section 5.4 du cahier des charges.
 * Lancer : php artisan test --filter=ContactRulesTest
 */
class ContactRulesTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([RolePermissionSeeder::class, SettingsSeeder::class]);
    }

    private function userWithRole(RoleSlug $role): User
    {
        $user = User::factory()->create();
        $user->roles()->attach(Role::where('slug', $role->value)->value('id'));

        return $user->fresh();
    }

    private function newContact(User $by, array $attrs = []): Contact
    {
        return Contact::create(array_merge([
            'first_name' => 'Grâce',
            'last_name' => 'Mabiala',
            'phone' => '06 123 45 67',
            'source' => ContactSource::Evangelisation,
            'first_met_at' => now(),
            'created_by' => $by->id,
        ], $attrs));
    }

    public function test_un_contact_peut_exister_sans_telephone(): void
    {
        $contact = $this->newContact($this->userWithRole(RoleSlug::Evangeliste), ['phone' => null]);

        $this->assertNull($contact->phone_normalized);
        $this->assertSame(ContactStatus::Nouveau, $contact->status);
    }

    public function test_un_numero_existant_est_detecte_quel_que_soit_le_format(): void
    {
        $by = $this->userWithRole(RoleSlug::Evangeliste);
        $this->newContact($by, ['phone' => '06 123 45 67']);

        $this->assertSame(1, Contact::samePhoneAs('+242 061234567')->count());
        $this->assertSame(1, Contact::samePhoneAs('00242-06-123-45-67')->count());
        $this->assertSame(0, Contact::samePhoneAs('06 999 99 99')->count());

        // Vérification, pas rejet : un second dossier reste possible si l'utilisateur le décide.
        $this->newContact($by, ['first_name' => 'Autre', 'phone' => '061234567']);
        $this->assertSame(2, Contact::samePhoneAs('061234567')->count());
    }

    public function test_chaque_changement_de_statut_est_historise(): void
    {
        $by = $this->userWithRole(RoleSlug::ResponsableSuivi);
        $contact = $this->newContact($by);

        $contact->changeStatus(ContactStatus::Contacte, $by, 'Premier appel');

        $this->assertSame(2, $contact->statusChanges()->count()); // création + changement
        $last = $contact->statusChanges()->first();
        $this->assertSame(ContactStatus::Contacte, $last->to_status);
        $this->assertSame('Premier appel', $last->reason);
        $this->assertSame($by->id, $last->changed_by);
        $this->assertSame(2, $contact->fresh()->version);
    }

    public function test_integre_ne_peut_pas_etre_pose_a_la_main(): void
    {
        $by = $this->userWithRole(RoleSlug::ResponsableSuivi);
        $contact = $this->newContact($by);

        $this->expectException(DomainException::class);
        $contact->changeStatus(ContactStatus::Integre, $by);
    }

    public function test_seul_un_responsable_habilite_confirme_une_integration(): void
    {
        $evangeliste = $this->userWithRole(RoleSlug::Evangeliste);
        $respSuivi = $this->userWithRole(RoleSlug::ResponsableSuivi);
        $contact = $this->newContact($evangeliste);
        $maison = HouseChurch::create(['name' => 'Église de maison Mafouta 1']);

        $integration = Integration::create([
            'contact_id' => $contact->id,
            'house_church_id' => $maison->id,
            'proposed_by' => $evangeliste->id,
        ]);

        try {
            $integration->confirm($evangeliste);
            $this->fail('Un évangéliste ne doit pas pouvoir confirmer une intégration.');
        } catch (AuthorizationException) {
            $this->assertSame(ContactStatus::Nouveau, $contact->fresh()->status);
        }

        $integration->confirm($respSuivi);

        $this->assertSame(ContactStatus::Integre, $contact->fresh()->status);
        $this->assertTrue($contact->hasConfirmedIntegration());
    }

    public function test_un_refus_exclut_des_relances(): void
    {
        $by = $this->userWithRole(RoleSlug::Evangeliste);
        $ok = $this->newContact($by, ['phone' => '061111111']);
        $this->newContact($by, ['phone' => '062222222', 'wants_contact' => false]);

        $consentContact = $this->newContact($by, ['phone' => '063333333']);
        $consent = $consentContact->consents()->create([
            'purpose' => 'suivi', 'granted_at' => now(), 'collected_by' => $by->id,
        ]);
        $consent->withdraw($by);

        $reachable = Contact::reachable()->pluck('id')->all();

        $this->assertSame([$ok->id], $reachable);
        $this->assertSame(ContactStatus::NePlusContacter, $consentContact->fresh()->status);
    }

    public function test_un_evangeliste_ne_voit_que_ses_contacts(): void
    {
        $e1 = $this->userWithRole(RoleSlug::Evangeliste);
        $e2 = $this->userWithRole(RoleSlug::Evangeliste);
        $respSuivi = $this->userWithRole(RoleSlug::ResponsableSuivi);

        $this->newContact($e1, ['phone' => '061111111']);
        $this->newContact($e2, ['phone' => '062222222']);

        $this->assertSame(1, Contact::visibleTo($e1)->count());
        $this->assertSame(2, Contact::visibleTo($respSuivi)->count());
    }
}
