<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', fn (Blueprint $table) => $table->unique(['id', 'public_id']));
        Schema::table('goal_actions', fn (Blueprint $table) => $table->unique(['id', 'user_id']));
        Schema::create('commitments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $this->publicOwner($table);
            $table->enum('journey_slot', ['primary']);
            $table->uuid('goal_id');
            $table->string('name', 120);
            foreach (['key_need_one', 'key_need_two', 'key_need_three'] as $field) {
                $table->string($field, 500);
            }
            $table->text('calling');
            $table->enum('guide_id', ['surrender', 'direction', 'peace']);
            $table->timestamps();
            $table->unique(['id', 'user_id']);
            $table->unique(['user_id', 'journey_slot']);
            $table->unique(['goal_id', 'user_id']);
            $table->foreign(['goal_id', 'user_id'])->references(['id', 'user_id'])->on('goals')->cascadeOnDelete();
        });
        Schema::create('commitment_practices', function (Blueprint $table) {
            $this->identity($table);
            $table->uuid('goal_action_id')->unique();
            $table->enum('category', ['joy_pleasure', 'exploration_adventure', 'attention_self_esteem']);
            $table->text('body');
            $table->unsignedTinyInteger('position');
            $table->enum('source', ['reviewed_suggestion', 'user_authored']);
            $table->string('suggestion_id', 120)->nullable();
            $table->timestamps();
            $table->unique(['commitment_id', 'position']);
            $table->foreign(['goal_action_id', 'user_id'])->references(['id', 'user_id'])->on('goal_actions')->cascadeOnDelete();
        });
        Schema::create('commitment_declarations', function (Blueprint $table) {
            $this->identity($table, true);
            $table->text('body');
            $table->timestamp('reviewed_at');
            $table->timestamps();
        });
        Schema::create('commitment_meditation_plans', function (Blueprint $table) {
            $this->identity($table, true);
            $table->enum('frequency', ['daily', 'selected_days']);
            $table->unsignedTinyInteger('weekdays_mask')->nullable();
            $table->string('local_time', 5);
            $table->string('timezone', 100);
            $table->unsignedTinyInteger('duration_minutes');
            $table->boolean('enabled');
            $table->timestamps();
        });
        Schema::create('commitment_preparation_cycles', function (Blueprint $table) {
            $this->identity($table, true);
            $table->timestamp('started_at_utc');
            $table->date('started_local_date');
            $table->string('start_timezone', 100);
            $table->date('review_local_date');
            $table->enum('state', ['active', 'review_available', 'listening_opened', 'deferred']);
            $table->timestamps();
        });
        Schema::create('commitment_meditation_sessions', function (Blueprint $table) {
            $this->identity($table);
            $table->enum('session_kind', ['meditation', 'listening']);
            $table->timestamp('started_at');
            $table->timestamp('ended_at');
            $table->date('local_date');
            $table->unsignedInteger('planned_duration_seconds');
            $table->unsignedInteger('actual_duration_seconds');
            $table->enum('outcome', ['completed', 'ended_early']);
            $table->string('device_id', 120);
            $table->index(['user_id', 'commitment_id', 'local_date'], 'commitment_sessions_date_index');
        });
        $this->integrity();
    }

    private function identity(Blueprint $table, bool $single = false): void
    {
        $table->uuid('id')->primary();
        $table->foreignId('user_id')->constrained()->cascadeOnDelete();
        $this->publicOwner($table);
        $table->uuid('commitment_id');
        $table->index(['user_id', 'commitment_id']);
        $table->foreign(['commitment_id', 'user_id'])->references(['id', 'user_id'])->on('commitments')->cascadeOnDelete();
        if ($single) {
            $table->unique('commitment_id');
        }
    }

    private function publicOwner(Blueprint $table): void
    {
        $table->uuid('owner_id')->index();
        $table->foreign(['user_id', 'owner_id'])->references(['id', 'public_id'])->on('users')->cascadeOnDelete();
    }

    private function integrity(): void
    {
        $length = DB::getDriverName() === 'sqlite' ? 'length' : 'char_length';
        $boolean = DB::getDriverName() === 'pgsql' ? 'NEW.enabled IN (true,false)' : 'NEW.enabled IN (0,1)';
        $timeShape = match (DB::getDriverName()) {
            'sqlite' => "NEW.local_time GLOB '[0-2][0-9]:[0-5][0-9]' AND substr(NEW.local_time,1,2) <= '23'",
            'pgsql' => "NEW.local_time ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'",
            default => "NEW.local_time REGEXP '^([01][0-9]|2[0-3]):[0-5][0-9]$'",
        };
        $text = fn (string $column, int $max): string => "$length(trim(NEW.$column)) > 0 AND $length(NEW.$column) <= $max";
        $reviewDate = match (DB::getDriverName()) {
            'sqlite' => "date(NEW.started_local_date, '+9 days')",
            'pgsql' => 'NEW.started_local_date + 9',
            default => 'DATE_ADD(NEW.started_local_date, INTERVAL 9 DAY)',
        };
        $shapes = [
            'commitments' => implode(' AND ', array_map(fn ($column, $max) => $text($column, $max), ['name', 'key_need_one', 'key_need_two', 'key_need_three', 'calling'], [120, 500, 500, 500, 1500])),
            'commitment_practices' => $text('body', 1000)." AND NEW.position BETWEEN 0 AND 11 AND ((NEW.source = 'user_authored' AND NEW.suggestion_id IS NULL) OR (NEW.source = 'reviewed_suggestion' AND NEW.suggestion_id IS NOT NULL AND $length(trim(NEW.suggestion_id)) > 0)) AND EXISTS (SELECT 1 FROM goal_actions a JOIN commitments c ON c.goal_id = a.goal_id AND c.user_id = a.user_id WHERE a.id = NEW.goal_action_id AND c.id = NEW.commitment_id AND a.user_id = NEW.user_id AND a.action_kind = 'commitment_practice')",
            'commitment_declarations' => $text('body', 4000),
            'commitment_meditation_plans' => "NEW.duration_minutes IN (5, 10, 15, 20, 30) AND ((NEW.frequency = 'daily' AND NEW.weekdays_mask IS NULL) OR (NEW.frequency = 'selected_days' AND NEW.weekdays_mask IS NOT NULL AND NEW.weekdays_mask BETWEEN 1 AND 127)) AND ($timeShape) AND $boolean",
            'commitment_preparation_cycles' => "NEW.review_local_date = $reviewDate",
            'commitment_meditation_sessions' => "NEW.ended_at >= NEW.started_at AND NEW.planned_duration_seconds IN (300,600,900,1200,1800) AND NEW.actual_duration_seconds BETWEEN 0 AND NEW.planned_duration_seconds AND ((NEW.outcome = 'completed' AND NEW.actual_duration_seconds = NEW.planned_duration_seconds) OR (NEW.outcome = 'ended_early' AND NEW.actual_duration_seconds < NEW.planned_duration_seconds))",
        ];
        foreach ($shapes as $table => $shape) {
            if (DB::getDriverName() === 'pgsql') {
                DB::unprepared("CREATE FUNCTION validate_{$table}_shape() RETURNS TRIGGER AS $$ BEGIN IF NOT ($shape) THEN RAISE EXCEPTION 'invalid commitment shape' USING ERRCODE = '23514'; END IF; RETURN NEW; END; $$ LANGUAGE plpgsql");
                DB::unprepared("CREATE TRIGGER {$table}_shape BEFORE INSERT OR UPDATE ON $table FOR EACH ROW EXECUTE FUNCTION validate_{$table}_shape()");
            } else {
                foreach (['insert' => 'INSERT', 'update' => 'UPDATE'] as $suffix => $event) {
                    if (DB::getDriverName() === 'sqlite') {
                        DB::unprepared("CREATE TRIGGER {$table}_shape_$suffix BEFORE $event ON $table WHEN NOT ($shape) BEGIN SELECT RAISE(ABORT, 'invalid commitment shape'); END");
                    } elseif (in_array(DB::getDriverName(), ['mysql', 'mariadb'], true)) {
                        DB::unprepared("CREATE TRIGGER {$table}_shape_$suffix BEFORE $event ON $table FOR EACH ROW BEGIN IF NOT ($shape) THEN SIGNAL SQLSTATE '23000' SET MESSAGE_TEXT = 'invalid commitment shape'; END IF; END");
                    } else {
                        throw new LogicException('Unsupported database for Commitment integrity checks.');
                    }
                }
            }
        }
    }

    public function down(): void
    {
        foreach (['commitment_meditation_sessions', 'commitment_preparation_cycles', 'commitment_meditation_plans', 'commitment_declarations', 'commitment_practices', 'commitments'] as $table) {
            Schema::dropIfExists($table);
            if (DB::getDriverName() === 'pgsql') {
                DB::unprepared("DROP FUNCTION IF EXISTS validate_{$table}_shape()");
            }
        }
        Schema::table('goal_actions', fn (Blueprint $table) => $table->dropUnique(['id', 'user_id']));
        Schema::table('users', fn (Blueprint $table) => $table->dropUnique(['id', 'public_id']));
    }
};
