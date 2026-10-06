<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('prayer_releases', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->string('slug', 191)->unique();
            $table->string('title', 120);
            $table->string('discovery_label', 120);
            $table->string('discovery_detail', 255);
            $table->text('preparation_text');
            $table->dateTime('published_at')->nullable()->index();
            $table->dateTime('archived_at')->nullable()->index();
            $table->timestamps();
        });

        Schema::create('prayer_release_items', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('release_id')->constrained('prayer_releases')->cascadeOnDelete();
            $table->foreignUuid('library_prayer_id')->constrained('library_prayers')->cascadeOnDelete();
            $table->enum('kind', ['prayer', 'meditation_prayer']);
            $table->unsignedInteger('sort_order');
            $table->char('content_sha256', 64);
            // The paced practice profile is stored only when it rebuilds the item body.
            $table->string('practice_mode', 48)->nullable();
            $table->json('practice_steps')->nullable();
            $table->text('narration_uri')->nullable();
            $table->char('narration_content_sha256', 64)->nullable();
            $table->timestamps();
            $table->unique(['release_id', 'sort_order']);
            $table->unique(['release_id', 'library_prayer_id']);
        });

        Schema::create('prayer_release_preferences', function (Blueprint $table): void {
            $table->foreignId('user_id')->primary()->constrained()->cascadeOnDelete();
            $table->boolean('weekly_enabled')->default(false);
            $table->boolean('notification_enabled')->default(true);
            $table->string('time_zone', 64)->nullable();
            $table->timestamps();
        });

        Schema::create('prayer_release_downloads', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignUuid('release_id')->constrained('prayer_releases')->restrictOnDelete();
            $table->dateTime('downloaded_at');
            $table->timestamps();
            $table->unique(['user_id', 'release_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('prayer_release_downloads');
        Schema::dropIfExists('prayer_release_preferences');
        Schema::dropIfExists('prayer_release_items');
        Schema::dropIfExists('prayer_releases');
    }
};
