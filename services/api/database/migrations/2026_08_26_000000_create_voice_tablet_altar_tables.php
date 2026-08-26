<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('voice_tablets', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->enum('source_type', ['personal_prayer', 'library_prayer']);
            $table->uuid('personal_prayer_id')->nullable();
            $table->uuid('library_prayer_id')->nullable();
            $table->uuid('prayer_revision_id')->nullable();
            $table->string('title', 120);
            $table->uuid('full_audio_id');
            $table->uuid('refrain_audio_id')->nullable();
            $table->string('recording_device_id', 120);
            $table->timestamps();
            $table->timestamp('archived_at')->nullable();
            $table->foreign('personal_prayer_id')->references('id')->on('personal_prayers')->cascadeOnDelete();
            $table->foreign('library_prayer_id')->references('id')->on('library_prayers')->cascadeOnDelete();
            $table->foreign('prayer_revision_id')->references('id')->on('personal_prayer_revisions')->cascadeOnDelete();
            $table->index(['user_id', 'source_type']);
            $table->index(['user_id', 'archived_at']);
        });

        Schema::create('altar_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->enum('target_type', ['encounter', 'personal_prayer', 'library_prayer', 'voice_tablet']);
            $table->uuid('encounter_id')->nullable();
            $table->uuid('personal_prayer_id')->nullable();
            $table->uuid('library_prayer_id')->nullable();
            $table->uuid('voice_tablet_id')->nullable();
            $table->timestamps();
            $table->timestamp('archived_at')->nullable();
            $table->foreign('encounter_id')->references('id')->on('encounters')->cascadeOnDelete();
            $table->foreign('personal_prayer_id')->references('id')->on('personal_prayers')->cascadeOnDelete();
            $table->foreign('library_prayer_id')->references('id')->on('library_prayers')->cascadeOnDelete();
            $table->foreign('voice_tablet_id')->references('id')->on('voice_tablets')->cascadeOnDelete();
            $table->index(['user_id', 'target_type']);
            $table->index(['user_id', 'archived_at']);
        });

        Schema::create('altar_rituals', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->uuid('altar_item_id');
            $table->enum('schedule_type', ['daily', 'weekdays']);
            $table->char('local_time', 5);
            $table->string('timezone', 64);
            $table->unsignedSmallInteger('weekdays_mask')->nullable();
            $table->enum('playback_mode', ['refrain', 'full_prayer', 'open_quietly']);
            $table->boolean('enabled')->default(true);
            $table->timestamps();
            $table->timestamp('archived_at')->nullable();
            $table->foreign('altar_item_id')->references('id')->on('altar_items')->cascadeOnDelete();
            $table->unique(['user_id', 'altar_item_id']);
            $table->index(['user_id', 'enabled', 'archived_at']);
        });

        $this->createIntegrityChecks();
    }

    public function down(): void
    {
        $this->dropIntegrityChecks();
        Schema::dropIfExists('altar_rituals');
        Schema::dropIfExists('altar_items');
        Schema::dropIfExists('voice_tablets');
    }

    private function createIntegrityChecks(): void
    {
        $driver = DB::getDriverName();
        $voiceShape = "((NEW.source_type = 'personal_prayer' AND NEW.personal_prayer_id IS NOT NULL AND NEW.prayer_revision_id IS NOT NULL AND NEW.library_prayer_id IS NULL) OR (NEW.source_type = 'library_prayer' AND NEW.personal_prayer_id IS NULL AND NEW.prayer_revision_id IS NULL AND NEW.library_prayer_id IS NOT NULL))";
        $altarShape = "((NEW.target_type = 'encounter' AND NEW.encounter_id IS NOT NULL AND NEW.personal_prayer_id IS NULL AND NEW.library_prayer_id IS NULL AND NEW.voice_tablet_id IS NULL) OR (NEW.target_type = 'personal_prayer' AND NEW.encounter_id IS NULL AND NEW.personal_prayer_id IS NOT NULL AND NEW.library_prayer_id IS NULL AND NEW.voice_tablet_id IS NULL) OR (NEW.target_type = 'library_prayer' AND NEW.encounter_id IS NULL AND NEW.personal_prayer_id IS NULL AND NEW.library_prayer_id IS NOT NULL AND NEW.voice_tablet_id IS NULL) OR (NEW.target_type = 'voice_tablet' AND NEW.encounter_id IS NULL AND NEW.personal_prayer_id IS NULL AND NEW.library_prayer_id IS NULL AND NEW.voice_tablet_id IS NOT NULL))";
        $ritualShape = "((NEW.schedule_type = 'daily' AND NEW.weekdays_mask IS NULL) OR (NEW.schedule_type = 'weekdays' AND NEW.weekdays_mask BETWEEN 1 AND 127))";

        if ($driver === 'sqlite') {
            foreach ([
                'voice_tablets_shape' => $voiceShape,
                'altar_items_shape' => $altarShape,
                'altar_rituals_shape' => $ritualShape,
            ] as $name => $condition) {
                foreach (['insert' => 'INSERT', 'update' => 'UPDATE'] as $suffix => $event) {
                    DB::unprepared("CREATE TRIGGER {$name}_{$suffix} BEFORE {$event} ON ".str_replace('_shape', '', $name)." WHEN NOT {$condition} BEGIN SELECT RAISE(ABORT, 'invalid synchronized altar shape'); END");
                }
            }

            return;
        }

        if ($driver === 'pgsql') {
            DB::statement('ALTER TABLE voice_tablets ADD CONSTRAINT voice_tablets_shape CHECK ('.str_replace('NEW.', '', $voiceShape).')');
            DB::statement('ALTER TABLE altar_items ADD CONSTRAINT altar_items_shape CHECK ('.str_replace('NEW.', '', $altarShape).')');
            DB::statement('ALTER TABLE altar_rituals ADD CONSTRAINT altar_rituals_shape CHECK ('.str_replace('NEW.', '', $ritualShape).')');

            return;
        }

        if (in_array($driver, ['mysql', 'mariadb'], true)) {
            $this->createMariaDbIntegrityChecks($voiceShape, $altarShape, $ritualShape);

            return;
        }

        throw new LogicException('Unsupported database for Voice Tablet and Altar integrity checks.');
    }

    private function createMariaDbIntegrityChecks(string $voiceShape, string $altarShape, string $ritualShape): void
    {
        foreach ([
            'voice_tablets_shape' => $voiceShape,
            'altar_items_shape' => $altarShape,
            'altar_rituals_shape' => $ritualShape,
        ] as $name => $condition) {
            $table = str_replace('_shape', '', $name);
            foreach (['insert' => 'INSERT', 'update' => 'UPDATE'] as $suffix => $event) {
                DB::unprepared("CREATE TRIGGER {$name}_{$suffix} BEFORE {$event} ON {$table} FOR EACH ROW BEGIN IF NOT {$condition} THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid synchronized altar shape'; END IF; END");
            }
        }
    }

    private function dropIntegrityChecks(): void
    {
        $driver = DB::getDriverName();
        if ($driver === 'pgsql') {
            DB::statement('ALTER TABLE altar_rituals DROP CONSTRAINT IF EXISTS altar_rituals_shape');
            DB::statement('ALTER TABLE altar_items DROP CONSTRAINT IF EXISTS altar_items_shape');
            DB::statement('ALTER TABLE voice_tablets DROP CONSTRAINT IF EXISTS voice_tablets_shape');

            return;
        }
        if (in_array($driver, ['sqlite', 'mysql', 'mariadb'], true)) {
            foreach (['voice_tablets_shape', 'altar_items_shape', 'altar_rituals_shape'] as $name) {
                DB::unprepared("DROP TRIGGER IF EXISTS {$name}_insert");
                DB::unprepared("DROP TRIGGER IF EXISTS {$name}_update");
            }
        }
    }
};
