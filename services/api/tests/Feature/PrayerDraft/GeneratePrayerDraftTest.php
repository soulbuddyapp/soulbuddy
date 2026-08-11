<?php

use App\Domain\PrayerDrafts\PrayerDraftProvider;
use App\Domain\PrayerDrafts\PrayerDraftRateLimited;
use App\Domain\PrayerDrafts\PrayerDraftResult;
use App\Domain\PrayerDrafts\PrayerDraftUnavailable;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

beforeEach(function () {
    config()->set('services.deepseek.disclosure_version', 'deepseek-1');
    config()->set('services.deepseek.prompt_version', '1');
});

it('requires an authenticated application session', function () {
    $this->postJson('/api/prayer-drafts', validPrayerDraftPayload())
        ->assertUnauthorized();
});

it('returns one validated draft without logging or caching private content', function () {
    $user = User::factory()->create();
    $private = 'Help my family through this private decision.';
    Log::spy();
    $this->mock(PrayerDraftProvider::class)
        ->shouldReceive('generate')
        ->once()
        ->andReturn(validPrayerDraftResult());

    $attemptId = (string) Str::uuid();
    $this->actingAs($user)
        ->postJson('/api/prayer-drafts', validPrayerDraftPayload(
            attemptId: $attemptId,
            requestText: $private,
        ))
        ->assertOk()
        ->assertJsonPath('draft.title', 'For wisdom')
        ->assertJsonPath('prompt_version', '1')
        ->assertJsonPath('disclosure_version', 'deepseek-1')
        ->assertJsonMissing(['request_text' => $private]);

    $cached = Cache::get("prayer-draft:{$user->public_id}:{$attemptId}");
    expect($cached)->toBeString()->not->toContain($private);
    foreach (['error', 'warning', 'info', 'debug', 'log'] as $level) {
        Log::shouldNotHaveReceived($level);
    }
});

it('accepts a daily request with no optional choices or selected context', function () {
    $this->mock(PrayerDraftProvider::class)
        ->shouldReceive('generate')
        ->once()
        ->andReturn(validPrayerDraftResult());
    $payload = validPrayerDraftPayload();
    $payload['style'] = 'daily';
    $payload['choices'] = [];
    $payload['contexts'] = [];

    $this->actingAs(User::factory()->create())
        ->postJson('/api/prayer-drafts', $payload)
        ->assertOk()
        ->assertJsonPath('draft.title', 'For wisdom');
});

it('rejects unknown keys before ordinary validation', function (array $change, string $path) {
    $payload = validPrayerDraftPayload();
    data_set($payload, $path, $change['value']);

    $this->actingAs(User::factory()->create())
        ->postJson('/api/prayer-drafts', $payload)
        ->assertUnprocessable()
        ->assertJsonPath('errors.payload.0', 'unknown_keys');
})->with([
    'top level owner id' => [['value' => 'private-owner'], 'owner_id'],
    'unknown choice' => [['value' => 'unused'], 'choices.open_question'],
    'unknown context' => [['value' => 'unused'], 'contexts.0.raw_record'],
]);

it('rejects invalid consent, enums, sizes, and duplicate context types', function (array $payload) {
    $this->actingAs(User::factory()->create())
        ->postJson('/api/prayer-drafts', $payload)
        ->assertUnprocessable();
})->with([
    'no consent' => fn () => validPrayerDraftPayload(consent: false),
    'wrong disclosure' => function () {
        $payload = validPrayerDraftPayload();
        $payload['disclosure_version'] = 'old-version';

        return $payload;
    },
    'invalid style' => function () {
        $payload = validPrayerDraftPayload();
        $payload['style'] = 'prosperity';

        return $payload;
    },
    'request over 500 characters' => fn () => validPrayerDraftPayload(requestText: str_repeat('a', 501)),
    'encounter over 2000 characters' => function () {
        $payload = validPrayerDraftPayload();
        $payload['contexts'][0]['excerpt_snapshot'] = str_repeat('a', 2001);

        return $payload;
    },
    'duplicate context type' => function () {
        $payload = validPrayerDraftPayload();
        $payload['contexts'][] = $payload['contexts'][0];

        return $payload;
    },
    'scripture over 4000 characters' => function () {
        $payload = validPrayerDraftPayload();
        $payload['contexts'] = [validScriptureContext()];
        $payload['contexts'][0]['excerpt_snapshot'] = str_repeat('a', 4001);

        return $payload;
    },
    'scripture over 20 verses' => function () {
        $payload = validPrayerDraftPayload();
        $payload['contexts'] = [validScriptureContext()];
        $payload['contexts'][0]['last_verse'] = 30;

        return $payload;
    },
    'encounter with Scripture metadata' => function () {
        $payload = validPrayerDraftPayload();
        $payload['contexts'][0]['translation'] = 'RSVCE';

        return $payload;
    },
]);

it('maps provider limits and outages to content-free client responses', function (
    Throwable $exception,
    int $status,
    ?string $code,
) {
    $this->mock(PrayerDraftProvider::class)
        ->shouldReceive('generate')
        ->once()
        ->andThrow($exception);

    $response = $this->actingAs(User::factory()->create())
        ->postJson('/api/prayer-drafts', validPrayerDraftPayload())
        ->assertStatus($status)
        ->assertJsonPath('code', $code)
        ->assertJsonMissing(['request_text' => 'Help my family receive wisdom today.']);

    if ($exception instanceof PrayerDraftRateLimited) {
        $response->assertHeader('Retry-After', '17');
    }
})->with([
    'provider limit' => [new PrayerDraftRateLimited(17), 429, 'rate_limited'],
    'provider outage' => [new PrayerDraftUnavailable, 503, 'temporarily_unavailable'],
]);

