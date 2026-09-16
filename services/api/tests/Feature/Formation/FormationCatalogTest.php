<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;

uses(RefreshDatabase::class);

it('publishes one internally consistent catalog transaction', function () {
    $this->artisan('formation:publish', [
        'file' => resource_path('formation/daily_formation_v1.json'),
    ])->assertSuccessful();

    expect(DB::table('formation_catalog_versions')->where('published', true)->count())->toBe(1)
        ->and(DB::table('formation_videos')->count())->toBe(45)
        ->and(DB::table('formation_packs')->count())->toBe(10)
        ->and(DB::table('formation_days')->count())->toBe(70)
        ->and(DB::table('formation_rules')->count())->toBe(10);
});

it('keeps the prior publication active when validation fails', function () {
    $this->artisan('formation:publish', [
        'file' => resource_path('formation/daily_formation_v1.json'),
    ])->assertSuccessful();
    $published = DB::table('formation_catalog_versions')->where('published', true)->value('checksum');

    $bad = tempnam(sys_get_temp_dir(), 'formation-');
    file_put_contents($bad, '{"version":2,"videos":[]}');

    try {
        $this->artisan('formation:publish', ['file' => $bad])->assertFailed();
    } finally {
        unlink($bad);
    }

    expect(DB::table('formation_catalog_versions')->where('published', true)->value('checksum'))
        ->toBe($published);
});
