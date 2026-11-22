<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Chaîne de prière : sessions planifiées, créneaux attribués aux intercesseurs,
 * tours de prière (« Je prends la main » / « Je rends la main ») et mur de messages.
 *
 * Aucun enregistrement audio : on ne garde que qui a prié, quand, et combien de temps.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('prayer_sessions', function (Blueprint $table) {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->string('title', 150);
            $table->text('description')->nullable();
            $table->dateTime('starts_at')->index();
            $table->dateTime('ends_at');
            $table->string('whatsapp_group_url')->nullable();
            $table->foreignId('created_by')->constrained('users');
            $table->timestamps();
            $table->softDeletes();
        });

        Schema::create('prayer_slots', function (Blueprint $table) {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->foreignId('prayer_session_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained();
            $table->dateTime('starts_at');
            $table->dateTime('ends_at');
            $table->timestamps();

            $table->index(['prayer_session_id', 'starts_at']);
            $table->index(['user_id', 'starts_at']);
        });

        Schema::create('prayer_turns', function (Blueprint $table) {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->foreignId('prayer_session_id')->constrained()->cascadeOnDelete();
            $table->foreignId('prayer_slot_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('user_id')->constrained();
            $table->string('visual', 10);              // App\Enums\PrayerVisual : feu, eau
            $table->dateTime('started_at');
            $table->dateTime('ended_at')->nullable();
            $table->timestamps();

            // « Une seule main à la fois », garanti par la base elle-même :
            // la colonne vaut l'id de la session tant que le tour est ouvert, NULL ensuite.
            // L'index unique interdit donc deux tours ouverts dans la même session,
            // même si deux personnes touchent le bouton à la même seconde.
            $table->unsignedBigInteger('open_session_lock')
                ->nullable()
                ->storedAs('CASE WHEN ended_at IS NULL THEN prayer_session_id END')
                ->unique();

            $table->index(['prayer_session_id', 'started_at']);
        });

        Schema::create('prayer_messages', function (Blueprint $table) {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->foreignId('prayer_session_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained();
            $table->string('body', 500);
            $table->timestamp('created_at')->useCurrent();
            $table->softDeletes();

            $table->index(['prayer_session_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('prayer_messages');
        Schema::dropIfExists('prayer_turns');
        Schema::dropIfExists('prayer_slots');
        Schema::dropIfExists('prayer_sessions');
    }
};
