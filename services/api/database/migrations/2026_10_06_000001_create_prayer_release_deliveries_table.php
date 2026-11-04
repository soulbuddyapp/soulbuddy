<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('prayer_release_deliveries', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('release_id')->constrained('prayer_releases')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            // One notice per release, person, and channel, however often the
            // scheduler retries.
            $table->string('channel', 24);
            $table->uuid('app_installation_id')->nullable();
            $table->uuid('telegram_connection_id')->nullable();
            $table->dateTime('delivered_at');
            $table->dateTime('created_at');
            $table->unique(['release_id', 'user_id', 'channel'], 'prayer_release_delivery_once');
            $table->index(['release_id', 'channel', 'delivered_at'], 'prayer_release_delivery_due');
            $table->index(['user_id', 'channel']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('prayer_release_deliveries');
    }
};
