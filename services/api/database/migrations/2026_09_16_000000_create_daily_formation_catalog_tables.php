<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('formation_catalog_versions', function (Blueprint $table) {
            $table->id();
            $table->unsignedInteger('version')->unique();
            $table->char('checksum', 64)->unique();
            $table->char('source_sha256', 64);
            $table->boolean('published')->default(false)->index();
            $table->timestamp('published_at')->nullable();
            $table->timestamps();
        });

        Schema::create('formation_videos', function (Blueprint $table) {
            $table->id();
            $table->foreignId('catalog_version_id')->constrained('formation_catalog_versions')->cascadeOnDelete();
            $table->string('stable_id', 16);
            $table->string('title');
            $table->string('channel', 120);
            $table->string('youtube_url', 255);
            $table->string('youtube_id', 32);
            $table->unsignedSmallInteger('runtime_seconds');
            $table->string('status', 32);
            $table->string('primary_topic', 120);
            $table->text('secondary_use');
            $table->text('vice_target');
            $table->text('virtue_target');
            $table->string('difficulty', 80);
            $table->string('theological_lens', 120);
            $table->text('official_runtime_source');
            $table->text('youtube_verification_source');
            $table->string('verified_on', 10);
            $table->text('curation_note');
            $table->text('best_packs');
            $table->string('formation_role', 80);
            $table->string('verification_confidence', 40);
            $table->text('sensitivity_note');
            $table->timestamps();
            $table->unique(['catalog_version_id', 'stable_id']);
        });

        Schema::create('formation_packs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('catalog_version_id')->constrained('formation_catalog_versions')->cascadeOnDelete();
            $table->string('stable_id', 16);
            $table->unsignedTinyInteger('editorial_order');
            $table->unsignedTinyInteger('start_day');
            $table->unsignedTinyInteger('end_day');
            $table->string('title');
            $table->text('primary_struggle');
            $table->text('target_formation');
            $table->text('anchor');
            $table->text('scripture');
            $table->text('coverage_note');
            $table->timestamps();
            $table->unique(['catalog_version_id', 'stable_id']);
        });

        Schema::create('formation_days', function (Blueprint $table) {
            $table->id();
            $table->foreignId('catalog_version_id')->constrained('formation_catalog_versions')->cascadeOnDelete();
            $table->string('stable_id', 16);
            $table->unsignedTinyInteger('canonical_day');
            $table->unsignedTinyInteger('week');
            $table->string('pack_stable_id', 16);
            $table->string('focus');
            $table->text('objective');
            $table->text('scripture');
            $table->text('anchor');
            $table->string('presentation', 32);
            $table->json('video_ids');
            $table->json('alternative_conditions');
            $table->string('coverage_strength', 32);
            $table->text('reflection');
            $table->text('action');
            $table->text('completion_rule');
            $table->text('on_complete');
            $table->text('on_incomplete');
            $table->timestamps();
            $table->unique(['catalog_version_id', 'stable_id']);
            $table->unique(['catalog_version_id', 'canonical_day']);
        });

        Schema::create('formation_rules', function (Blueprint $table) {
            $table->id();
            $table->foreignId('catalog_version_id')->constrained('formation_catalog_versions')->cascadeOnDelete();
            $table->string('stable_id', 16);
            $table->unsignedTinyInteger('priority');
            $table->text('trigger');
            $table->text('eligibility');
            $table->string('presentation', 32);
            $table->json('option_labels');
            $table->text('progress_behavior');
            $table->text('note');
            $table->timestamps();
            $table->unique(['catalog_version_id', 'stable_id']);
            $table->unique(['catalog_version_id', 'priority']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('formation_rules');
        Schema::dropIfExists('formation_days');
        Schema::dropIfExists('formation_packs');
        Schema::dropIfExists('formation_videos');
        Schema::dropIfExists('formation_catalog_versions');
    }
};
