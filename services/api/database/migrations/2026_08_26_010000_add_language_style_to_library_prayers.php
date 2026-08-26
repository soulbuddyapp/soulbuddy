<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('library_prayers', function (Blueprint $table) {
            $table->string('language_style', 20)->default('christian')->index();
        });

        DB::table('library_prayers')
            ->where('grounding', 'catholic')
            ->update(['language_style' => 'catholic']);
    }

    public function down(): void
    {
        Schema::table('library_prayers', function (Blueprint $table) {
            $table->dropColumn('language_style');
        });
    }
};
