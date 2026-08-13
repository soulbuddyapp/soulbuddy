<?php

use App\Domain\PrayerNarrations\PrayerNarrationAudio;
use App\Domain\PrayerNarrations\PrayerNarrationProvider;
use App\Models\PersonalPrayer;
use App\Models\PersonalPrayerRevision;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

beforeEach(function () {
    Storage::fake('local');
    config()->set('services.deepgram.disclosure_version', 'deepgram-aura2-1');
    config()->set('services.deepgram.model', 'aura-2-thalia-en');
    config()->set('services.deepgram.encoding', 'mp3');
    config()->set('services.deepgram.bit_rate', 32000);
});

it('requires authentication and exact current narration consent', function () {
    $user = User::factory()->create();
    [$prayer, $revision] = ownedPrayerRevision($user);

    $this->postJson('/api/prayer-narrations', narrationPayload($prayer, $revision))
        ->assertUnauthorized();

    $payload = narrationPayload($prayer, $revision);
    $payload['disclosure_version'] = 'old';
    $this->actingAs($user)->postJson('/api/prayer-narrations', $payload)
        ->assertUnprocessable();

    $payload['disclosure_version'] = 'deepgram-aura2-1';
    $payload['consent'] = false;
    $this->actingAs($user)->postJson('/api/prayer-narrations', $payload)
        ->assertUnprocessable();
});

it('loads only an owned immutable revision and never accepts arbitrary text', function () {
    $owner = User::factory()->create();
    $other = User::factory()->create();
    [$prayer, $revision] = ownedPrayerRevision($owner);

    $payload = narrationPayload($prayer, $revision);
    $payload['text'] = 'Client supplied text must not be narrated.';
    $this->actingAs($owner)->postJson('/api/prayer-narrations', $payload)
        ->assertUnprocessable()
        ->assertJsonPath('errors.payload.0', 'unknown_keys');

    $this->actingAs($other)
        ->postJson('/api/prayer-narrations', narrationPayload($prayer, $revision))
        ->assertNotFound();

    [$differentPrayer] = ownedPrayerRevision($owner);
    $this->actingAs($owner)
        ->postJson('/api/prayer-narrations', narrationPayload($differentPrayer, $revision))
        ->assertNotFound();
});

it('rejects narration above the provider limit before synthesis', function () {
    $user = User::factory()->create();
    [$prayer, $revision] = ownedPrayerRevision($user, str_repeat('a', 2001));
    $provider = $this->mock(PrayerNarrationProvider::class);
    $provider->shouldNotReceive('synthesize');

    $this->actingAs($user)
        ->postJson('/api/prayer-narrations', narrationPayload($prayer, $revision))
        ->assertUnprocessable()
        ->assertJsonPath('code', 'narration_too_long');
});

it('caches one encrypted narration by exact content and voice configuration', function () {
    $user = User::factory()->create();
    [$prayer, $revision] = ownedPrayerRevision($user, 'Father, teach me to walk faithfully. Amen.');
    $privateBody = $revision->body;
    $audio = str_repeat('mp3-bytes-', 120);
    Log::spy();

    $provider = $this->mock(PrayerNarrationProvider::class);
    $provider->shouldReceive('synthesize')
        ->once()
        ->with($privateBody)
        ->andReturn(new PrayerNarrationAudio($audio, 'audio/mpeg'));

    $first = $this->actingAs($user)
        ->postJson('/api/prayer-narrations', narrationPayload($prayer, $revision))
        ->assertOk()
        ->assertJsonPath('status', 'ready')
        ->assertJsonPath('revision_id', $revision->id)
        ->assertJsonPath('content_type', 'audio/mpeg')
        ->assertJsonMissing(['body' => $privateBody]);
    $second = $this->actingAs($user)
        ->postJson('/api/prayer-narrations', narrationPayload($prayer, $revision))
        ->assertOk();

    expect($second->json('playback_url'))->not->toBeEmpty()
        ->and(Storage::disk('local')->allFiles('prayer-narrations'))->toHaveCount(1)
        ->and(Storage::disk('local')->get(Storage::disk('local')->allFiles('prayer-narrations')[0]))
        ->not->toContain($audio);
    foreach (['error', 'warning', 'info', 'debug', 'log'] as $level) {
        Log::shouldNotHaveReceived($level);
    }

    $this->withHeader('Authorization', 'Bearer unused');
    $this->actingAs($user)
        ->get($first->json('playback_url'))
        ->assertOk()
        ->assertHeader('content-type', 'audio/mpeg')
        ->assertContent($audio);
});

