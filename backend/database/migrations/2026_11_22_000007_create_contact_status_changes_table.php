<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * « Chaque changement de statut doit enregistrer la date, l'utilisateur et
 * le motif éventuel. » Table en ajout seul : on n'y modifie ni ne supprime rien.
 * Elle sert aussi aux statistiques (ex. intégrations du mois).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('contact_status_changes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('contact_id')->constrained()->cascadeOnDelete();
            $table->string('from_status', 30)->nullable();
            $table->string('to_status', 30)->index();
            $table->string('reason')->nullable();
            $table->foreignId('changed_by')->constrained('users');
            $table->timestamp('changed_at')->index();

            $table->index(['contact_id', 'changed_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('contact_status_changes');
    }
};
