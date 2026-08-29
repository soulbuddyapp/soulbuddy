<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('goal_guard_selections', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('goal_id');
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('guard_definition_id', 120);
            $table->unsignedInteger('guard_content_version');
            $table->text('private_note')->nullable();
            $table->timestamp('configured_at');
            $table->timestamp('archived_at')->nullable();
            $table->unique(['id', 'user_id']);
            $table->unique([
                'goal_id',
                'user_id',
                'guard_definition_id',
            ], 'goal_guard_selection_definition_unique');
            $table->index([
                'user_id',
                'goal_id',
                'archived_at',
            ], 'goal_guard_selection_goal_index');
            $table->foreign(['goal_id', 'user_id'])
                ->references(['id', 'user_id'])
                ->on('goals')
                ->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('goal_guard_selections');
    }
};
