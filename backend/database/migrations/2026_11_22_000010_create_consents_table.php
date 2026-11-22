<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Autorisations de contact : objet, canal, date, et retrait éventuel.
 * On ne supprime jamais une ligne : un retrait renseigne withdrawn_at,
 * ce qui garde la preuve de ce qui avait été accepté et quand.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('consents', function (Blueprint $table) {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->foreignId('contact_id')->constrained()->cascadeOnDelete();
            $table->string('purpose', 40);                 // App\Enums\ConsentPurpose
            $table->string('channel', 20)->nullable();     // App\Enums\ContactChannel (null = tous canaux)
            $table->string('method', 20)->default('oral'); // oral, ecrit, formulaire
            $table->timestamp('granted_at');
            $table->foreignId('collected_by')->constrained('users');
            $table->timestamp('withdrawn_at')->nullable();
            $table->foreignId('withdrawn_recorded_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('notes')->nullable();
            $table->timestamps();

            $table->index(['contact_id', 'purpose', 'withdrawn_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('consents');
    }
};
