<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Affectation d'un contact à une église de maison.
 * Le contact n'est « Intégré » qu'une fois l'affectation confirmée
 * par un responsable habilité (permission integrations.confirm).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('integrations', function (Blueprint $table) {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->foreignId('contact_id')->constrained()->cascadeOnDelete();
            $table->foreignId('house_church_id')->constrained();
            $table->string('status', 20)->default('proposee')->index(); // App\Enums\IntegrationStatus
            $table->foreignId('proposed_by')->constrained('users');
            $table->timestamp('proposed_at');
            $table->foreignId('confirmed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('confirmed_at')->nullable()->index();
            $table->timestamp('ended_at')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->index(['contact_id', 'status']);
            $table->index(['house_church_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('integrations');
    }
};
