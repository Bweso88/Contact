<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Un suivi peut être programmé (scheduled_at, sans completed_at)
 * puis réalisé (completed_at + result).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('follow_ups', function (Blueprint $table) {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->foreignId('contact_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained();           // auteur / responsable de l'action
            $table->string('action_type', 30)->index();            // App\Enums\FollowUpActionType
            $table->text('description')->nullable();
            $table->string('result', 30)->nullable();              // App\Enums\FollowUpResult
            $table->dateTime('scheduled_at')->nullable();
            $table->dateTime('completed_at')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['contact_id', 'created_at']);
            // « Contacts à rappeler aujourd'hui » pour un utilisateur donné.
            $table->index(['user_id', 'completed_at', 'scheduled_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('follow_ups');
    }
};
