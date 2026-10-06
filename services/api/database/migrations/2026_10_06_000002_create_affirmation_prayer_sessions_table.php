<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('affirmation_prayer_sessions', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            // Only a release item that carries the counted practice is eligible.
            $table->foreignUuid('release_item_id')
                ->constrained('prayer_release_items')
                ->restrictOnDelete();
            $table->date('local_date');
            $table->dateTime('started_at');
            $table->dateTime('ended_at');
            $table->enum('outcome', ['completed', 'ended_early']);
            $table->unsignedTinyInteger('step_one_count');
            $table->unsignedTinyInteger('step_two_count');
            $table->string('sound_key', 64)->nullable();
            $table->string('narration_speed', 8)->nullable();
            $table->timestamps();

            $table->index(['user_id', 'release_item_id']);
            $table->index(['user_id', 'local_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('affirmation_prayer_sessions');
    }
};
