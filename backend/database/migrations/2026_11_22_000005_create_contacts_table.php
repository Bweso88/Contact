<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Un seul dossier par personne. Les rencontres successives vont dans
 * contact_events, jamais dans un nouveau contact.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('contacts', function (Blueprint $table) {
            $table->id();
            // Généré sur le téléphone : rend la synchronisation idempotente.
            $table->uuid('uuid')->unique();

            // A. Identité
            $table->string('first_name', 100);
            $table->string('last_name', 100);
            $table->string('phone', 30)->nullable();
            // Chiffres seuls, indicatif inclus (ex. 242061234567).
            // Indexé mais PAS unique : un doublon déclenche une vérification, pas un rejet.
            $table->string('phone_normalized', 20)->nullable()->index();
            $table->string('gender', 20)->nullable();        // App\Enums\Gender
            $table->string('age_range', 30)->nullable();     // App\Enums\AgeRange

            // B. Localisation
            $table->string('neighborhood', 150)->nullable()->index();
            $table->string('arrondissement', 100)->nullable()->index();
            $table->string('address_hint')->nullable();

            // C. Origine et D. Suivi
            $table->string('source', 30)->index();           // App\Enums\ContactSource
            $table->string('status', 30)->default('nouveau')->index(); // App\Enums\ContactStatus
            $table->timestamp('status_changed_at')->nullable();
            $table->date('first_met_at');
            $table->foreignId('team_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('assigned_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('invited_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('created_by')->constrained('users');
            $table->boolean('wants_contact')->default(true);
            $table->string('preferred_channel', 20)->nullable(); // App\Enums\ContactChannel
            // Mis à vrai dès qu'un consentement « suivi » est retiré : exclu de toute relance.
            $table->boolean('do_not_contact')->default(false)->index();

            // E. Souhaits facultatifs (null = question non posée)
            $table->boolean('wants_spiritual_support')->nullable();
            $table->boolean('wants_service_invitation')->nullable();
            $table->boolean('wants_house_church')->nullable();

            // Dénormalisé pour l'alerte « sans suivi depuis X jours ».
            $table->timestamp('last_follow_up_at')->nullable()->index();

            // Verrou optimiste : le mobile renvoie la version qu'il a modifiée.
            // Si elle ne correspond plus, il y a conflit → pas d'écrasement silencieux.
            $table->unsignedInteger('version')->default(1);

            $table->timestamps();
            $table->softDeletes();

            $table->index(['last_name', 'first_name']);
            $table->index(['status', 'assigned_user_id']);
            $table->index('updated_at'); // curseur de synchronisation
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('contacts');
    }
};
