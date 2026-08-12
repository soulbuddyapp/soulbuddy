<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('encounters', function (Blueprint $table) {
            $table->string('memory_type', 32)->default('encounter');
            $table->boolean('sensitive')->default(false);
            $table->boolean('recall_enabled')->default(true);
            $table->boolean('recall_paused')->default(false);
            $table->unsignedSmallInteger('recall_interval_days')->default(7);
        });
        Schema::table('encounter_revisions', function (Blueprint $table) {
            $table->string('memory_type', 32)->default('encounter');
            $table->boolean('sensitive')->default(false);
            $table->boolean('recall_enabled')->default(true);
            $table->boolean('recall_paused')->default(false);
            $table->unsignedSmallInteger('recall_interval_days')->default(7);
        });
        Schema::create('memory_reflections', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('encounter_id');
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->text('body');
            $table->date('local_date');
            $table->string('device_id', 120);
            $table->timestamp('created_at');
            $table->foreign('encounter_id')->references('id')->on('encounters')->cascadeOnDelete();
            $table->index(['encounter_id', 'local_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('memory_reflections');
        Schema::table('encounter_revisions', function (Blueprint $table) {
            $table->dropColumn(['memory_type', 'sensitive', 'recall_enabled', 'recall_paused', 'recall_interval_days']);
        });
        Schema::table('encounters', function (Blueprint $table) {
            $table->dropColumn(['memory_type', 'sensitive', 'recall_enabled', 'recall_paused', 'recall_interval_days']);
        });
    }
};
