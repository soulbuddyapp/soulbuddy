<?php

use Illuminate\Support\Str;

it('provides MariaDB integrity implementations for every prayer migration', function () {
    $migrations = [
        '2026_08_11_000000_create_prayer_library_tables.php' => [
            'createMariaDbVoteCountTriggers',
            'GREATEST(helpful_count - 1, 0)',
        ],
        '2026_08_11_000001_create_personal_prayer_tables.php' => [
            'createMariaDbIntegrityChecks',
            'today_prayers_exactly_one_source_insert',
        ],
        '2026_08_11_000002_create_prayer_practice_tables.php' => [
            'createMariaDbIntegrityChecks',
            'prayer_reminders_shape_insert',
        ],
        '2026_08_13_000000_support_library_prayer_sessions.php' => [
            'createMariaDbIntegrityChecks',
            'prayer_sessions_shape_update',
        ],
        '2026_08_26_000000_create_voice_tablet_altar_tables.php' => [
            'createMariaDbIntegrityChecks',
            'voice_tablets_shape',
            'altar_rituals_shape',
        ],
        '2026_08_31_000000_create_sacred_hour_tables.php' => [
            'createMariaDbIntegrityChecks',
            'sacred_hours_shape_{$suffix}',
            'NEW.duration_minutes = 60',
        ],
    ];

    foreach ($migrations as $filename => $needles) {
        $source = file_get_contents(
            dirname(__DIR__, 2)."/database/migrations/{$filename}",
        );

        expect($source)
            ->toContain("'mysql'")
            ->toContain("'mariadb'");
        foreach ($needles as $needle) {
            expect($source)->toContain($needle);
        }
        expect(Str::contains($source, 'require SQLite or PostgreSQL'))->toBeFalse();
    }
});

it('uses datetime columns for commitment session boundaries', function () {
    $source = file_get_contents(
        dirname(__DIR__, 2).'/database/migrations/2026_09_24_000000_create_commitment_tables.php',
    );

    expect($source)
        ->toContain("dateTime('started_at')")
        ->toContain("dateTime('ended_at')")
        ->not->toContain("timestamp('started_at')")
        ->not->toContain("timestamp('ended_at')");
});
