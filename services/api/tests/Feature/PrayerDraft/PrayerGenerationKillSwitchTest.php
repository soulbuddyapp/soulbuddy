<?php

use App\Domain\PrayerDrafts\PrayerDraftProvider;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

it('keeps prayer generation disabled by default', function () {
    expect(config('services.deepseek.prayer_generation_enabled'))->toBeFalse();
});

it('blocks provider calls when prayer generation is disabled', function () {
    config()->set('services.deepseek.prayer_generation_enabled', false);
    config()->set('services.deepseek.disclosure_version', 'deepseek-1');
    $this->mock(PrayerDraftProvider::class)->shouldNotReceive('generate');

    $this->actingAs(User::factory()->create())
        ->postJson('/api/prayer-drafts', disabledPrayerGenerationPayload())
        ->assertStatus(503)
        ->assertExactJson(['code' => 'generation_disabled']);
});

function disabledPrayerGenerationPayload(): array
{
    return [
        'attempt_id' => (string) Str::uuid(),
        'disclosure_version' => 'deepseek-1',
        'consent' => true,
        'style' => 'daily',
        'reach' => 'personal',
        'grounding' => 'general_christian',
        'language_preference' => 'christian',
        'purpose' => 'guidance',
        'request_text' => 'Give me wisdom for the next faithful step.',
        'choices' => [],
        'contexts' => [],
    ];
}
