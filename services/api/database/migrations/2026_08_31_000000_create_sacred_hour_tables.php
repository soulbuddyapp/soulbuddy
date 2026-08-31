<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sacred_hours', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->enum('purpose_key', ['morning', 'evening'])->nullable();
            $table->string('name', 120);
            $table->char('local_time', 5);
            $table->string('timezone', 64);
            $table->unsignedSmallInteger('duration_minutes')->default(60);
            $table->unsignedTinyInteger('prayer_minutes')->default(15);
            $table->boolean('enabled')->default(true);
            $table->enum('sound_key', [
                'gentle_chime',
                'dawn_chime',
                'still_bell',
                'evening_chime',
                'device',
                'silent',
            ])->default('gentle_chime');
            $table->enum('prayer_type', ['library', 'personal'])->nullable();
            $table->uuid('prayer_id')->nullable();
            $table->uuid('person_id')->nullable();
            $table->timestamps();
            $table->timestamp('archived_at')->nullable();
            $table->unique(['id', 'user_id']);
            $table->unique(['user_id', 'purpose_key']);
            $table->index(['user_id', 'local_time', 'archived_at']);
            $table->foreign('person_id')
                ->references('id')
                ->on('prayer_people')
                ->nullOnDelete();
        });

        Schema::create('sacred_hour_occurrences', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('sacred_hour_id');
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->timestamp('due_at');
            $table->date('local_date');
            $table->enum('status', ['due', 'begun', 'completed', 'dismissed']);
            $table->uuid('prayer_session_id')->nullable();
            $table->timestamps();
            $table->unique(['user_id', 'sacred_hour_id', 'due_at']);
            $table->index(['user_id', 'due_at']);
            $table->foreign(['sacred_hour_id', 'user_id'])
                ->references(['id', 'user_id'])
                ->on('sacred_hours')
                ->cascadeOnDelete();
            $table->foreign('prayer_session_id')
                ->references('id')
                ->on('prayer_sessions')
                ->nullOnDelete();
        });

        $this->createIntegrityChecks();
    }

    public function down(): void
    {
        $this->dropIntegrityChecks();
        Schema::dropIfExists('sacred_hour_occurrences');
        Schema::dropIfExists('sacred_hours');
    }

    private function createIntegrityChecks(): void
    {
        if (DB::getDriverName() === 'sqlite') {
            foreach (['insert' => 'INSERT', 'update' => 'UPDATE'] as $suffix => $event) {
                DB::unprepared(<<<SQL
                    CREATE TRIGGER sacred_hours_shape_{$suffix}
                    BEFORE {$event} ON sacred_hours
                    WHEN NOT (
                        NEW.duration_minutes = 60
                        AND NEW.prayer_minutes IN (5, 15, 30)
                        AND ((NEW.prayer_type IS NULL AND NEW.prayer_id IS NULL)
                            OR (NEW.prayer_type IS NOT NULL AND NEW.prayer_id IS NOT NULL))
                    )
                    BEGIN
                        SELECT RAISE(ABORT, 'invalid Sacred Hour shape');
                    END
                SQL);
            }

            return;
        }

        if (DB::getDriverName() === 'pgsql') {
            DB::statement(<<<'SQL'
                ALTER TABLE sacred_hours
                ADD CONSTRAINT sacred_hours_shape CHECK (
                    duration_minutes = 60
                    AND prayer_minutes IN (5, 15, 30)
                    AND ((prayer_type IS NULL AND prayer_id IS NULL)
                        OR (prayer_type IS NOT NULL AND prayer_id IS NOT NULL))
                )
            SQL);

            return;
        }

        if (in_array(DB::getDriverName(), ['mysql', 'mariadb'], true)) {
            $this->createMariaDbIntegrityChecks();

            return;
        }

        throw new LogicException('Unsupported database for Sacred Hour integrity checks.');
    }

    private function createMariaDbIntegrityChecks(): void
    {
        foreach (['insert' => 'INSERT', 'update' => 'UPDATE'] as $suffix => $event) {
            DB::unprepared(<<<SQL
                CREATE TRIGGER sacred_hours_shape_{$suffix}
                BEFORE {$event} ON sacred_hours FOR EACH ROW
                BEGIN
                    IF NOT (
                        NEW.duration_minutes = 60
                        AND NEW.prayer_minutes IN (5, 15, 30)
                        AND ((NEW.prayer_type IS NULL AND NEW.prayer_id IS NULL)
                            OR (NEW.prayer_type IS NOT NULL AND NEW.prayer_id IS NOT NULL))
                    ) THEN
                        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid Sacred Hour shape';
                    END IF;
                END
            SQL);
        }
    }

    private function dropIntegrityChecks(): void
    {
        if (DB::getDriverName() === 'pgsql') {
            DB::statement('ALTER TABLE sacred_hours DROP CONSTRAINT IF EXISTS sacred_hours_shape');

            return;
        }

        foreach (['insert', 'update'] as $suffix) {
            DB::unprepared("DROP TRIGGER IF EXISTS sacred_hours_shape_{$suffix}");
        }
    }
};