it('keeps playback authenticated, signed, short lived, and ownership scoped', function () {
    $owner = User::factory()->create();
    $other = User::factory()->create();
    [$prayer, $revision] = ownedPrayerRevision($owner);
    $this->mock(PrayerNarrationProvider::class)
        ->shouldReceive('synthesize')
        ->once()
        ->andReturn(new PrayerNarrationAudio('safe-mp3', 'audio/mpeg'));

    $url = $this->actingAs($owner)
        ->postJson('/api/prayer-narrations', narrationPayload($prayer, $revision))
        ->assertOk()
        ->json('playback_url');

    auth()->forgetGuards();
    $this->getJson($url)->assertUnauthorized();
    $this->actingAs($other)->getJson($url)->assertNotFound();
    $this->actingAs($owner)->getJson($url.'&tampered=1')->assertForbidden();
    $this->actingAs($owner)->get($url)->assertOk()->assertContent('safe-mp3');
});

it('rejects unsafe provider content without caching bytes or private text', function (
    PrayerNarrationAudio $audio,
) {
    $user = User::factory()->create();
    [$prayer, $revision] = ownedPrayerRevision($user);
    Log::spy();
    $this->mock(PrayerNarrationProvider::class)
        ->shouldReceive('synthesize')
        ->once()
        ->andReturn($audio);

    $this->actingAs($user)
        ->postJson('/api/prayer-narrations', narrationPayload($prayer, $revision))
        ->assertServiceUnavailable()
        ->assertJsonPath('code', 'narration_unavailable')
        ->assertJsonMissing(['body' => $revision->body]);

    expect(Storage::disk('local')->allFiles('prayer-narrations'))->toBeEmpty();
    foreach (['error', 'warning', 'info', 'debug', 'log'] as $level) {
        Log::shouldNotHaveReceived($level);
    }
})->with([
    'wrong type' => fn () => new PrayerNarrationAudio('not audio', 'text/plain'),
    'empty' => fn () => new PrayerNarrationAudio('', 'audio/mpeg'),
    'too large' => fn () => new PrayerNarrationAudio(str_repeat('a', 2_000_001), 'audio/mpeg'),
]);

function ownedPrayerRevision(User $user, string $body = 'Father, keep me near you and faithful today. Amen.'): array
{
    $prayer = PersonalPrayer::create([
        'id' => (string) Str::uuid(),
        'user_id' => $user->id,
        'title' => 'A private prayer',
        'style' => 'daily',
        'reach' => 'personal',
        'grounding' => 'general_christian',
        'purpose' => 'character',
        'created_at' => now(),
        'updated_at' => now(),
    ]);
    $revision = PersonalPrayerRevision::create([
        'id' => (string) Str::uuid(),
        'prayer_id' => $prayer->id,
        'user_id' => $user->id,
        'body' => $body,
        'created_at' => now(),
        'device_id' => 'test-device',
    ]);
    $prayer->forceFill(['current_revision_id' => $revision->id])->save();

    return [$prayer->fresh(), $revision->fresh()];
}

function narrationPayload(PersonalPrayer $prayer, PersonalPrayerRevision $revision): array
{
    return [
        'personal_prayer_id' => $prayer->id,
        'prayer_revision_id' => $revision->id,
        'disclosure_version' => 'deepgram-aura2-1',
        'consent' => true,
    ];
}
