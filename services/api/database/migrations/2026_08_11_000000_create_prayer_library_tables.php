<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
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
            $table->index('prayer_id');
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
            $table->index('prayer_id');
        });

        Schema::create('prayer_record_aliases', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->enum('record_type', ['vote', 'today']);
            $table->uuid('alias_id');
            $table->uuid('canonical_id');
            $table->unique(['user_id', 'record_type', 'alias_id']);
            $table->index(['user_id', 'record_type', 'canonical_id']);
        });

        $this->createVoteCountTriggers();
    }

    public function down(): void
    {
        $this->dropVoteCountTriggers();
        Schema::dropIfExists('prayer_record_aliases');
        Schema::dropIfExists('today_prayers');
        Schema::dropIfExists('prayer_votes');
        Schema::dropIfExists('library_prayers');
    }

    private function createVoteCountTriggers(): void
    {
        match (DB::getDriverName()) {
            'sqlite' => $this->createSqliteVoteCountTriggers(),
            'pgsql' => $this->createPostgresVoteCountTriggers(),
            default => throw new LogicException('Prayer vote count triggers require SQLite or PostgreSQL.'),
        };
    }

    private function createSqliteVoteCountTriggers(): void
    {
        DB::unprepared(<<<'SQL'
            CREATE TRIGGER prayer_votes_helpful_count_after_insert
            AFTER INSERT ON prayer_votes
            BEGIN
                UPDATE library_prayers
                SET helpful_count = helpful_count + 1
                WHERE id = NEW.prayer_id;
            END
        SQL);
        DB::unprepared(<<<'SQL'
            CREATE TRIGGER prayer_votes_helpful_count_after_delete
            AFTER DELETE ON prayer_votes
            BEGIN
                UPDATE library_prayers
                SET helpful_count = MAX(helpful_count - 1, 0)
                WHERE id = OLD.prayer_id;
            END
        SQL);
        DB::unprepared(<<<'SQL'
            CREATE TRIGGER prayer_votes_helpful_count_after_update
            AFTER UPDATE OF prayer_id ON prayer_votes
            WHEN OLD.prayer_id <> NEW.prayer_id
            BEGIN
                UPDATE library_prayers
                SET helpful_count = MAX(helpful_count - 1, 0)
                WHERE id = OLD.prayer_id;
                UPDATE library_prayers
                SET helpful_count = helpful_count + 1
                WHERE id = NEW.prayer_id;
            END
        SQL);
    }

    private function createPostgresVoteCountTriggers(): void
    {
        DB::unprepared(<<<'SQL'
            CREATE FUNCTION update_prayer_helpful_count() RETURNS TRIGGER AS $$
            BEGIN
                IF TG_OP = 'INSERT' THEN
                    UPDATE library_prayers
                    SET helpful_count = helpful_count + 1
                    WHERE id = NEW.prayer_id;
                    RETURN NEW;
                ELSIF TG_OP = 'DELETE' THEN
                    UPDATE library_prayers
                    SET helpful_count = GREATEST(helpful_count - 1, 0)
                    WHERE id = OLD.prayer_id;
                    RETURN OLD;
                ELSIF NEW.prayer_id IS DISTINCT FROM OLD.prayer_id THEN
                    UPDATE library_prayers
                    SET helpful_count = GREATEST(helpful_count - 1, 0)
                    WHERE id = OLD.prayer_id;
                    UPDATE library_prayers
                    SET helpful_count = helpful_count + 1
                    WHERE id = NEW.prayer_id;
                END IF;

                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql
        SQL);
        DB::unprepared(<<<'SQL'
            CREATE TRIGGER prayer_votes_helpful_count_after_change
            AFTER INSERT OR DELETE OR UPDATE OF prayer_id ON prayer_votes
            FOR EACH ROW EXECUTE FUNCTION update_prayer_helpful_count()
        SQL);
    }

    private function dropVoteCountTriggers(): void
    {
        if (DB::getDriverName() === 'sqlite') {
            DB::unprepared('DROP TRIGGER IF EXISTS prayer_votes_helpful_count_after_insert');
            DB::unprepared('DROP TRIGGER IF EXISTS prayer_votes_helpful_count_after_delete');
            DB::unprepared('DROP TRIGGER IF EXISTS prayer_votes_helpful_count_after_update');

            return;
        }

        if (DB::getDriverName() === 'pgsql') {
            DB::unprepared('DROP TRIGGER IF EXISTS prayer_votes_helpful_count_after_change ON prayer_votes');
            DB::unprepared('DROP FUNCTION IF EXISTS update_prayer_helpful_count()');
        }
    }
};
