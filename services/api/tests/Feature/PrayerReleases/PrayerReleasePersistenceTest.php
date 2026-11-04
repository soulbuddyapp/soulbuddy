<?php

use App\Models\LibraryPrayer;
use App\Models\PrayerRelease;
use App\Models\PrayerReleaseDownload;
use App\Models\PrayerReleaseItem;
use App\Models\PrayerReleasePreference;
use App\Models\PrayerVote;
use App\Models\TodayPrayer;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

function releaseUser(): User
{
    return User::factory()->create();
}

function releasePrayer(string $title = 'Release prayer'): LibraryPrayer
{
    return LibraryPrayer::query()->create([
        'id' => (string) Str::uuid(),
        'title' => $title,
        'body' => 'Faithful source body.',
        'grounding' => 'general_christian',
        'language_style' => 'christian',
        'purpose' => 'daily',
        'action' => null,
        'helpful_count' => 0,
        'published_at' => '2026-08-11 00:00:00',
        'archived_at' => null,
    ]);
}

function publishedRelease(?string $slug = 'renewed-mind-and-guarded-heart-v1', int $itemCount = 2): PrayerRelease
{
    $release = PrayerRelease::query()->create([
        'id' => (string) Str::uuid(),
        'slug' => $slug,
        'title' => 'Renewed mind & guarded heart',
        'discovery_label' => 'This week’s prayer',
        'discovery_detail' => 'Prayer and meditation for purity, discipline, and a renewed mind.',
        'preparation_text' => 'Before you Pray - Preparation for a graceful prayer',
        'published_at' => '2026-10-05 07:00:00',
        'archived_at' => null,
    ]);

    for ($order = 0; $order < $itemCount; $order++) {
        $prayer = releasePrayer('Release prayer '.$order);
        PrayerReleaseItem::query()->create([
            'id' => (string) Str::uuid(),
            'release_id' => $release->id,
            'library_prayer_id' => $prayer->id,
            'kind' => $order % 2 === 0 ? 'prayer' : 'meditation_prayer',
            'sort_order' => $order,
            'content_sha256' => hash('sha256', "Release prayer {$order}\nFaithful source body."),
            'practice_mode' => null,
            'practice_steps' => null,
            'narration_uri' => null,
            'narration_content_sha256' => null,
        ]);
    }

    return $release->fresh('items');
}

function releaseDownload(User $user, PrayerRelease $release, ?string $at = null): PrayerReleaseDownload
{
    return PrayerReleaseDownload::query()->create([
        'id' => (string) Str::uuid(),
        'user_id' => $user->id,
        'release_id' => $release->id,
        'downloaded_at' => $at ?? now(),
    ]);
}

it('stores a release with ordered items linked to canonical prayers', function () {
    $release = publishedRelease();

    expect($release->items)->toHaveCount(2)
        ->and($release->items->pluck('sort_order')->all())->toBe([0, 1])
        ->and($release->items->pluck('kind')->all())->toBe(['prayer', 'meditation_prayer'])
        ->and($release->items->first()->libraryPrayer)->toBeInstanceOf(LibraryPrayer::class)
        ->and($release->items->first()->libraryPrayer->releaseItems->pluck('release_id')->all())
        ->toBe([$release->id])
        ->and($release->isVisible())->toBeTrue();
});

it('keeps a release invisible until it is published and again once archived', function () {
    $release = publishedRelease();

    $release->forceFill(['published_at' => null])->save();
    expect($release->fresh()->isVisible())->toBeFalse();

    $release->forceFill(['published_at' => '2026-10-05 07:00:00', 'archived_at' => now()])->save();
    expect($release->fresh()->isVisible())->toBeFalse();
});

it('rejects a second item at an occupied position or for the same prayer', function () {
    $release = publishedRelease();

    expect(static fn () => PrayerReleaseItem::query()->create([
        'id' => (string) Str::uuid(),
        'release_id' => $release->id,
        'library_prayer_id' => releasePrayer()->id,
        'kind' => 'prayer',
        'sort_order' => 0,
        'content_sha256' => str_repeat('a', 64),
    ]))->toThrow(QueryException::class);

    expect(static fn () => PrayerReleaseItem::query()->create([
        'id' => (string) Str::uuid(),
        'release_id' => $release->id,
        'library_prayer_id' => $release->items->first()->library_prayer_id,
        'kind' => 'prayer',
        'sort_order' => 9,
        'content_sha256' => str_repeat('b', 64),
    ]))->toThrow(QueryException::class);
});

