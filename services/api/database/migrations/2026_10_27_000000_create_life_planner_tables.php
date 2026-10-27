<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('life_plans', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->uuid('request_id');
            $table->string('focus', 240);
            $table->date('starts_on');
            $table->string('timezone', 64);
            $table->timestamp('archived_at')->nullable();
            $table->timestamps();
            $table->unique(['id', 'user_id']);
            $table->unique(['user_id', 'request_id']);
            $table->index(['user_id', 'archived_at', 'created_at']);
        });

        Schema::create('life_plan_items', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('plan_id');
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->date('planned_on');
            $table->string('domain', 24);
            $table->string('title', 140);
            $table->unsignedSmallInteger('minutes');
            $table->timestamps();
            $table->unique(['id', 'plan_id', 'user_id']);
            $table->index(['user_id', 'planned_on']);
            $table->foreign(['plan_id', 'user_id'])
                ->references(['id', 'user_id'])->on('life_plans')->cascadeOnDelete();
        });

        Schema::create('life_plan_checkins', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('item_id')->unique();
            $table->uuid('plan_id');
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('outcome', 12);
            $table->string('note', 300)->nullable();
            $table->timestamps();
            $table->foreign(['item_id', 'plan_id', 'user_id'])
                ->references(['id', 'plan_id', 'user_id'])->on('life_plan_items')->cascadeOnDelete();
        });

        Schema::create('life_plan_reviews', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('plan_id')->unique();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->text('reflection');
            $table->string('next_adjustment', 500);
            $table->timestamps();
            $table->foreign(['plan_id', 'user_id'])
                ->references(['id', 'user_id'])->on('life_plans')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('life_plan_reviews');
        Schema::dropIfExists('life_plan_checkins');
        Schema::dropIfExists('life_plan_items');
        Schema::dropIfExists('life_plans');
    }
};
