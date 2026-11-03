<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('personal_prayer_revisions', function (Blueprint $table) {
            $table->enum('content_format', ['text', 'audio'])->default('text');
        });
        Schema::table('memory_reflections', function (Blueprint $table) {
            $table->uuid('audio_encounter_id')->nullable();
            $table->foreign('audio_encounter_id')->references('id')->on('encounters')->restrictOnDelete();
        });
    }

    public function down(): void
    {
        if (DB::table('personal_prayer_revisions')->where('content_format', 'audio')->exists()
            || DB::table('memory_reflections')->whereNotNull('audio_encounter_id')->exists()) {
            throw new RuntimeException('Cannot remove audio authoring metadata while recorded content exists.');
        }
        Schema::table('memory_reflections', function (Blueprint $table) {
            $table->dropForeign(['audio_encounter_id']);
            $table->dropColumn('audio_encounter_id');
        });
        Schema::table('personal_prayer_revisions', function (Blueprint $table) {
            $table->dropColumn('content_format');
        });
    }
};
