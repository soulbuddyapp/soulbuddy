<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('circles', function (Blueprint $table): void {
            $table->id();
            $table->uuid('public_id')->unique();
            $table->foreignId('owner_user_id')->constrained('users')->cascadeOnDelete();
            $table->uuid('creation_key');
            $table->string('creation_fingerprint', 64);
            $table->string('name', 80);
            $table->string('category', 32);
            $table->string('description', 280);
            $table->string('visibility', 16);
            $table->string('status', 16)->default('active');
            $table->boolean('directory_listed')->default(true);
            $table->timestamps();

            $table->unique(
                ['owner_user_id', 'creation_key'],
                'circles_owner_creation_key_unique',
            );
            $table->index(
                ['directory_listed', 'visibility', 'status', 'category', 'public_id'],
                'circles_directory_index',
            );
            $table->index(
                ['owner_user_id', 'status', 'updated_at'],
                'circles_owner_status_updated',
            );
        });

        Schema::create('circle_provider_bindings', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('circle_id')->unique()->constrained('circles')->cascadeOnDelete();
            $table->string('provider', 32);
            $table->text('open_url')->nullable();
            $table->json('capabilities');
            $table->string('binding_status', 24);
            $table->timestamp('bound_at')->nullable();
            $table->timestamp('last_verified_at')->nullable();
            $table->timestamps();
        });

        Schema::create('circle_content_plans', function (Blueprint $table): void {
            $table->id();
            $table->uuid('public_id')->unique();
            $table->string('name', 100);
            $table->string('kind', 32);
            $table->json('editorial_item_ids');
            $table->string('status', 16)->default('draft');
            $table->timestamps();
        });

        Schema::create('circle_schedules', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('circle_id')->constrained('circles')->cascadeOnDelete();
            $table->string('schedule_kind', 32);
            $table->string('timezone', 64);
            $table->string('local_time', 5);
            $table->unsignedInteger('weekdays_mask')->default(0);
            $table->foreignId('content_plan_id')
                ->nullable()
                ->constrained('circle_content_plans')
                ->nullOnDelete();
            $table->boolean('enabled')->default(true);
            $table->timestamps();

            $table->index(['circle_id', 'enabled'], 'circle_schedules_circle_enabled');
        });

        Schema::create('circle_directory_reports', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignId('circle_id')->constrained('circles')->cascadeOnDelete();
            $table->foreignId('reporter_user_id')->constrained('users')->cascadeOnDelete();
            $table->string('reason_code', 32);
            $table->string('status', 16)->default('open');
            $table->timestamp('resolved_at')->nullable();
            $table->timestamps();

            $table->unique(
                ['circle_id', 'reporter_user_id', 'reason_code', 'status'],
                'circle_reports_open_dedupe',
            );
            $table->index(['circle_id', 'status'], 'circle_reports_circle_status');
        });

        Schema::create('circle_moderation_events', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('circle_id')->constrained('circles')->cascadeOnDelete();
            $table->foreignId('actor_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('event_type', 24);
            $table->string('reason_code', 32)->nullable();
            $table->timestamp('created_at');

            $table->index(['circle_id', 'created_at'], 'circle_moderation_circle_created');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('circle_moderation_events');
        Schema::dropIfExists('circle_directory_reports');
        Schema::dropIfExists('circle_schedules');
        Schema::dropIfExists('circle_content_plans');
        Schema::dropIfExists('circle_provider_bindings');
        Schema::dropIfExists('circles');
    }
};
