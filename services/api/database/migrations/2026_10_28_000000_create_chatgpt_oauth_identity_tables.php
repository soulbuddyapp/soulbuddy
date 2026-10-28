<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('chatgpt_oauth_identities', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('issuer', 255);
            $table->string('subject', 255);
            // Fixed-size hashes avoid cross-database composite-index byte limits.
            $table->char('identity_hash', 64)->unique();
            $table->char('issuer_hash', 64);
            $table->timestamps();
            // Only one subject from a given issuer may own this local account.
            $table->unique(['user_id', 'issuer_hash']);
        });

        Schema::create('chatgpt_account_link_codes', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->char('code_hash', 64)->unique();
            $table->dateTime('expires_at');
            $table->dateTime('consumed_at')->nullable();
            $table->dateTime('created_at');
            $table->index(['user_id', 'expires_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('chatgpt_account_link_codes');
        Schema::dropIfExists('chatgpt_oauth_identities');
    }
};
