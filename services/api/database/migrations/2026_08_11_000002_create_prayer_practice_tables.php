<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('prayer_reminders', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->uuid('personal_prayer_id');
            $table->enum('schedule_type', ['once', 'daily', 'weekdays']);
            $table->char('local_time', 5);
            $table->string('timezone', 64);
            $table->timestamp('once_at')->nullable();
            $table->unsignedSmallInteger('weekdays_mask')->nullable();
            $table->boolean('enabled')->default(true);
            $table->timestamps();
            $table->timestamp('archived_at')->nullable();
            $table->foreign('personal_prayer_id')
                ->references('id')->on('personal_prayers')->cascadeOnDelete();
            $table->unique(['user_id', 'personal_prayer_id']);
            $table->index(['user_id', 'enabled', 'archived_at']);
        });

        Schema::create('prayer_sessions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->uuid('personal_prayer_id');
            $table->uuid('prayer_revision_id');
            $table->uuid('reminder_id')->nullable();
            $table->string('reminder_occurrence_key', 160)->nullable();
            $table->enum('source', ['reminder', 'manual']);
            $table->timestamp('occurred_at');
            $table->date('local_date');
            $table->string('timezone', 64);
            $table->string('device_id', 120);
            $table->timestamp('retracted_at')->nullable();
            $table->foreign('personal_prayer_id')
                ->references('id')->on('personal_prayers')->cascadeOnDelete();
            $table->foreign('prayer_revision_id')
                ->references('id')->on('personal_prayer_revisions')->cascadeOnDelete();
            $table->foreign('reminder_id')
                ->references('id')->on('prayer_reminders')->nullOnDelete();
            $table->unique(['user_id', 'reminder_occurrence_key']);
            $table->index(['user_id', 'prayer_revision_id', 'retracted_at']);
            $table->index(['personal_prayer_id', 'occurred_at']);
        });

        $this->createIntegrityChecks();
    }

    public function down(): void
    {
        $this->dropIntegrityChecks();
        Schema::dropIfExists('prayer_sessions');
        Schema::dropIfExists('prayer_reminders');
    }

    private function createIntegrityChecks(): void
    {
        if (DB::getDriverName() === 'sqlite') {
            DB::unprepared(<<<'SQL'
                CREATE TRIGGER prayer_reminders_shape_insert
                BEFORE INSERT ON prayer_reminders
                WHEN NOT (
                    (NEW.schedule_type = 'once' AND NEW.once_at IS NOT NULL AND NEW.weekdays_mask IS NULL)
                    OR (NEW.schedule_type = 'daily' AND NEW.once_at IS NULL AND NEW.weekdays_mask IS NULL)
                    OR (NEW.schedule_type = 'weekdays' AND NEW.once_at IS NULL
                        AND NEW.weekdays_mask BETWEEN 1 AND 127)
                )
                BEGIN
                    SELECT RAISE(ABORT, 'invalid prayer reminder schedule');
                END
            SQL);
            DB::unprepared(<<<'SQL'
                CREATE TRIGGER prayer_reminders_shape_update
                BEFORE UPDATE OF schedule_type, once_at, weekdays_mask ON prayer_reminders
                WHEN NOT (
                    (NEW.schedule_type = 'once' AND NEW.once_at IS NOT NULL AND NEW.weekdays_mask IS NULL)
                    OR (NEW.schedule_type = 'daily' AND NEW.once_at IS NULL AND NEW.weekdays_mask IS NULL)
                    OR (NEW.schedule_type = 'weekdays' AND NEW.once_at IS NULL
                        AND NEW.weekdays_mask BETWEEN 1 AND 127)
                )
                BEGIN
                    SELECT RAISE(ABORT, 'invalid prayer reminder schedule');
                END
            SQL);
            DB::unprepared(<<<'SQL'
                CREATE TRIGGER prayer_sessions_shape_insert
                BEFORE INSERT ON prayer_sessions
                WHEN NOT (
                    (NEW.source = 'manual' AND NEW.reminder_id IS NULL
                        AND NEW.reminder_occurrence_key IS NULL)
                    OR (NEW.source = 'reminder' AND NEW.reminder_id IS NOT NULL
                        AND NEW.reminder_occurrence_key IS NOT NULL)
                )
                BEGIN
                    SELECT RAISE(ABORT, 'invalid prayer session source');
                END
            SQL);

            return;
        }

        if (DB::getDriverName() === 'pgsql') {
            DB::statement(<<<'SQL'
                ALTER TABLE prayer_reminders
                ADD CONSTRAINT prayer_reminders_shape CHECK (
                    (schedule_type = 'once' AND once_at IS NOT NULL AND weekdays_mask IS NULL)
                    OR (schedule_type = 'daily' AND once_at IS NULL AND weekdays_mask IS NULL)
                    OR (schedule_type = 'weekdays' AND once_at IS NULL
                        AND weekdays_mask BETWEEN 1 AND 127)
                )
            SQL);
            DB::statement(<<<'SQL'
                ALTER TABLE prayer_sessions
                ADD CONSTRAINT prayer_sessions_shape CHECK (
                    (source = 'manual' AND reminder_id IS NULL
                        AND reminder_occurrence_key IS NULL)
                    OR (source = 'reminder' AND reminder_id IS NOT NULL
                        AND reminder_occurrence_key IS NOT NULL)
                )
            SQL);

            return;
        }

        throw new LogicException('Prayer practice integrity checks require SQLite or PostgreSQL.');
    }

    private function dropIntegrityChecks(): void
    {
        if (DB::getDriverName() === 'sqlite') {
            DB::unprepared('DROP TRIGGER IF EXISTS prayer_reminders_shape_insert');
            DB::unprepared('DROP TRIGGER IF EXISTS prayer_reminders_shape_update');
            DB::unprepared('DROP TRIGGER IF EXISTS prayer_sessions_shape_insert');

            return;
        }

        if (DB::getDriverName() === 'pgsql') {
            DB::statement('ALTER TABLE prayer_sessions DROP CONSTRAINT IF EXISTS prayer_sessions_shape');
            DB::statement('ALTER TABLE prayer_reminders DROP CONSTRAINT IF EXISTS prayer_reminders_shape');
        }
    }
};
