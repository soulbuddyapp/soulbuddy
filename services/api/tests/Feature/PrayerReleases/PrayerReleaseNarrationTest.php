<?php

use App\Domain\PrayerReleases\PrayerReleasePublisher;
use App\Domain\PrayerReleases\ReleaseContent;
use App\Models\PrayerRelease;
use App\Models\PrayerReleaseDownload;
use App\Models\PrayerReleaseItem;
use App\Models\User;
use Database\Seeders\PrayerReleaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

function narrationRelease(): PrayerRelease
{
    config()->set('prayer_releases.published_at', '2026-10-05 07:00:00');
    app(PrayerReleasePublisher::class)->publish(
        ReleaseContent::fromJsonFile(resource_path('prayer-releases/'.PrayerReleaseSeeder::SLUG.'.json')),
        config('prayer_releases.published_at'),
    );

    return PrayerRelease::query()->where('slug', PrayerReleaseSeeder::SLUG)->firstOrFail();
}

function narrationAdded(PrayerRelease $release, User $user): User
{
    PrayerReleaseDownload::query()->create([
        'id' => (string) Str::uuid(),
        'user_id' => $user->id,
        'release_id' => $release->id,
        'downloaded_at' => now(),
    ]);

    return $user;
}

it('requires an authenticated account', function () {
    $release = narrationRelease();
    $item = $release->items->first();

    $this->getJson("/api/prayer-release-items/{$item->id}/narration")->assertUnauthorized();
});

it('serves the exact visible text when no matching asset exists', function () {
    $release = narrationRelease();
    $item = $release->items->first();
    $user = narrationAdded($release, User::factory()->create());

    $response = $this->actingAs($user)->getJson("/api/prayer-release-items/{$item->id}/narration")
        ->assertOk()
        ->assertJsonPath('status', 'text_only')
        ->assertJsonPath('default_speed', 0.85)
        ->assertJsonPath('available_speeds', [0.7, 0.85, 1, 1.15])
        ->assertJsonMissingPath('narration_uri');

    $content = $response->json();
    $prayer = $item->libraryPrayer;

    expect($content['text'])->toBe($prayer->body)
        ->and($content['text'])->toStartWith("+\n")
        ->and($content['content_sha256'])
        ->toBe(hash('sha256', $prayer->title."\n".$prayer->body));
});

it('never serves narration for a collection the person has not added', function () {
    $release = narrationRelease();
    $item = $release->items->first();
    $user = User::factory()->create();

    $this->actingAs($user)->getJson("/api/prayer-release-items/{$item->id}/narration")
        ->assertNotFound()
        ->assertJsonPath('code', 'release_not_added');
});

it('refuses an asset whose transcript is not this exact content', function () {
    $release = narrationRelease();
    $item = $release->items->first();
    $user = narrationAdded($release, User::factory()->create());

    $item->forceFill([
        'narration_uri' => 'prayer-releases/planted.mp3',
        'narration_content_sha256' => str_repeat('a', 64),
    ])->save();

    $this->actingAs($user)->getJson("/api/prayer-release-items/{$item->id}/narration")
        ->assertOk()
        ->assertJsonPath('status', 'text_only');
});

it('refuses to speak when the stored content no longer matches its hash', function () {
    $release = narrationRelease();
    $item = $release->items->first();
    $user = narrationAdded($release, User::factory()->create());

    // Someone changed the wording in the database without updating the hash.
    $item->libraryPrayer->forceFill(['body' => 'A different prayer entirely.'])->save();
    $item->forceFill([
        'narration_uri' => 'prayer-releases/planted.mp3',
        'narration_content_sha256' => $item->content_sha256,
    ])->save();

    $this->actingAs($user)->getJson("/api/prayer-release-items/{$item->id}/narration")
        ->assertStatus(503)
        ->assertJsonPath('code', 'narration_content_mismatch');
});

it('offers the asset only when its transcript hash matches the content', function () {
    $release = narrationRelease();
    $content = ReleaseContent::fromJsonFile(resource_path('prayer-releases/'.PrayerReleaseSeeder::SLUG.'.json'));
    $item = $release->items[3];
    $user = narrationAdded($release, User::factory()->create());

    app(PrayerReleasePublisher::class)->attachNarration(
        $content,
        3,
        'prayer-releases/new-adam.mp3',
        ReleaseContent::contentHash($content->items[3]->title, $content->items[3]->body),
    );

    $this->actingAs($user)->getJson("/api/prayer-release-items/{$item->id}/narration")
        ->assertOk()
        ->assertJsonPath('status', 'ready')
        ->assertJsonPath('narration_uri', 'prayer-releases/new-adam.mp3')
        ->assertJsonPath('default_speed', 0.85)
        ->assertJsonPath('content_sha256', ReleaseContent::contentHash($content->items[3]->title, $content->items[3]->body));

    expect(PrayerReleaseItem::query()->whereKey($item->id)->firstOrFail()->narrationMatchesContent())->toBeTrue();
});

it('offers only the four approved spoken paces', function () {
    $release = narrationRelease();
    $item = $release->items->first();
    $user = narrationAdded($release, User::factory()->create());

    $speeds = $this->actingAs($user)->getJson("/api/prayer-release-items/{$item->id}/narration")
        ->assertOk()
        ->json('available_speeds');

    expect($speeds)->toBe([0.7, 0.85, 1, 1.15])
        ->and($speeds)->not->toContain(1.25)
        ->and($speeds)->not->toContain(0.5);
});
