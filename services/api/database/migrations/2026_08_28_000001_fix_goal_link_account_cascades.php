<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('goal_links', function (Blueprint $table) {
            $table->dropForeign(['personal_prayer_id']);
            $table->dropForeign(['encounter_id']);
            $table->dropForeign(['voice_tablet_id']);

            $table->foreign('personal_prayer_id')
                ->references('id')->on('personal_prayers')->cascadeOnDelete();
            $table->foreign('encounter_id')
                ->references('id')->on('encounters')->cascadeOnDelete();
            $table->foreign('voice_tablet_id')
                ->references('id')->on('voice_tablets')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('goal_links', function (Blueprint $table) {
            $table->dropForeign(['personal_prayer_id']);
            $table->dropForeign(['encounter_id']);
            $table->dropForeign(['voice_tablet_id']);

            $table->foreign('personal_prayer_id')
                ->references('id')->on('personal_prayers')->restrictOnDelete();
            $table->foreign('encounter_id')
                ->references('id')->on('encounters')->restrictOnDelete();
            $table->foreign('voice_tablet_id')
                ->references('id')->on('voice_tablets')->restrictOnDelete();
        });
    }
};
