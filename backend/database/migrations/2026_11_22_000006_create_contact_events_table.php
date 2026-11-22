<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('contact_events', function (Blueprint $table) {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->foreignId('contact_id')->constrained()->cascadeOnDelete();
            $table->string('type', 40)->index();     // App\Enums\ContactEventType
            $table->dateTime('occurred_at')->index();
            $table->string('location', 150)->nullable();
            $table->foreignId('team_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('house_church_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('recorded_by')->constrained('users');
            $table->text('notes')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['contact_id', 'occurred_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('contact_events');
    }
};
