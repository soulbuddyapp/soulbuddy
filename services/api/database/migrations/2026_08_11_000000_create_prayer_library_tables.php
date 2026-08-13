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
            'mysql', 'mariadb' => $this->createMariaDbVoteCountTriggers(),
            default => throw new LogicException('Unsupported database for prayer vote count triggers.'),
        };
    }

    private function createMariaDbVoteCountTriggers(): void
    {
        DB::unprepared(<<<'SQL'
            CREATE TRIGGER prayer_votes_helpful_count_after_insert
            AFTER INSERT ON prayer_votes FOR EACH ROW
            UPDATE library_prayers
            SET helpful_count = helpful_count + 1
            WHERE id = NEW.prayer_id
        SQL);
        DB::unprepared(<<<'SQL'
            CREATE TRIGGER prayer_votes_helpful_count_after_delete
            AFTER DELETE ON prayer_votes FOR EACH ROW
            UPDATE library_prayers
            SET helpful_count = GREATEST(helpful_count - 1, 0)
            WHERE id = OLD.prayer_id
        SQL);
        DB::unprepared(<<<'SQL'
            CREATE TRIGGER prayer_votes_helpful_count_after_update
            AFTER UPDATE ON prayer_votes FOR EACH ROW
            BEGIN
                IF OLD.prayer_id <> NEW.prayer_id THEN
                    UPDATE library_prayers
                    SET helpful_count = GREATEST(helpful_count - 1, 0)
                    WHERE id = OLD.prayer_id;
                    UPDATE library_prayers
                    SET helpful_count = helpful_count + 1
                    WHERE id = NEW.prayer_id;
                END IF;
            END
        SQL);
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
            CREATE FUNCTION refresh_prayer_helpful_counts_after_vote_insert() RETURNS TRIGGER AS $$
            DECLARE
                affected_prayer_id uuid;
            BEGIN
                FOR affected_prayer_id IN
                    SELECT DISTINCT prayer_id AS id
                    FROM new_votes
                    ORDER BY id
                LOOP
                    UPDATE library_prayers
                    SET helpful_count = helpful_count + (
                        SELECT COUNT(*)::integer
                        FROM new_votes
                        WHERE prayer_id = affected_prayer_id
                    )
                    WHERE id = affected_prayer_id;
                END LOOP;

                RETURN NULL;
            END;
            $$ LANGUAGE plpgsql
        SQL);
        DB::unprepared(<<<'SQL'
            CREATE FUNCTION refresh_prayer_helpful_counts_after_vote_delete() RETURNS TRIGGER AS $$
            DECLARE
                affected_prayer_id uuid;
            BEGIN
                FOR affected_prayer_id IN
                    SELECT DISTINCT prayer_id AS id
                    FROM old_votes
                    ORDER BY id
                LOOP
                    UPDATE library_prayers
                    SET helpful_count = GREATEST(
                        helpful_count - (
                            SELECT COUNT(*)::integer
                            FROM old_votes
                            WHERE prayer_id = affected_prayer_id
                        ),
                        0
                    )
                    WHERE id = affected_prayer_id;
                END LOOP;

                RETURN NULL;
            END;
            $$ LANGUAGE plpgsql
        SQL);
        DB::unprepared(<<<'SQL'
            CREATE FUNCTION refresh_prayer_helpful_counts_after_vote_update() RETURNS TRIGGER AS $$
            DECLARE
                affected_prayer_id uuid;
            BEGIN
                FOR affected_prayer_id IN
                    SELECT DISTINCT prayer_id AS id
                    FROM (
                        SELECT prayer_id FROM old_votes
                        UNION ALL
                        SELECT prayer_id FROM new_votes
                    ) AS changed_votes
                    ORDER BY id
                LOOP
                    UPDATE library_prayers
                    SET helpful_count = GREATEST(
                        helpful_count
                            - (
                                SELECT COUNT(*)::integer
                                FROM old_votes
                                WHERE prayer_id = affected_prayer_id
                            )
                            + (
                                SELECT COUNT(*)::integer
                                FROM new_votes
                                WHERE prayer_id = affected_prayer_id
                            ),
                        0
                    )
                    WHERE id = affected_prayer_id;
                END LOOP;

                RETURN NULL;
            END;
            $$ LANGUAGE plpgsql
        SQL);
        DB::unprepared(<<<'SQL'
            CREATE TRIGGER prayer_votes_helpful_count_after_insert
            AFTER INSERT ON prayer_votes
            REFERENCING NEW TABLE AS new_votes
            FOR EACH STATEMENT EXECUTE FUNCTION refresh_prayer_helpful_counts_after_vote_insert()
        SQL);
        DB::unprepared(<<<'SQL'
            CREATE TRIGGER prayer_votes_helpful_count_after_delete
            AFTER DELETE ON prayer_votes
            REFERENCING OLD TABLE AS old_votes
            FOR EACH STATEMENT EXECUTE FUNCTION refresh_prayer_helpful_counts_after_vote_delete()
        SQL);
        DB::unprepared(<<<'SQL'
            CREATE TRIGGER prayer_votes_helpful_count_after_update
            AFTER UPDATE ON prayer_votes
            REFERENCING OLD TABLE AS old_votes NEW TABLE AS new_votes
            FOR EACH STATEMENT EXECUTE FUNCTION refresh_prayer_helpful_counts_after_vote_update()
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
            DB::unprepared('DROP TRIGGER IF EXISTS prayer_votes_helpful_count_after_insert ON prayer_votes');
            DB::unprepared('DROP TRIGGER IF EXISTS prayer_votes_helpful_count_after_delete ON prayer_votes');
            DB::unprepared('DROP TRIGGER IF EXISTS prayer_votes_helpful_count_after_update ON prayer_votes');
            DB::unprepared('DROP FUNCTION IF EXISTS refresh_prayer_helpful_counts_after_vote_insert()');
            DB::unprepared('DROP FUNCTION IF EXISTS refresh_prayer_helpful_counts_after_vote_delete()');
            DB::unprepared('DROP FUNCTION IF EXISTS refresh_prayer_helpful_counts_after_vote_update()');

            return;
        }

        if (in_array(DB::getDriverName(), ['mysql', 'mariadb'], true)) {
            DB::unprepared('DROP TRIGGER IF EXISTS prayer_votes_helpful_count_after_insert');
            DB::unprepared('DROP TRIGGER IF EXISTS prayer_votes_helpful_count_after_delete');
            DB::unprepared('DROP TRIGGER IF EXISTS prayer_votes_helpful_count_after_update');
        }
    }
};
