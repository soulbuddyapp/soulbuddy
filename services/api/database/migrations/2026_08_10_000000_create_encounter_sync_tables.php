<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('encounters', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('title', 120);
            $table->text('body')->nullable();
            $table->date('occurred_on')->index();
            $table->boolean('is_altar')->default(false);
            $table->uuid('current_revision_id');
            $table->timestamp('archived_at')->nullable();
            $table->timestamps();
            $table->index(['user_id', 'occurred_on']);
        });

        Schema::create('encounter_revisions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('encounter_id');
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('title', 120);
            $table->text('body')->nullable();
            $table->string('device_id', 120);
            $table->timestamp('created_at');
            $table->foreign('encounter_id')->references('id')->on('encounters')->cascadeOnDelete();
            $table->unique(['encounter_id', 'id']);
        });

        Schema::create('sync_operations', function (Blueprint $table) {
            $table->uuid('operation_id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('table_name', 64);
            $table->uuid('record_id');
            $table->timestamp('created_at');
            $table->index(['user_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sync_operations');
        Schema::dropIfExists('encounter_revisions');
        Schema::dropIfExists('encounters');
    }
};
