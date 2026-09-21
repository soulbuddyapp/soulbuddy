<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('app_installations', function (Blueprint $table) {
            $table->string('push_token', 512)->nullable();
            $table->string('time_zone', 64)->nullable();
            $table->date('last_morning_sent_on')->nullable();
            $table->index('push_token');
        });
    }

    public function down(): void
    {
        Schema::table('app_installations', function (Blueprint $table) {
            $table->dropIndex(['push_token']);
            $table->dropColumn(['push_token', 'time_zone', 'last_morning_sent_on']);
        });
    }
};
