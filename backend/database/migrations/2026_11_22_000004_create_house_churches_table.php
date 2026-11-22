<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('house_churches', function (Blueprint $table) {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->string('name', 120)->unique();
            $table->string('neighborhood', 150)->nullable()->index();
            $table->string('arrondissement', 100)->nullable();
            $table->string('address_hint')->nullable();
            $table->foreignId('leader_id')->nullable()->constrained('users')->nullOnDelete();
            $table->unsignedTinyInteger('meeting_day')->nullable(); // 1 = lundi … 7 = dimanche (ISO-8601)
            $table->time('meeting_time')->nullable();
            $table->unsignedSmallInteger('capacity')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->softDeletes();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('house_churches');
    }
};