it('makes a repeated add idempotent through the unique account and release key', function () {
    $user = releaseUser();
    $release = publishedRelease();

    $download = releaseDownload($user, $release);

    expect(static fn () => releaseDownload($user, $release))
        ->toThrow(QueryException::class);

    expect(PrayerReleaseDownload::query()->where('user_id', $user->id)->count())->toBe(1)
        ->and($download->downloaded_at)->not->toBeNull();

    $other = releaseUser();
    releaseDownload($other, $release);

    expect(PrayerReleaseDownload::query()->count())->toBe(2)
        ->and($other->prayerReleaseDownloads->count())->toBe(1);
});

it('defaults the weekly preference to opted out and notices enabled', function () {
    $user = releaseUser();
    $preference = PrayerReleasePreference::query()->create([
        'user_id' => $user->id,
    ]);

    expect($preference->fresh()->weekly_enabled)->toBeFalse()
        ->and($preference->fresh()->notification_enabled)->toBeTrue()
        ->and($preference->fresh()->time_zone)->toBeNull()
        ->and($preference->receivesDelivery())->toBeFalse()
        ->and($user->prayerReleasePreference->is($preference))->toBeTrue();

    $preference->forceFill([
        'weekly_enabled' => true,
        'notification_enabled' => true,
        'time_zone' => 'Africa/Lagos',
    ])->save();

    expect($preference->fresh()->receivesDelivery())->toBeTrue();

    $preference->forceFill(['notification_enabled' => false])->save();
    expect($preference->fresh()->receivesDelivery())->toBeFalse();
});

it('removes preferences and downloads when the account is deleted', function () {
    $user = releaseUser();
    $release = publishedRelease();
    PrayerReleasePreference::query()->create([
        'user_id' => $user->id,
        'weekly_enabled' => true,
        'time_zone' => 'UTC',
    ]);
    releaseDownload($user, $release);

    $user->delete();

    expect(DB::table('prayer_release_preferences')->count())->toBe(0)
        ->and(DB::table('prayer_release_downloads')->count())->toBe(0)
        ->and(DB::table('prayer_releases')->count())->toBe(1);
});

it('preserves downloads and existing selections when a release is archived', function () {
    $user = releaseUser();
    $release = publishedRelease();
    $prayerId = $release->items->first()->library_prayer_id;
    $localDate = '2026-10-06';

    TodayPrayer::query()->create([
        'id' => (string) Str::uuid(),
        'user_id' => $user->id,
        'local_date' => $localDate,
        'prayer_id' => $prayerId,
        'include_action' => false,
        'action_completed' => false,
    ]);
    PrayerVote::query()->create([
        'id' => (string) Str::uuid(),
        'user_id' => $user->id,
        'prayer_id' => $prayerId,
        'created_at' => now(),
    ]);
    $download = releaseDownload($user, $release);

    $release->forceFill(['archived_at' => now()])->save();

    expect($release->fresh()->isVisible())->toBeFalse()
        ->and(PrayerReleaseDownload::query()->whereKey($download->id)->exists())->toBeTrue()
        ->and(TodayPrayer::query()->where('prayer_id', $prayerId)->exists())->toBeTrue()
        ->and(PrayerVote::query()->where('prayer_id', $prayerId)->exists())->toBeTrue()
        ->and(LibraryPrayer::query()->whereKey($prayerId)->exists())->toBeTrue();
});

it('keeps a download and its items when the release row itself would be deleted', function () {
    $user = releaseUser();
    $release = publishedRelease();
    releaseDownload($user, $release);

    expect(static fn () => DB::table('prayer_releases')->where('id', $release->id)->delete())
        ->toThrow(QueryException::class);

    expect(PrayerReleaseDownload::query()->count())->toBe(1);
});

it('records the repetition practice profile only where the source allows it', function () {
    $release = publishedRelease(itemCount: 1);
    $item = $release->items->first();

    expect($item->hasRepetitionPractice())->toBeFalse()
        ->and($item->narrationMatchesContent())->toBeFalse();

    $item->forceFill([
        'practice_mode' => 'affirmation_repetition',
        'practice_steps' => [
            ['phrase' => 'Dear Lord, renew my mind and heart', 'target_count' => 50, 'source_line' => 'Dear Lord, renew my mind and heart (x50)'],
        ],
    ])->save();
    expect($item->fresh()->hasRepetitionPractice())->toBeTrue();

    $item->forceFill(['narration_uri' => 'prayer-releases/audio/item-0.mp3'])->save();
    expect($item->fresh()->narrationMatchesContent())->toBeFalse();

    $item->forceFill(['narration_content_sha256' => $item->content_sha256])->save();
    expect($item->fresh()->narrationMatchesContent())->toBeTrue();
});
