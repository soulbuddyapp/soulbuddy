<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('prayer_people', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('name', 120);
            $table->string('relationship', 80)->nullable();
            $table->enum('cadence', ['daily', 'weekly', 'selected_days']);
            $table->string('local_time', 5)->nullable();
            $table->string('timezone', 100)->nullable();
            $table->unsignedTinyInteger('weekdays_mask')->default(0);
            $table->timestamps();
            $table->timestamp('archived_at')->nullable();
            $table->unique(['id', 'user_id']);
            $table->index(['user_id', 'name']);
        });

        Schema::create('person_prayer_occurrences', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('person_id');
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->date('local_date');
            $table->string('occurrence_key', 180);
            $table->timestamp('prayed_at');
            $table->string('device_id', 120);
            $table->unique(['user_id', 'occurrence_key']);
            $table->foreign(['person_id', 'user_id'])
                ->references(['id', 'user_id'])
                ->on('prayer_people')
                ->cascadeOnDelete();
        });

        Schema::create('encounter_person_links', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('encounter_id');
            $table->uuid('person_id');
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->timestamp('created_at');
            $table->unique(['encounter_id', 'person_id', 'user_id']);
            $table->foreign(['person_id', 'user_id'])
                ->references(['id', 'user_id'])
                ->on('prayer_people')
                ->cascadeOnDelete();
            $table->foreign('encounter_id')->references('id')->on('encounters')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('encounter_person_links');
        Schema::dropIfExists('person_prayer_occurrences');
        Schema::dropIfExists('prayer_people');
    }
};
