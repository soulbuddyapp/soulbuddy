<?php

use App\Domain\PrayerReleases\PrayerReleasePublisher;
use App\Domain\PrayerReleases\ReleaseContent;
use App\Models\PrayerRelease;
use App\Models\PrayerReleaseDownload;
use App\Models\PrayerReleasePreference;
use App\Models\User;
use Database\Seeders\PrayerReleaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

function apiReleaseContent(): ReleaseContent
{
    return ReleaseContent::fromJsonFile(
        dirname(__DIR__, 3).'/resources/prayer-releases/'.PrayerReleaseSeeder::SLUG.'.json',
    );
}

function apiUser(): User
{
    return User::factory()->create();
}

function seedPublishedRelease(): PrayerRelease
{
    app(PrayerReleasePublisher::class)->publish(apiReleaseContent(), config('prayer_releases.published_at'));

    return PrayerRelease::query()->where('slug', PrayerReleaseSeeder::SLUG)->firstOrFail();
}

beforeEach(function () {
    config()->set('prayer_releases.published_at', '2026-10-05 07:00:00');
    $this->travelTo(now()->setDate(2026, 10, 6)->setTime(9, 0)->utc());
});

it('requires an authenticated account for discovery, preferences, and adding', function () {
    $release = seedPublishedRelease();

    $this->getJson('/api/prayer-releases')->assertUnauthorized();
    $this->putJson('/api/prayer-release-preference', [
        'weekly_enabled' => true,
        'notification_enabled' => true,
        'time_zone' => 'UTC',
    ])->assertUnauthorized();
    $this->postJson("/api/prayer-releases/{$release->slug}/add")->assertUnauthorized();
});

it('lists a published release with ordered item metadata and no bodies', function () {
    $release = seedPublishedRelease();
    $user = apiUser();

    $response = $this->actingAs($user)->getJson('/api/prayer-releases')
        ->assertOk()
        ->assertJsonPath('releases.0.slug', PrayerReleaseSeeder::SLUG)
        ->assertJsonPath('releases.0.title', 'Renewed mind & guarded heart')
        ->assertJsonPath('releases.0.discovery_label', 'This week’s prayer')
        ->assertJsonPath('releases.0.added_at', null)
        ->assertJsonPath('releases.0.preparation_text', null)
        ->assertJsonPath('preference.weekly_enabled', false)
        ->assertJsonPath('preference.notification_enabled', true);

    $content = $this->getJson('/api/prayer-releases')->assertOk()->json();

    expect($content['releases'][0]['items'])->toHaveCount(5)
        ->and(array_column($content['releases'][0]['items'], 'sort_order'))->toBe([0, 1, 2, 3, 4])
        ->and(array_column($content['releases'][0]['items'], 'kind'))->toBe([
            'prayer',
            'meditation_prayer',
            'prayer',
            'meditation_prayer',
            'prayer',
        ])
        ->and(array_column($content['releases'][0]['items'], 'library_prayer_id'))
        ->toBe(array_map(
            static fn (int $order): string => $content['releases'][0]['items'][$order]['library_prayer_id'],
            [0, 1, 2, 3, 4],
        ))
        ->and($content['releases'][0]['items'][3]['has_attention_practice'])->toBeTrue();

    // Metadata before an add never carries source wording.
    foreach ($content['releases'][0]['items'] as $item) {
        expect($item)->not->toHaveKey('body')
            ->and($item)->not->toHaveKey('content_sha256')
            ->and($item)->not->toHaveKey('practice');
    }

    expect(json_encode($content))->not->toContain('Jesus humbled himself')
        ->and(json_encode($content))->not->toContain('new Adam');
});

it('omits an unpublished or archived release from discovery', function () {
    $release = seedPublishedRelease();
    $user = apiUser();

    $release->forceFill(['published_at' => '2026-10-07 07:00:00'])->save();
    $this->actingAs($user)->getJson('/api/prayer-releases')
        ->assertOk()
        ->assertJsonPath('releases', []);

    $release->forceFill([
        'published_at' => '2026-10-05 07:00:00',
        'archived_at' => now(),
    ])->save();
    $this->actingAs($user)->getJson('/api/prayer-releases')
        ->assertOk()
        ->assertJsonPath('releases', []);
});

it('stores an opt-in preference and reflects it in discovery', function () {
    seedPublishedRelease();
    $user = apiUser();

    $this->actingAs($user)->putJson('/api/prayer-release-preference', [
        'weekly_enabled' => true,
        'notification_enabled' => true,
        'time_zone' => 'Africa/Lagos',
    ])->assertOk()
        ->assertJsonPath('preference.weekly_enabled', true)
        ->assertJsonPath('preference.notification_enabled', true)
        ->assertJsonPath('preference.time_zone', 'Africa/Lagos');

    $preference = PrayerReleasePreference::query()->where('user_id', $user->id)->firstOrFail();
    expect($preference->receivesDelivery())->toBeTrue();

    $this->actingAs($user)->getJson('/api/prayer-releases')
        ->assertOk()
        ->assertJsonPath('preference.weekly_enabled', true)
        ->assertJsonPath('preference.time_zone', 'Africa/Lagos');
});

