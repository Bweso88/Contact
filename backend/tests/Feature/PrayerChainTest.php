<?php

namespace Tests\Feature;

use App\Enums\PrayerVisual;
use App\Enums\RoleSlug;
use App\Models\PrayerSession;
use App\Models\PrayerTurn;
use App\Models\Role;
use App\Models\User;
use Database\Seeders\RolePermissionSeeder;
use DomainException;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** Lancer : php artisan test --filter=PrayerChainTest */
class PrayerChainTest extends TestCase
{
    use RefreshDatabase;

    private PrayerSession $session;
    private User $marc;
    private User $grace;
    private User $responsable;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(RolePermissionSeeder::class);

        $this->marc = $this->userWithRole(RoleSlug::Intercesseur);
        $this->grace = $this->userWithRole(RoleSlug::Intercesseur);
        $this->responsable = $this->userWithRole(RoleSlug::ResponsablePriere);

        $this->session = PrayerSession::create([
            'title' => 'Chaîne de prière du vendredi',
            'starts_at' => now()->subHour(),
            'ends_at' => now()->addHours(3),
            'created_by' => $this->responsable->id,
        ]);

        // Marc : créneau en cours. Grâce : créneau suivant, dans 1 heure.
        $this->session->slots()->create(['user_id' => $this->marc->id, 'starts_at' => now()->subMinutes(5), 'ends_at' => now()->addMinutes(55)]);
        $this->session->slots()->create(['user_id' => $this->grace->id, 'starts_at' => now()->addMinutes(55), 'ends_at' => now()->addMinutes(115)]);
    }

    private function userWithRole(RoleSlug $role): User
    {
        $user = User::factory()->create();
        $user->roles()->attach(Role::where('slug', $role->value)->value('id'));

        return $user->fresh();
    }

    public function test_l_intercesseur_prend_la_main_pendant_son_creneau(): void
    {
        $turn = PrayerTurn::take($this->session, $this->marc, PrayerVisual::Feu);

        $this->assertSame(PrayerVisual::Feu, $turn->visual);
        $this->assertTrue($this->session->currentTurn()->first()->is($turn));
        $this->assertNotNull($turn->prayer_slot_id);
    }

    public function test_hors_de_son_creneau_on_ne_peut_pas_prendre_la_main(): void
    {
        $this->expectException(DomainException::class);
        PrayerTurn::take($this->session, $this->grace, PrayerVisual::Eau);
    }

    public function test_une_seule_main_a_la_fois(): void
    {
        PrayerTurn::take($this->session, $this->marc, PrayerVisual::Feu);

        // Même le responsable doit attendre que Marc rende la main.
        $this->expectException(DomainException::class);
        PrayerTurn::take($this->session, $this->responsable, PrayerVisual::Eau);
    }

    public function test_la_base_refuse_deux_tours_ouverts(): void
    {
        PrayerTurn::take($this->session, $this->marc, PrayerVisual::Feu);

        // Contourne les vérifications PHP : l'index unique doit tout de même bloquer.
        $this->expectException(\Illuminate\Database\QueryException::class);
        PrayerTurn::create([
            'prayer_session_id' => $this->session->id,
            'user_id' => $this->grace->id,
            'visual' => PrayerVisual::Eau,
            'started_at' => now(),
        ]);
    }

    public function test_rendre_la_main_libere_la_flamme(): void
    {
        $turn = PrayerTurn::take($this->session, $this->marc, PrayerVisual::Feu);

        try {
            $turn->release($this->grace);
            $this->fail('Grâce ne doit pas pouvoir rendre la main de Marc.');
        } catch (AuthorizationException) {
        }

        $turn->release($this->marc);

        $this->assertNull($this->session->currentTurn()->first());
        // Après Marc, le responsable peut prendre la main (gestion des trous de planning).
        $this->assertNotNull(PrayerTurn::take($this->session, $this->responsable, PrayerVisual::Eau));
    }

    public function test_le_tour_se_clot_a_la_fin_du_creneau(): void
    {
        $turn = PrayerTurn::take($this->session, $this->marc, PrayerVisual::Feu);

        // Une heure plus tard, le créneau de Marc est terminé et celui de Grâce a commencé.
        $this->travel(61)->minutes();

        $this->assertTrue($this->session->closeExpiredTurn()?->is($turn));
        $turn->refresh();
        $this->assertTrue($turn->auto_ended);
        $this->assertNotNull($turn->ended_at);

        // La main est libre : on attend que Grâce la prenne.
        $this->assertTrue($this->session->isWaitingForHand());
        PrayerTurn::take($this->session, $this->grace, PrayerVisual::Eau);
        $this->assertFalse($this->session->isWaitingForHand());
    }

    public function test_grace_peut_prendre_la_main_meme_si_marc_a_oublie_de_la_rendre(): void
    {
        PrayerTurn::take($this->session, $this->marc, PrayerVisual::Feu);
        $this->travel(61)->minutes();

        // take() clôt d'abord le tour expiré de Marc.
        $turn = PrayerTurn::take($this->session, $this->grace, PrayerVisual::Eau);
        $this->assertSame($this->grace->id, $turn->user_id);
    }
}
