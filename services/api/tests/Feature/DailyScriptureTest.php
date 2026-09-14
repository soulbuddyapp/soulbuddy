<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;

uses(RefreshDatabase::class);

it('serves a stable scripture for an explicit calendar date', function () {
    $first = $this->getJson('/api/scriptures/daily?date=2026-09-11')->assertOk();
    $again = $this->getJson('/api/scriptures/daily?date=2026-09-11')->assertOk();
    expect($first->json('data'))->toBe($again->json('data'));
    $first->assertJsonPath('data.date', '2026-09-11')
        ->assertJsonPath('data.translation', 'RSVCE')
        ->assertJsonStructure(['data' => ['reference', 'text', 'theme', 'reflection', 'prayer', 'practice']]);
    expect($this->getJson('/api/scriptures/daily?date=2026-09-12')->json('data.reference'))
        ->not->toBe($first->json('data.reference'));
});

it('rejects invalid dates rather than silently changing the day', function (string $date) {
    $this->getJson('/api/scriptures/daily?date='.urlencode($date))->assertUnprocessable();
})->with(['2026-02-30', 'tomorrow', '2026-9-1']);

it('uses a manual replacement without changing adjacent days', function () {
    $original = $this->getJson('/api/scriptures/daily?date=2026-09-11')->json('data');
    $next = $this->getJson('/api/scriptures/daily?date=2026-09-12')->json('data');
    $replacement = array_replace($original, ['theme' => 'A faithful beginning']);
    DB::table('daily_scripture_overrides')->insert([
        'date' => '2026-09-11', 'content' => json_encode($replacement),
        'created_at' => now(), 'updated_at' => now(),
    ]);
    $this->getJson('/api/scriptures/daily?date=2026-09-11')->assertJsonPath('data.theme', 'A faithful beginning');
    expect($this->getJson('/api/scriptures/daily?date=2026-09-12')->json('data'))->toBe($next);
});

it('has no public scripture replacement endpoint', function () {
    $this->postJson('/api/scriptures/daily', ['text' => 'changed'])->assertStatus(405);
});

it('validates an operator replacement before saving', function () {
    $path = tempnam(sys_get_temp_dir(), 'scripture-test-');
    try {
        file_put_contents($path, json_encode(['text' => 'Incomplete']));
        $this->artisan('scriptures:replace', ['date' => '2026-09-11', 'file' => $path])->assertFailed();
        expect(DB::table('daily_scripture_overrides')->count())->toBe(0);
        $content = $this->getJson('/api/scriptures/daily?date=2026-09-11')->json('data');
        $content['theme'] = 'Faithful love';
        file_put_contents($path, json_encode($content));
        $this->artisan('scriptures:replace', ['date' => '2026-09-11', 'file' => $path])->assertSuccessful();
        $this->getJson('/api/scriptures/daily?date=2026-09-11')->assertJsonPath('data.theme', 'Faithful love');
    } finally {
        unlink($path);
    }
});