it('replays an encrypted result idempotently for ten minutes', function () {
    $user = User::factory()->create();
    $attemptId = (string) Str::uuid();
    $this->mock(PrayerDraftProvider::class)
        ->shouldReceive('generate')
        ->once()
        ->andReturn(validPrayerDraftResult());

    $payload = validPrayerDraftPayload(attemptId: $attemptId);
    $first = $this->actingAs($user)->postJson('/api/prayer-drafts', $payload)->assertOk();
    $second = $this->actingAs($user)->postJson('/api/prayer-drafts', $payload)->assertOk();

    expect($second->json('draft'))->toBe($first->json('draft'));
});

it('repairs one invalid result using safe validation codes only', function () {
    $user = User::factory()->create();
    $provider = $this->mock(PrayerDraftProvider::class);
    $provider->shouldReceive('generate')
        ->once()
        ->withArgs(fn ($input, $repairCodes) => $repairCodes === null)
        ->andReturn(new PrayerDraftResult('For wisdom', 'Too short. Amen.', null));
    $provider->shouldReceive('generate')
        ->once()
        ->withArgs(function ($input, $repairCodes) {
            $encoded = json_encode($repairCodes, JSON_THROW_ON_ERROR);

            return in_array('body_word_count', $repairCodes, true)
                && ! str_contains($encoded, $input->requestText);
        })
        ->andReturn(validPrayerDraftResult());

    $this->actingAs($user)
        ->postJson('/api/prayer-drafts', validPrayerDraftPayload())
        ->assertOk()
        ->assertJsonPath('draft.title', 'For wisdom');
});

it('never returns a second invalid provider result', function () {
    $private = 'Private family difficulty';
    $this->mock(PrayerDraftProvider::class)
        ->shouldReceive('generate')
        ->twice()
        ->andReturn(new PrayerDraftResult('For wisdom', 'Too short. Amen.', null));

    $this->actingAs(User::factory()->create())
        ->postJson('/api/prayer-drafts', validPrayerDraftPayload(requestText: $private))
        ->assertStatus(502)
        ->assertJsonPath('code', 'draft_needs_attention')
        ->assertJsonMissing(['private' => $private]);
});

it('acknowledges only the authenticated users cached attempt', function () {
    $firstUser = User::factory()->create();
    $secondUser = User::factory()->create();
    $attemptId = (string) Str::uuid();
    $this->mock(PrayerDraftProvider::class)
        ->shouldReceive('generate')
        ->once()
        ->andReturn(validPrayerDraftResult());

    $this->actingAs($firstUser)
        ->postJson('/api/prayer-drafts', validPrayerDraftPayload(attemptId: $attemptId))
        ->assertOk();
    $this->actingAs($secondUser)
        ->deleteJson("/api/prayer-drafts/{$attemptId}")
        ->assertNoContent();
    expect(Cache::has("prayer-draft:{$firstUser->public_id}:{$attemptId}"))->toBeTrue();

    $this->actingAs($firstUser)
        ->deleteJson("/api/prayer-drafts/{$attemptId}")
        ->assertNoContent();
    expect(Cache::has("prayer-draft:{$firstUser->public_id}:{$attemptId}"))->toBeFalse();
});

it('rate limits generation by authenticated user', function () {
    $user = User::factory()->create();
    $this->mock(PrayerDraftProvider::class)
        ->shouldReceive('generate')
        ->times(10)
        ->andReturn(validPrayerDraftResult());

    foreach (range(1, 10) as $index) {
        $this->actingAs($user)
            ->postJson('/api/prayer-drafts', validPrayerDraftPayload())
            ->assertOk();
    }
    $this->actingAs($user)
        ->postJson('/api/prayer-drafts', validPrayerDraftPayload())
        ->assertTooManyRequests();
});

function validPrayerDraftPayload(
    ?string $attemptId = null,
    string $requestText = 'Help my family receive wisdom today.',
    bool $consent = true,
): array {
    return [
        'attempt_id' => $attemptId ?? (string) Str::uuid(),
        'disclosure_version' => 'deepseek-1',
        'consent' => $consent,
        'style' => 'situational',
        'reach' => 'encompassing',
        'grounding' => 'general_christian',
        'purpose' => 'family',
        'request_text' => $requestText,
        'choices' => [
            'beneficiary' => 'household_family',
            'surrender' => 'all',
            'responsibility' => 'act_faithfully',
            'alignment' => 'no_conflict_seen',
        ],
        'contexts' => [[
            'type' => 'encounter',
            'source_id' => (string) Str::uuid(),
            'display_label' => 'A remembered conversation',
            'excerpt_snapshot' => 'We listened carefully and chose peace.',
        ]],
    ];
}

function validPrayerDraftResult(): PrayerDraftResult
{
    return new PrayerDraftResult(
        'For wisdom',
        'Father, give us wisdom as we face this decision. Keep us truthful, patient, and ready to listen. Guard us from fear, pride, and haste. Help us consider everyone affected, receive correction with humility, and act with love. We entrust the outcome, the timing, and the way forward to you. Strengthen us to do what is faithful, repair any harm, and serve one another in peace. Through every uncertainty, keep our hearts near you and our steps honest. Amen.',
        'Listen carefully before offering an answer.',
    );
}

function validScriptureContext(): array
{
    return [
        'type' => 'scripture',
        'source_id' => 'John-15-9-10',
        'display_label' => 'John 15:9-10',
        'excerpt_snapshot' => '9 Remain in my love. 10 Keep my commandments.',
        'translation' => 'RSVCE',
        'book' => 'John',
        'chapter' => 15,
        'first_verse' => 9,
        'last_verse' => 10,
    ];
}
