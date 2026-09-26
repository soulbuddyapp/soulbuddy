<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        $this->changeKind(['next_step', 'guard', 'accountability', 'care', 'other', 'commitment_practice']);
    }

    public function down(): void
    {
        if (DB::table('goal_actions')->where('action_kind', 'commitment_practice')->exists()) {
            throw new LogicException('Commitment practices prevent reverting this migration.');
        }
        $this->changeKind(['next_step', 'guard', 'accountability', 'care', 'other']);
    }

    private function changeKind(array $values): void
    {
        if (DB::getDriverName() === 'pgsql') {
            DB::statement('ALTER TABLE goal_actions DROP CONSTRAINT IF EXISTS goal_actions_action_kind_check');
            $list = implode(',', array_map(fn ($value) => "'$value'", $values));
            DB::statement("ALTER TABLE goal_actions ADD CONSTRAINT goal_actions_action_kind_check CHECK (action_kind IN ($list))");

            return;
        }
        if (DB::getDriverName() === 'sqlite') {
            // This CHECK-only change uses SQLite's schema-text procedure. A
            // table rebuild can cascade-delete action history when migrations
            // run inside a transaction (foreign_keys cannot be disabled then).
            $sql = DB::selectOne("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'goal_actions'")->sql;
            $list = implode(',', array_map(fn ($value) => "'$value'", $values));
            $updated = preg_replace('/check\s*\(\s*"action_kind"\s+in\s*\([^)]*\)\s*\)/i', 'check ("action_kind" in ('.$list.'))', $sql, -1, $count);
            if ($count !== 1) {
                throw new LogicException('Unexpected Goal action kind constraint.');
            }
            $version = (int) DB::selectOne('PRAGMA schema_version')->schema_version;
            DB::unprepared('PRAGMA writable_schema = ON');
            try {
                DB::update("UPDATE sqlite_master SET sql = ? WHERE type = 'table' AND name = 'goal_actions'", [$updated]);
                DB::unprepared('PRAGMA schema_version = '.($version + 1));
            } finally {
                DB::unprepared('PRAGMA writable_schema = OFF');
            }
            if (DB::selectOne('PRAGMA integrity_check')->integrity_check !== 'ok') {
                throw new LogicException('Goal action schema integrity check failed.');
            }

            return;
        }
        Schema::table('goal_actions', fn (Blueprint $table) => $table->enum('action_kind', $values)->change());
    }
};
