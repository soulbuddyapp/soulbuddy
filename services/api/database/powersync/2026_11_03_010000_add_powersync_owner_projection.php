<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /** Tables whose client projection is scoped by the public account ID. */
    private const TABLES = [
        'encounters', 'encounter_revisions', 'memory_reflections', 'voice_tablets',
        'altar_items', 'altar_rituals', 'affirmation_prayer_sessions',
        'personal_prayers', 'personal_prayer_revisions', 'personal_prayer_links',
        'sacred_hours', 'sacred_hour_occurrences', 'prayer_reminders', 'prayer_sessions',
        'prayer_votes', 'today_prayers', 'goals', 'goal_revisions', 'goal_links',
        'goal_actions', 'goal_action_events', 'goal_guard_selections', 'prayer_people',
        'person_prayer_occurrences', 'encounter_person_links', 'commitments',
        'commitment_practices', 'commitment_declarations', 'commitment_meditation_plans',
        'commitment_preparation_cycles', 'commitment_meditation_sessions',
    ];

    private const EXISTING_OWNER_TABLES = [
        'commitments', 'commitment_practices', 'commitment_declarations',
        'commitment_meditation_plans', 'commitment_preparation_cycles',
        'commitment_meditation_sessions',
    ];

    public function up(): void
    {
        // SQLite is the test/local API database and does not feed PowerSync.
        if (DB::getDriverName() === 'sqlite') {
            return;
        }
        if (DB::getDriverName() !== 'mysql') {
            throw new RuntimeException('PowerSync ownership projection requires MySQL 8.');
        }
        $version = DB::selectOne('SELECT VERSION() AS version')->version;
        if (stripos($version, 'mariadb') !== false || (int) explode('.', $version)[0] < 8) {
            throw new RuntimeException('PowerSync ownership projection requires MySQL 8.');
        }
        $replication = DB::selectOne('SELECT @@GLOBAL.log_bin AS log_bin, @@GLOBAL.binlog_format AS binlog_format, @@GLOBAL.binlog_row_image AS binlog_row_image, @@GLOBAL.gtid_mode AS gtid_mode');
        if (! $replication->log_bin || $replication->binlog_format !== 'ROW'
            || $replication->binlog_row_image !== 'FULL' || $replication->gtid_mode !== 'ON') {
            throw new RuntimeException('PowerSync requires GTID and full row-based binary logging.');
        }

        // MySQL DDL commits implicitly. Deploy only after all writers are stopped;
        // any partial failure must be recovered from the pre-cutover backup.
        foreach (self::TABLES as $table) {
            $exists = in_array($table, self::EXISTING_OWNER_TABLES, true);
            if (! Schema::hasTable($table) || ! Schema::hasColumn($table, 'user_id')
                || Schema::hasColumn($table, 'owner_id') !== $exists) {
                throw new RuntimeException('Unexpected ownership schema: '.$table);
            }
            $mismatch = DB::table($table.' as owned')
                ->leftJoin('users', 'owned.user_id', '=', 'users.id')
                ->where(function ($query) use ($exists): void {
                    $query->whereNull('users.id')->orWhereNull('users.public_id');
                    if ($exists) {
                        $query->orWhereRaw('NOT (owned.owner_id <=> users.public_id)');
                    }
                })->exists();
            if ($mismatch) {
                throw new RuntimeException('Invalid existing owner: '.$table);
            }
        }
        $existingTriggers = DB::selectOne("SELECT COUNT(*) AS n FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=DATABASE() AND (LEFT(TRIGGER_NAME, 9) = 'ps_owner_' OR TRIGGER_NAME = 'ps_user_public_id_immutable')");
        if ((int) $existingTriggers->n !== 0) {
            throw new RuntimeException('PowerSync owner triggers already exist.');
        }

        foreach (self::TABLES as $index => $table) {
            $suffix = str_pad((string) $index, 2, '0', STR_PAD_LEFT);
            if (! in_array($table, self::EXISTING_OWNER_TABLES, true)) {
                DB::statement("ALTER TABLE `{$table}` ADD COLUMN `owner_id` CHAR(36) NULL");
                $automaticColumns = DB::select("SELECT COLUMN_NAME AS column_name FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=? AND EXTRA LIKE '%on update%'", [$table]);
                $preserve = '';
                foreach ($automaticColumns as $column) {
                    if (! preg_match('/^[A-Za-z0-9_]+$/', $column->column_name)) {
                        throw new RuntimeException('Unexpected automatic timestamp column: '.$table);
                    }
                    $preserve .= ", owned.`{$column->column_name}`=owned.`{$column->column_name}`";
                }
                DB::statement("UPDATE `{$table}` AS owned JOIN `users` ON owned.user_id=users.id SET owned.owner_id=users.public_id{$preserve}");
                DB::statement("ALTER TABLE `{$table}` MODIFY `owner_id` CHAR(36) NOT NULL, ADD INDEX `ps_owner_{$suffix}` (`owner_id`)");
            }
            foreach (['bi' => 'INSERT', 'bu' => 'UPDATE'] as $kind => $event) {
                DB::unprepared("CREATE TRIGGER `ps_owner_{$suffix}_{$kind}` BEFORE {$event} ON `{$table}` FOR EACH ROW SET NEW.owner_id=(SELECT public_id FROM users WHERE id=NEW.user_id)");
            }
        }
        DB::unprepared(<<<'SQL'
            CREATE TRIGGER ps_user_public_id_immutable BEFORE UPDATE ON users FOR EACH ROW
            BEGIN
                IF NOT (NEW.public_id <=> OLD.public_id) THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'public_id is immutable';
                END IF;
            END
        SQL);
    }

    public function down(): void
    {
        if (DB::getDriverName() === 'sqlite') {
            return;
        }
        throw new RuntimeException('Owner projection cannot be removed while clients may depend on it.');
    }
};
