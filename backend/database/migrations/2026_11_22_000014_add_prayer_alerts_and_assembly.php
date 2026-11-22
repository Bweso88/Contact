<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * - users.assembly : assemblée de l'intercesseur (affichée pendant qu'il prie) ;
 * - prayer_sessions.end_warning_minutes : alerte sonore « votre temps finit dans X min »,
 *   réglée par l'organisateur ;
 * - prayer_turns.auto_ended : tour clos automatiquement à la fin du créneau.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('assembly', 150)->nullable()->after('phone');
        });

        Schema::table('prayer_sessions', function (Blueprint $table) {
            $table->unsignedSmallInteger('end_warning_minutes')->default(5)->after('ends_at');
        });

        Schema::table('prayer_turns', function (Blueprint $table) {
            $table->boolean('auto_ended')->default(false)->after('ended_at');
        });
    }

    public function down(): void
    {
        Schema::table('prayer_turns', fn (Blueprint $t) => $t->dropColumn('auto_ended'));
        Schema::table('prayer_sessions', fn (Blueprint $t) => $t->dropColumn('end_warning_minutes'));
        Schema::table('users', fn (Blueprint $t) => $t->dropColumn('assembly'));
    }
};
