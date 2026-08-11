<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('personal_prayers', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('title', 120);
            $table->enum('style', ['daily', 'situational']);
            $table->enum('reach', ['personal', 'encompassing']);
            $table->enum('grounding', ['general_christian', 'catholic']);
            $table->string('purpose', 40);
            $table->uuid('current_revision_id')->nullable();
            $table->timestamps();
            $table->timestamp('archived_at')->nullable();
            $table->index(['user_id', 'archived_at']);
        });

        Schema::create('personal_prayer_revisions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('prayer_id');
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->text('body');
            $table->text('action')->nullable();
            $table->string('device_id', 120);
            $table->timestamp('created_at');
            $table->foreign('prayer_id')->references('id')->on('personal_prayers')->cascadeOnDelete();
            $table->unique(['id', 'prayer_id', 'user_id']);
            $table->index(['prayer_id', 'created_at']);
        });

        Schema::table('personal_prayers', function (Blueprint $table) {
            $table->foreign('current_revision_id')
                ->references('id')
                ->on('personal_prayer_revisions')
                ->nullOnDelete();
        });

        Schema::create('personal_prayer_links', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('prayer_id');
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->enum('link_type', ['encounter', 'scripture']);
            $table->uuid('encounter_id')->nullable();
            $table->string('translation', 20)->nullable();
            $table->string('book', 80)->nullable();
            $table->unsignedSmallInteger('chapter')->nullable();
            $table->unsignedSmallInteger('first_verse')->nullable();
            $table->unsignedSmallInteger('last_verse')->nullable();
            $table->timestamp('created_at');
            $table->foreign('prayer_id')->references('id')->on('personal_prayers')->cascadeOnDelete();
            $table->foreign('encounter_id')->references('id')->on('encounters')->restrictOnDelete();
            $table->index(['prayer_id', 'link_type']);
        });

        Schema::table('today_prayers', function (Blueprint $table) {
            $table->dropForeign(['prayer_id']);
            $table->uuid('prayer_id')->nullable()->change();
            $table->uuid('personal_prayer_id')->nullable()->after('prayer_id');
            $table->foreign('prayer_id')->references('id')->on('library_prayers')->restrictOnDelete();
            $table->foreign('personal_prayer_id')->references('id')->on('personal_prayers')->restrictOnDelete();
            $table->index('personal_prayer_id');
        });

        $this->createIntegrityChecks();
    }

    public function down(): void
    {
        if (Schema::hasColumn('today_prayers', 'personal_prayer_id')
            && DB::table('today_prayers')->whereNotNull('personal_prayer_id')->exists()) {
            throw new RuntimeException('Cannot roll back personal prayers while Today contains personal selections.');
        }

        $this->dropIntegrityChecks();
        Schema::table('today_prayers', function (Blueprint $table) {
            $table->dropForeign(['personal_prayer_id']);
            $table->dropForeign(['prayer_id']);
            $table->dropIndex(['personal_prayer_id']);
            $table->dropColumn('personal_prayer_id');
            $table->uuid('prayer_id')->nullable(false)->change();
            $table->foreign('prayer_id')->references('id')->on('library_prayers')->restrictOnDelete();
        });
        Schema::dropIfExists('personal_prayer_links');
        Schema::table('personal_prayers', function (Blueprint $table) {
            $table->dropForeign(['current_revision_id']);
        });
        Schema::dropIfExists('personal_prayer_revisions');
        Schema::dropIfExists('personal_prayers');
    }

    private function createIntegrityChecks(): void
    {
        if (DB::getDriverName() === 'sqlite') {
            DB::unprepared(<<<'SQL'
                CREATE TRIGGER today_prayers_exactly_one_source_insert
                BEFORE INSERT ON today_prayers
                WHEN (NEW.prayer_id IS NULL) = (NEW.personal_prayer_id IS NULL)
                BEGIN
                    SELECT RAISE(ABORT, 'today_prayers requires exactly one source');
                END
            SQL);
            DB::unprepared(<<<'SQL'
                CREATE TRIGGER today_prayers_exactly_one_source_update
                BEFORE UPDATE OF prayer_id, personal_prayer_id ON today_prayers
                WHEN (NEW.prayer_id IS NULL) = (NEW.personal_prayer_id IS NULL)
                BEGIN
                    SELECT RAISE(ABORT, 'today_prayers requires exactly one source');
                END
            SQL);
            DB::unprepared(<<<'SQL'
                CREATE TRIGGER personal_prayer_links_shape_insert
                BEFORE INSERT ON personal_prayer_links
                WHEN NOT (
                    (NEW.link_type = 'encounter' AND NEW.encounter_id IS NOT NULL
                     AND NEW.translation IS NULL AND NEW.book IS NULL
                     AND NEW.chapter IS NULL AND NEW.first_verse IS NULL AND NEW.last_verse IS NULL)
                    OR
                    (NEW.link_type = 'scripture' AND NEW.encounter_id IS NULL
                     AND NEW.translation IS NOT NULL AND NEW.book IS NOT NULL
                     AND NEW.chapter IS NOT NULL AND NEW.first_verse IS NOT NULL
                     AND NEW.last_verse IS NOT NULL AND NEW.last_verse >= NEW.first_verse)
                )
                BEGIN
                    SELECT RAISE(ABORT, 'invalid personal prayer link');
                END
            SQL);

            return;
        }

        if (DB::getDriverName() === 'pgsql') {
            DB::statement('ALTER TABLE today_prayers ADD CONSTRAINT today_prayers_exactly_one_source CHECK ((prayer_id IS NULL) <> (personal_prayer_id IS NULL))');
            DB::statement(<<<'SQL'
                ALTER TABLE personal_prayer_links
                ADD CONSTRAINT personal_prayer_links_shape CHECK (
                    (link_type = 'encounter' AND encounter_id IS NOT NULL
                     AND translation IS NULL AND book IS NULL AND chapter IS NULL
                     AND first_verse IS NULL AND last_verse IS NULL)
                    OR
                    (link_type = 'scripture' AND encounter_id IS NULL
                     AND translation IS NOT NULL AND book IS NOT NULL
                     AND chapter IS NOT NULL AND first_verse IS NOT NULL
                     AND last_verse IS NOT NULL AND last_verse >= first_verse)
                )
            SQL);

            return;
        }

        throw new LogicException('Personal prayer integrity checks require SQLite or PostgreSQL.');
    }

    private function dropIntegrityChecks(): void
    {
        if (DB::getDriverName() === 'sqlite') {
            DB::unprepared('DROP TRIGGER IF EXISTS today_prayers_exactly_one_source_insert');
            DB::unprepared('DROP TRIGGER IF EXISTS today_prayers_exactly_one_source_update');
            DB::unprepared('DROP TRIGGER IF EXISTS personal_prayer_links_shape_insert');

            return;
        }

        if (DB::getDriverName() === 'pgsql') {
            DB::statement('ALTER TABLE today_prayers DROP CONSTRAINT IF EXISTS today_prayers_exactly_one_source');
            DB::statement('ALTER TABLE personal_prayer_links DROP CONSTRAINT IF EXISTS personal_prayer_links_shape');
        }
    }
};
