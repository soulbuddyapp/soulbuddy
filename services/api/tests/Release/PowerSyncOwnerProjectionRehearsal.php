<?php

// Standalone, synthetic MySQL 8 rehearsal. Never run against a real database.
require __DIR__.'/../../vendor/autoload.php';
$app = require __DIR__.'/../../bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();
set_exception_handler(function (Throwable $error): void {
    fwrite(STDERR, $error->getMessage().PHP_EOL);
    exit(1);
});

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Database\QueryException;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

if (! app()->environment('testing') || DB::getDriverName() !== 'mysql'
    || ! preg_match('/^soulbuddy_owner_test_[a-z0-9]+$/', DB::connection()->getDatabaseName())) {
    throw new RuntimeException('A synthetic MySQL rehearsal database is required.');
}
$tables = explode(' ', 'encounters encounter_revisions memory_reflections voice_tablets altar_items altar_rituals affirmation_prayer_sessions personal_prayers personal_prayer_revisions personal_prayer_links sacred_hours sacred_hour_occurrences prayer_reminders prayer_sessions prayer_votes today_prayers goals goal_revisions goal_links goal_actions goal_action_events goal_guard_selections prayer_people person_prayer_occurrences encounter_person_links commitments commitment_practices commitment_declarations commitment_meditation_plans commitment_preparation_cycles commitment_meditation_sessions');
$existing = ['commitments', 'commitment_practices', 'commitment_declarations', 'commitment_meditation_plans', 'commitment_preparation_cycles', 'commitment_meditation_sessions'];
Schema::create('users', function (Blueprint $table): void {
    $table->id();
    $table->uuid('public_id')->unique();
});
$ownerA = 'aaaaaaaa-1111-4111-8111-111111111111';
$ownerB = 'bbbbbbbb-1111-4111-8111-111111111111';
DB::table('users')->insert([['id' => 1, 'public_id' => $ownerA], ['id' => 2, 'public_id' => $ownerB]]);
foreach ($tables as $tableName) {
    Schema::create($tableName, function (Blueprint $table) use ($tableName, $existing): void {
        $table->uuid('id')->primary();
        $table->unsignedBigInteger('user_id');
        $table->timestamp('updated_at')->useCurrent()->useCurrentOnUpdate();
        if (in_array($tableName, $existing, true)) {
            $table->uuid('owner_id');
        }
    });
    $row = ['id' => 'aaaaaaaa-2222-4222-8222-222222222222', 'user_id' => 1, 'updated_at' => '2020-01-02 03:04:05'];
    if (in_array($tableName, $existing, true)) {
        $row['owner_id'] = $ownerA;
    }
    DB::table($tableName)->insert($row);
}
$migration = require __DIR__.'/../../database/powersync/2026_11_03_010000_add_powersync_owner_projection.php';
if (($argv[1] ?? '') === 'invalid-owner') {
    DB::table('commitments')->update(['owner_id' => $ownerB]);
    try {
        $migration->up();
        throw new RuntimeException('Invalid owner was accepted.');
    } catch (RuntimeException $e) {
        if (! str_contains($e->getMessage(), 'Invalid existing owner')) {
            throw $e;
        }
    }
    if (Schema::hasColumn('encounters', 'owner_id')) {
        throw new RuntimeException('Preflight changed the schema.');
    }
    echo "owner_preflight=passed\n";
    exit(0);
}
$migration->up();
foreach ($tables as $tableName) {
    $row = DB::table($tableName)->first();
    if ($row->owner_id !== $ownerA) {
        throw new RuntimeException('Backfill failed: '.$tableName);
    }
    if ($row->updated_at !== '2020-01-02 03:04:05') {
        throw new RuntimeException('Backfill changed timestamp: '.$tableName);
    }
    DB::table($tableName)->where('id', $row->id)->update(['owner_id' => $ownerB]);
    if (DB::table($tableName)->where('id', $row->id)->value('owner_id') !== $ownerA) {
        throw new RuntimeException('Owner spoof accepted: '.$tableName);
    }
    DB::table($tableName)->insert(['id' => 'bbbbbbbb-2222-4222-8222-222222222222', 'user_id' => 2, 'owner_id' => $ownerA]);
    if (DB::table($tableName)->where('id', 'bbbbbbbb-2222-4222-8222-222222222222')->value('owner_id') !== $ownerB) {
        throw new RuntimeException('Insert owner incorrect: '.$tableName);
    }
}
try {
    DB::table('users')->where('id', 1)->update(['public_id' => $ownerB]);
    throw new RuntimeException('Public owner ID was mutable.');
} catch (QueryException $e) {
    if (! str_contains($e->getMessage(), 'public_id is immutable')) {
        throw $e;
    }
}
try {
    $migration->down();
    throw new RuntimeException('Unsafe owner rollback was allowed.');
} catch (RuntimeException $e) {
    if (! str_contains($e->getMessage(), 'Owner projection cannot be removed')) {
        throw $e;
    }
}
echo 'owner_projection_tables='.count($tables)." passed\n";
