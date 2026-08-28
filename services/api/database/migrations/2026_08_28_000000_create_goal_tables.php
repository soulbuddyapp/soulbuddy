<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('goals', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->enum('starter_key', [
                'closer_to_god',
                'stop_control',
                'direction',
                'difficult_time',
                'other',
            ])->nullable();
            $table->enum('mode', ['actionable', 'petition', 'mixed']);
            $table->enum('status', ['active', 'paused', 'completed', 'archived']);
            $table->uuid('current_revision_id')->nullable();
            $table->unsignedInteger('position')->default(0);
            $table->timestamps();
            $table->timestamp('archived_at')->nullable();
            $table->unique(['id', 'user_id']);
            $table->index(['user_id', 'status', 'position']);
            $table->index(['user_id', 'updated_at']);
        });

        Schema::create('goal_revisions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('goal_id');
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('title', 120);
            $table->text('current_situation')->nullable();
            $table->text('why_it_matters')->nullable();
            $table->timestamp('created_at');
            $table->string('device_id', 120);
            $table->unique(['id', 'goal_id', 'user_id']);
            $table->index(['goal_id', 'created_at']);
            $table->foreign(['goal_id', 'user_id'])
                ->references(['id', 'user_id'])
                ->on('goals')
                ->cascadeOnDelete();
        });

        Schema::table('goals', function (Blueprint $table) {
            $table->foreign('current_revision_id')
                ->references('id')
                ->on('goal_revisions')
                ->nullOnDelete();
        });

        Schema::create('goal_links', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('goal_id');
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->enum('link_type', [
                'personal_prayer',
                'library_prayer',
                'encounter',
                'voice_tablet',
                'circle',
                'scripture',
            ]);
            $table->uuid('personal_prayer_id')->nullable();
            $table->uuid('library_prayer_id')->nullable();
            $table->uuid('encounter_id')->nullable();
            $table->uuid('voice_tablet_id')->nullable();
            $table->uuid('circle_id')->nullable();
            $table->string('translation', 20)->nullable();
            $table->string('book', 80)->nullable();
            $table->unsignedSmallInteger('chapter')->nullable();
            $table->unsignedSmallInteger('first_verse')->nullable();
            $table->unsignedSmallInteger('last_verse')->nullable();
            $table->enum('role', [
                'primary_prayer',
                'supporting_prayer',
                'primary_circle',
                'support',
                'reference',
            ]);
            $table->timestamp('created_at');
            $table->timestamp('archived_at')->nullable();
            $table->index(['goal_id', 'archived_at']);
            $table->index(['user_id', 'link_type']);
            $table->foreign(['goal_id', 'user_id'])
                ->references(['id', 'user_id'])
                ->on('goals')
                ->cascadeOnDelete();
            $table->foreign('personal_prayer_id')
                ->references('id')->on('personal_prayers')->restrictOnDelete();
            $table->foreign('library_prayer_id')
                ->references('id')->on('library_prayers')->restrictOnDelete();
            $table->foreign('encounter_id')
                ->references('id')->on('encounters')->restrictOnDelete();
            $table->foreign('voice_tablet_id')
                ->references('id')->on('voice_tablets')->restrictOnDelete();
        });

        Schema::create('goal_actions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('goal_id');
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->text('body');
            $table->enum('action_kind', [
                'next_step', 'guard', 'accountability', 'care', 'other',
            ]);
            $table->enum('schedule_type', [
                'today', 'once', 'daily', 'selected_days', 'none',
            ]);
            $table->string('local_time', 5)->nullable();
            $table->string('timezone', 100)->nullable();
            $table->timestamp('once_at')->nullable();
            $table->unsignedTinyInteger('weekdays_mask')->nullable();
            $table->boolean('enabled')->default(true);
            $table->timestamps();
            $table->timestamp('archived_at')->nullable();
            $table->unique(['id', 'goal_id', 'user_id']);
            $table->index(['user_id', 'goal_id', 'archived_at']);
            $table->index(['user_id', 'enabled', 'schedule_type']);
            $table->foreign(['goal_id', 'user_id'])
                ->references(['id', 'user_id'])
                ->on('goals')
                ->cascadeOnDelete();
        });

        Schema::create('goal_action_events', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('goal_action_id');
            $table->uuid('goal_id');
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->enum('event_type', ['completed', 'skipped', 'retracted']);
            $table->string('occurrence_key', 180);
            $table->timestamp('occurred_at');
            $table->date('local_date');
            $table->string('device_id', 120);
            $table->index([
                'user_id', 'goal_action_id', 'occurrence_key', 'occurred_at',
            ], 'goal_action_events_occurrence_index');
            $table->index(['user_id', 'goal_id', 'local_date']);
            $table->foreign(['goal_action_id', 'goal_id', 'user_id'])
                ->references(['id', 'goal_id', 'user_id'])
                ->on('goal_actions')
                ->cascadeOnDelete();
        });

        $this->createGoalRevisionIntegrityTrigger();
    }

    public function down(): void
    {
        $this->dropGoalRevisionIntegrityTrigger();
        Schema::dropIfExists('goal_action_events');
        Schema::dropIfExists('goal_actions');
        Schema::dropIfExists('goal_links');
        Schema::table('goals', function (Blueprint $table) {
            $table->dropForeign(['current_revision_id']);
        });
        Schema::dropIfExists('goal_revisions');
        Schema::dropIfExists('goals');
    }

    private function createGoalRevisionIntegrityTrigger(): void
    {
        if (DB::getDriverName() === 'sqlite') {
            foreach (['insert' => 'INSERT', 'update' => 'UPDATE'] as $suffix => $event) {
                DB::unprepared(<<<SQL
                    CREATE TRIGGER goals_current_revision_{$suffix}
                    BEFORE {$event} ON goals
                    WHEN NEW.current_revision_id IS NOT NULL
                      AND NOT EXISTS (
                        SELECT 1 FROM goal_revisions
                        WHERE id = NEW.current_revision_id
                          AND goal_id = NEW.id
                          AND user_id = NEW.user_id
                      )
                    BEGIN
                        SELECT RAISE(ABORT, 'invalid goal current revision');
                    END
                SQL);
            }

            return;
        }

        if (DB::getDriverName() === 'pgsql') {
            DB::unprepared(<<<'SQL'
                CREATE OR REPLACE FUNCTION validate_goal_current_revision()
                RETURNS TRIGGER AS $$
                BEGIN
                    IF NEW.current_revision_id IS NOT NULL
                       AND NOT EXISTS (
                           SELECT 1 FROM goal_revisions
                           WHERE id = NEW.current_revision_id
                             AND goal_id = NEW.id
                             AND user_id = NEW.user_id
                       ) THEN
                        RAISE EXCEPTION 'invalid goal current revision' USING ERRCODE = '23514';
                    END IF;
                    RETURN NEW;
                END;
                $$ LANGUAGE plpgsql
            SQL);
            DB::unprepared(<<<'SQL'
                CREATE TRIGGER goals_current_revision_integrity
                BEFORE INSERT OR UPDATE OF current_revision_id, id, user_id ON goals
                FOR EACH ROW EXECUTE FUNCTION validate_goal_current_revision()
            SQL);

            return;
        }

        if (in_array(DB::getDriverName(), ['mysql', 'mariadb'], true)) {
            foreach (['insert' => 'INSERT', 'update' => 'UPDATE'] as $suffix => $event) {
                DB::unprepared(<<<SQL
                    CREATE TRIGGER goals_current_revision_{$suffix}
                    BEFORE {$event} ON goals FOR EACH ROW
                    BEGIN
                        IF NEW.current_revision_id IS NOT NULL
                           AND NOT EXISTS (
                               SELECT 1 FROM goal_revisions
                               WHERE id = NEW.current_revision_id
                                 AND goal_id = NEW.id
                                 AND user_id = NEW.user_id
                           ) THEN
                            SIGNAL SQLSTATE '45000'
                                SET MESSAGE_TEXT = 'invalid goal current revision';
                        END IF;
                    END
                SQL);
            }

            return;
        }

        throw new LogicException('Unsupported database for Goal integrity checks.');
    }

    private function dropGoalRevisionIntegrityTrigger(): void
    {
        if (DB::getDriverName() === 'sqlite') {
            DB::unprepared('DROP TRIGGER IF EXISTS goals_current_revision_insert');
            DB::unprepared('DROP TRIGGER IF EXISTS goals_current_revision_update');

            return;
        }

        if (DB::getDriverName() === 'pgsql') {
            DB::unprepared('DROP TRIGGER IF EXISTS goals_current_revision_integrity ON goals');
            DB::unprepared('DROP FUNCTION IF EXISTS validate_goal_current_revision()');

            return;
        }

        if (in_array(DB::getDriverName(), ['mysql', 'mariadb'], true)) {
            DB::unprepared('DROP TRIGGER IF EXISTS goals_current_revision_insert');
            DB::unprepared('DROP TRIGGER IF EXISTS goals_current_revision_update');
        }
    }
};
