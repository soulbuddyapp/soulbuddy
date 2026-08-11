<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('library_prayers', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('title', 120);
            $table->text('body');
            $table->string('grounding', 40)->index();
            $table->string('purpose', 40)->index();
            $table->text('action')->nullable();
            $table->unsignedInteger('helpful_count')->default(0);
            $table->timestamp('published_at')->nullable()->index();
            $table->timestamp('archived_at')->nullable()->index();
        });

        Schema::create('prayer_votes', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->uuid('prayer_id');
            $table->timestamp('created_at');
            $table->foreign('prayer_id')->references('id')->on('library_prayers')->cascadeOnDelete();
            $table->unique(['user_id', 'prayer_id']);
        });

        Schema::create('today_prayers', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->date('local_date');
            $table->uuid('prayer_id');
            $table->boolean('include_action');
            $table->boolean('action_completed');
            $table->timestamps();
            $table->foreign('prayer_id')->references('id')->on('library_prayers')->restrictOnDelete();
            $table->unique(['user_id', 'local_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('today_prayers');
        Schema::dropIfExists('prayer_votes');
        Schema::dropIfExists('library_prayers');
    }
};
