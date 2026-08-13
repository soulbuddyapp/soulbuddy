<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        $this->dropIntegrityChecks();

        Schema::table('prayer_sessions', function (Blueprint $table) {
            $table->uuid('library_prayer_id')->nullable()->after('user_id');
            $table->uuid('personal_prayer_id')->nullable()->change();
            $table->uuid('prayer_revision_id')->nullable()->change();
            $table->foreign('library_prayer_id')
                ->references('id')->on('library_prayers')->cascadeOnDelete();
            $table->index(
                ['user_id', 'library_prayer_id', 'local_date', 'retracted_at'],
                'prayer_sessions_user_library_date_retracted_index',
            );
            $table->index(
                ['user_id', 'personal_prayer_id', 'local_date', 'retracted_at'],
                'prayer_sessions_user_personal_date_retracted_index',
            );
        });

        $this->createIntegrityChecks();
    }

    public function down(): void
    {
        $this->dropIntegrityChecks();

        DB::table('prayer_sessions')->whereNotNull('library_prayer_id')->delete();
        Schema::table('prayer_sessions', function (Blueprint $table) {
            $table->dropIndex('prayer_sessions_user_library_date_retracted_index');
            $table->dropIndex('prayer_sessions_user_personal_date_retracted_index');
            $table->dropForeign(['library_prayer_id']);
            $table->dropColumn('library_prayer_id');
            $table->uuid('personal_prayer_id')->nullable(false)->change();
            $table->uuid('prayer_revision_id')->nullable(false)->change();
        });

        $this->createLegacyIntegrityChecks();
    }

    private function createIntegrityChecks(): void
    {
        $shape = $this->sessionShape();

        if (DB::getDriverName() === 'sqlite') {
            $sqliteShape = $this->sessionShape('NEW.');
            DB::unprepared(<<<SQL
                CREATE TRIGGER prayer_sessions_shape_insert
                BEFORE INSERT ON prayer_sessions
                WHEN NOT ({$sqliteShape})
                BEGIN
                    SELECT RAISE(ABORT, 'invalid prayer session source');
                END
            SQL);
            DB::unprepared(<<<SQL
                CREATE TRIGGER prayer_sessions_shape_update
                BEFORE UPDATE OF library_prayer_id, personal_prayer_id,
                    prayer_revision_id, source, reminder_id,
                    reminder_occurrence_key ON prayer_sessions
                WHEN NOT ({$sqliteShape})
                BEGIN
                    SELECT RAISE(ABORT, 'invalid prayer session source');
                END
            SQL);

            return;
        }

        if (DB::getDriverName() === 'pgsql') {
            DB::statement(<<<SQL
                ALTER TABLE prayer_sessions
                ADD CONSTRAINT prayer_sessions_shape CHECK ({$shape})
            SQL);

            return;
        }

        if (in_array(DB::getDriverName(), ['mysql', 'mariadb'], true)) {
            $this->createMariaDbIntegrityChecks($this->sessionShape('NEW.'));

            return;
        }

        throw new LogicException('Unsupported database for prayer session integrity checks.');
    }

    private function createLegacyIntegrityChecks(): void
    {
        $shape = $this->legacySessionShape();

        if (DB::getDriverName() === 'sqlite') {
            $sqliteShape = $this->legacySessionShape('NEW.');
            DB::unprepared(<<<SQL
                CREATE TRIGGER prayer_sessions_shape_insert
                BEFORE INSERT ON prayer_sessions
                WHEN NOT ({$sqliteShape})
                BEGIN
                    SELECT RAISE(ABORT, 'invalid prayer session source');
                END
            SQL);

            return;
        }

        if (DB::getDriverName() === 'pgsql') {
            DB::statement(<<<SQL
                ALTER TABLE prayer_sessions
                ADD CONSTRAINT prayer_sessions_shape CHECK ({$shape})
            SQL);

            return;
        }

        if (in_array(DB::getDriverName(), ['mysql', 'mariadb'], true)) {
            $this->createMariaDbIntegrityChecks(
                $this->legacySessionShape('NEW.'),
                includeUpdate: false,
            );

            return;
        }

        throw new LogicException('Unsupported database for prayer session integrity checks.');
    }

    private function createMariaDbIntegrityChecks(string $shape, bool $includeUpdate = true): void
    {
        DB::unprepared(<<<SQL
            CREATE TRIGGER prayer_sessions_shape_insert
            BEFORE INSERT ON prayer_sessions FOR EACH ROW
            BEGIN
                IF NOT ({$shape}) THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid prayer session source';
                END IF;
            END
        SQL);
        if ($includeUpdate) {
            DB::unprepared(<<<SQL
                CREATE TRIGGER prayer_sessions_shape_update
                BEFORE UPDATE ON prayer_sessions FOR EACH ROW
                BEGIN
                    IF NOT ({$shape}) THEN
                        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid prayer session source';
                    END IF;
                END
            SQL);
        }
    }

    private function dropIntegrityChecks(): void
    {
        if (DB::getDriverName() === 'sqlite') {
            DB::unprepared('DROP TRIGGER IF EXISTS prayer_sessions_shape_insert');
            DB::unprepared('DROP TRIGGER IF EXISTS prayer_sessions_shape_update');

            return;
        }

        if (DB::getDriverName() === 'pgsql') {
            DB::statement('ALTER TABLE prayer_sessions DROP CONSTRAINT IF EXISTS prayer_sessions_shape');

            return;
        }

        if (in_array(DB::getDriverName(), ['mysql', 'mariadb'], true)) {
            DB::unprepared('DROP TRIGGER IF EXISTS prayer_sessions_shape_insert');
            DB::unprepared('DROP TRIGGER IF EXISTS prayer_sessions_shape_update');
        }
    }

    private function sessionShape(string $prefix = ''): string
    {
        return <<<SQL
            (
                ({$prefix}library_prayer_id IS NOT NULL
                    AND {$prefix}personal_prayer_id IS NULL
                    AND {$prefix}prayer_revision_id IS NULL)
                OR
                ({$prefix}library_prayer_id IS NULL
                    AND {$prefix}personal_prayer_id IS NOT NULL
                    AND {$prefix}prayer_revision_id IS NOT NULL)
            )
            AND
            (
                ({$prefix}source = 'manual'
                    AND {$prefix}reminder_id IS NULL
                    AND {$prefix}reminder_occurrence_key IS NULL)
                OR
                ({$prefix}source = 'reminder'
                    AND {$prefix}library_prayer_id IS NULL
                    AND {$prefix}reminder_id IS NOT NULL
                    AND {$prefix}reminder_occurrence_key IS NOT NULL)
            )
        SQL;
    }

    private function legacySessionShape(string $prefix = ''): string
    {
        return <<<SQL
            ({$prefix}source = 'manual'
                AND {$prefix}reminder_id IS NULL
                AND {$prefix}reminder_occurrence_key IS NULL)
            OR
            ({$prefix}source = 'reminder'
                AND {$prefix}reminder_id IS NOT NULL
                AND {$prefix}reminder_occurrence_key IS NOT NULL)
        SQL;
    }
};
