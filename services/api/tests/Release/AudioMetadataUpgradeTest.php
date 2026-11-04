<?php

use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Tests\TestCase;

uses(TestCase::class);

// Explicit CI invocation only; the default PHPUnit suites do not include Release.
it('upgrades existing written content on MariaDB and refuses to discard either kind of audio metadata', function () {
    expect(app()->environment('testing'))->toBeTrue()
        ->and(DB::getDriverName())->toBe('mariadb')
        ->and(DB::connection()->getDatabaseName())->toBe('soulbuddy_audio_rehearsal')
        ->and(Schema::hasTable('migrations'))->toBeFalse();

    $file = '2026_11_03_000000_add_audio_authoring_metadata.php';
    $previous = collect(glob(database_path('migrations/*.php')))
        ->filter(fn (string $path): bool => strcmp(basename($path), $file) < 0)
        ->values()->all();
    $this->artisan('migrate', ['--realpath' => true, '--path' => $previous, '--force' => true])->assertSuccessful();

    $user = User::factory()->create();
    $prayer = (string) Str::uuid();
    $revision = (string) Str::uuid();
    $memory = (string) Str::uuid();
    $reflection = (string) Str::uuid();
    DB::table('personal_prayers')->insert([
        'id' => $prayer, 'user_id' => $user->id, 'title' => 'Existing prayer',
        'style' => 'situational', 'reach' => 'personal', 'grounding' => 'catholic', 'purpose' => 'family',
    ]);
    DB::table('personal_prayer_revisions')->insert([
        'id' => $revision, 'user_id' => $user->id, 'prayer_id' => $prayer,
        'body' => 'Existing words', 'device_id' => 'fixture', 'created_at' => now(),
    ]);
    DB::table('encounters')->insert([
        'id' => $memory, 'user_id' => $user->id, 'title' => 'Existing memory',
        'occurred_on' => '2026-11-01', 'current_revision_id' => (string) Str::uuid(),
    ]);
    DB::table('memory_reflections')->insert([
        'id' => $reflection, 'encounter_id' => $memory, 'user_id' => $user->id, 'body' => 'Existing reflection',
        'local_date' => '2026-11-01', 'device_id' => 'fixture', 'created_at' => now(),
    ]);
    $revisions = DB::table('personal_prayer_revisions')->where('id', $revision);
    $reflections = DB::table('memory_reflections')->where('id', $reflection);
    $options = ['--path' => ['database/migrations/'.$file], '--force' => true];
    $this->artisan('migrate', $options)->assertSuccessful();
    expect($revisions->value('content_format'))->toBe('text')
        ->and($revisions->value('body'))->toBe('Existing words')
        ->and($reflections->value('audio_encounter_id'))->toBeNull()
        ->and($reflections->value('body'))->toBe('Existing reflection');

    // The clean rollback removes the FK and both columns; old rows stay intact.
    $this->artisan('migrate:rollback', $options)->assertSuccessful();
    expect(Schema::hasColumn('personal_prayer_revisions', 'content_format'))->toBeFalse()
        ->and(Schema::hasColumn('memory_reflections', 'audio_encounter_id'))->toBeFalse()
        ->and($revisions->value('body'))->toBe('Existing words')
        ->and($reflections->value('body'))->toBe('Existing reflection');
    $this->artisan('migrate', $options)->assertSuccessful();

    $migration = require database_path('migrations/'.$file);
    $guard = 'Cannot remove audio authoring metadata while recorded content exists.';
    $revisions->update(['content_format' => 'audio', 'body' => '']);
    expect(fn () => $migration->down())->toThrow(RuntimeException::class, $guard);
    expect($revisions->value('content_format'))->toBe('audio');

    $revisions->update(['content_format' => 'text', 'body' => 'Existing words']);
    expect(fn () => $reflections->update(['audio_encounter_id' => (string) Str::uuid()]))->toThrow(QueryException::class);
    $reflections->update(['audio_encounter_id' => $memory]);
    expect(fn () => $migration->down())->toThrow(RuntimeException::class, $guard);
    expect($reflections->value('audio_encounter_id'))->toBe($memory);
});
