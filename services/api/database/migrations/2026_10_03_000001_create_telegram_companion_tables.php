<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('companion_link_codes', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('channel', 40);
            $table->char('token_hash', 64)->unique();
            $table->dateTime('expires_at');
            $table->dateTime('consumed_at')->nullable();
            $table->dateTime('created_at');

            $table->index(['user_id', 'channel', 'expires_at']);
        });

        Schema::create('telegram_connections', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->unique()->constrained()->cascadeOnDelete();
            $table->string('chat_id', 32)->unique();
            $table->string('username', 255)->nullable();
            $table->boolean('daily_enabled')->default(false);
            $table->date('last_daily_sent_on')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('telegram_connections');
        Schema::dropIfExists('companion_link_codes');
    }
};