it('stops future notices when weekly delivery is turned off without touching added content', function () {
    $release = seedPublishedRelease();
    $user = apiUser();

    $this->actingAs($user)->putJson('/api/prayer-release-preference', [
        'weekly_enabled' => true,
        'notification_enabled' => true,
        'time_zone' => 'UTC',
    ])->assertOk();
    $this->actingAs($user)->postJson("/api/prayer-releases/{$release->slug}/add")->assertCreated();

    $this->actingAs($user)->putJson('/api/prayer-release-preference', [
        'weekly_enabled' => false,
        'notification_enabled' => false,
        'time_zone' => 'UTC',
    ])->assertOk()
        ->assertJsonPath('preference.weekly_enabled', false);

    expect(PrayerReleasePreference::query()->where('user_id', $user->id)->firstOrFail()->receivesDelivery())->toBeFalse()
        ->and(PrayerReleaseDownload::query()->where('user_id', $user->id)->count())->toBe(1);
});

it('rejects an unknown time zone and unknown payload keys', function () {
    $user = apiUser();

    $this->actingAs($user)->putJson('/api/prayer-release-preference', [
        'weekly_enabled' => true,
        'notification_enabled' => true,
        'time_zone' => 'Mars/Olympus',
    ])->assertUnprocessable()->assertJsonValidationErrors('time_zone');

    $this->actingAs($user)->putJson('/api/prayer-release-preference', [
        'weekly_enabled' => true,
        'notification_enabled' => true,
        'time_zone' => 'UTC',
        'user_id' => 9999,
    ])->assertUnprocessable()->assertJsonValidationErrors('payload');
});

it('adds a release once and returns the complete exact content', function () {
    $release = seedPublishedRelease();
    $user = apiUser();
    $content = apiReleaseContent();

    $response = $this->actingAs($user)->postJson("/api/prayer-releases/{$release->slug}/add")
        ->assertCreated()
        ->assertJsonPath('slug', PrayerReleaseSeeder::SLUG)
        ->assertJsonPath('added_at', '2026-10-06T09:00:00+00:00');

    $payload = $response->json();

    expect($payload['preparation_text'])->toBe($content->preparationText)
        ->and($payload['items'])->toHaveCount(5);

    foreach ($content->items as $item) {
        $served = $payload['items'][$item->sortOrder];

        expect($served['body'])->toBe($item->body)
            ->and($served['title'])->toBe($item->title)
            ->and($served['kind'])->toBe($item->kind)
            ->and($served['library_prayer_id'])->toBe($content->libraryPrayerId($item->sortOrder))
            ->and($served['action'])->toBeNull()
            ->and($served['content_sha256'])->toBe(hash('sha256', $item->title."\n".$item->body))
            ->and($served['practice'])->toBe($item->practice === null ? null : [
                'mode' => 'affirmation_repetition',
                'steps' => array_map(
                    static fn ($step): array => [
                        'phrase' => $step->phrase,
                        'target_count' => $step->targetCount,
                        'source_line' => $step->sourceLine,
                    ],
                    $item->practice->steps,
                ),
            ]);
    }

    expect($payload['items'][3]['body'])
        ->toBe("Dear Lord, renew my mind and heart and make me a new Adam in Christ Jesus (x50)\n"
            ."In moments that distract me from your perfect will, let Satan be rebuked o Lord (x10)");
});

it('makes a repeated add idempotent for the same account', function () {
    $release = seedPublishedRelease();
    $user = apiUser();

    $first = $this->actingAs($user)->postJson("/api/prayer-releases/{$release->slug}/add")->assertCreated();
    $this->travelTo(now()->addDays(3));
    $second = $this->actingAs($user)->postJson("/api/prayer-releases/{$release->slug}/add")->assertOk();

    expect(PrayerReleaseDownload::query()->where('user_id', $user->id)->count())->toBe(1)
        ->and($second->json('added_at'))->toBe($first->json('added_at'))
        ->and($second->json('items'))->toBe($first->json('items'));
});

it('keeps one account download out of another account library', function () {
    $release = seedPublishedRelease();
    $first = apiUser();
    $second = apiUser();

    $this->actingAs($first)->postJson("/api/prayer-releases/{$release->slug}/add")->assertCreated();

    expect(PrayerReleaseDownload::query()->where('user_id', $second->id)->count())->toBe(0);

    $this->actingAs($second)->getJson('/api/prayer-releases')
        ->assertOk()
        ->assertJsonPath('releases.0.added_at', null);
});

it('hides an archived release from the add route', function () {
    $release = seedPublishedRelease();
    $user = apiUser();

    $release->forceFill(['archived_at' => now()])->save();

    $this->actingAs($user)->postJson("/api/prayer-releases/{$release->slug}/add")->assertNotFound();
    expect(PrayerReleaseDownload::query()->count())->toBe(0);
});

it('keeps an added release readable after the release is archived', function () {
    $release = seedPublishedRelease();
    $user = apiUser();

    $this->actingAs($user)->postJson("/api/prayer-releases/{$release->slug}/add")->assertCreated();
    $release->forceFill(['archived_at' => now()])->save();

    $this->actingAs($user)->postJson("/api/prayer-releases/{$release->slug}/add")->assertNotFound();
    expect(PrayerReleaseDownload::query()->where('user_id', $user->id)->count())->toBe(1);
});

it('never exposes memorare through any release route', function () {
    $release = seedPublishedRelease();
    $user = apiUser();

    $discovery = $this->actingAs($user)->getJson('/api/prayer-releases')->assertOk()->content();
    $added = $this->actingAs($user)->postJson("/api/prayer-releases/{$release->slug}/add")->assertCreated()->content();

    expect(stripos($discovery, 'memorare'))->toBeFalse()
        ->and(stripos(json_encode($added), 'memorare'))->toBeFalse();
});
