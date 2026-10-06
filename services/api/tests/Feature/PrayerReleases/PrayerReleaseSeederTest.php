<?php

use App\Domain\PrayerReleases\PrayerReleasePublisher;
use App\Domain\PrayerReleases\ReleaseContent;
use App\Models\LibraryPrayer;
use App\Models\PrayerRelease;
use App\Models\PrayerReleaseItem;
use App\Models\PrayerVote;
use App\Models\User;
use Database\Seeders\PrayerReleaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

function seederReleaseContent(): ReleaseContent
{
    return ReleaseContent::fromJsonFile(
        dirname(__DIR__, 3).'/resources/prayer-releases/'.PrayerReleaseSeeder::SLUG.'.json',
    );
}

function seedRelease(?string $publishedAt = null): PrayerRelease
{
    app(PrayerReleasePublisher::class)->publish(seederReleaseContent(), $publishedAt);

    return PrayerRelease::query()->where('slug', PrayerReleaseSeeder::SLUG)->firstOrFail();
}

it('seeds one release with five canonical prayers in order', function () {
    $release = seedRelease();

    expect($release->id)->toBe(seederReleaseContent()->releaseId())
        ->and($release->title)->toBe('Renewed mind & guarded heart')
        ->and($release->items)->toHaveCount(5)
        ->and($release->items->pluck('sort_order')->all())->toBe([0, 1, 2, 3, 4])
        ->and($release->items->pluck('kind')->all())->toBe([
            'prayer',
            'meditation_prayer',
            'prayer',
            'meditation_prayer',
            'prayer',
        ])
        ->and($release->items->map(
            static fn ($item): ?string => $item->libraryPrayer?->title,
        )->all())->toBe([
            'Daily Prayer Against Temptations',
            'Brief Meditation',
            'Affirmative Prayer to resist occasions of Sin',
            'New Adam repetitions',
            'Daily Prayer to join our hearts to the heart of Jesus',
        ])
        ->and($release->items->pluck('library_prayer_id')->all())->toBe([
            seederReleaseContent()->libraryPrayerId(0),
            seederReleaseContent()->libraryPrayerId(1),
            seederReleaseContent()->libraryPrayerId(2),
            seederReleaseContent()->libraryPrayerId(3),
            seederReleaseContent()->libraryPrayerId(4),
        ])
        ->and($release->items->pluck('content_sha256')->all())->toBe(array_map(
            static fn ($item): string => hash('sha256', $item->title."\n".$item->body),
            seederReleaseContent()->items,
        ));
});

it('stores each seeded prayer in the canonical library without an invented action', function () {
    $release = seedRelease();

    foreach ($release->items as $item) {
        $prayer = LibraryPrayer::query()->whereKey($item->library_prayer_id)->firstOrFail();

        expect($prayer->title)->toBe($item->libraryPrayer->title)
            ->and($prayer->body)->toBe($item->libraryPrayer->body)
            ->and($prayer->action)->toBeNull()
            ->and($prayer->grounding)->toBe('general_christian')
            ->and($prayer->language_style)->toBe('christian')
            ->and($prayer->purpose)->toBe($item->libraryPrayer->purpose)
            ->and($prayer->published_at)->not->toBeNull()
            ->and($prayer->archived_at)->toBeNull();
    }

    expect(LibraryPrayer::query()->whereIn('id', $release->items->pluck('library_prayer_id'))->count())->toBe(5);
});

it('keeps the repetition practice profile on the fourth item only', function () {
    $release = seedRelease();

    expect($release->items[3]->hasRepetitionPractice())->toBeTrue()
        ->and($release->items[3]->practice_steps)->toBe([
            [
                'phrase' => 'Dear Lord, renew my mind and heart and make me a new Adam in Christ Jesus',
                'target_count' => 50,
                'source_line' => 'Dear Lord, renew my mind and heart and make me a new Adam in Christ Jesus (x50)',
            ],
            [
                'phrase' => 'In moments that distract me from your perfect will, let Satan be rebuked o Lord',
                'target_count' => 10,
                'source_line' => 'In moments that distract me from your perfect will, let Satan be rebuked o Lord (x10)',
            ],
        ])
        ->and($release->items->reject->hasRepetitionPractice())->toHaveCount(4);
});

it('publishes on an explicit date rather than the seeding moment', function () {
    $this->travelTo(now()->setDate(2027, 3, 4)->setTime(18, 30)->utc());

    $release = seedRelease();

    expect($release->published_at?->toDateTimeString())->toBe('2026-10-05 07:00:00');

    config()->set('prayer_releases.published_at', '2026-10-12 07:00:00');
    $this->seed(PrayerReleaseSeeder::class);
    expect($release->fresh()->published_at?->toDateTimeString())->toBe('2026-10-05 07:00:00');
});

it('never moves an existing publish date forward', function () {
    seedRelease('2026-10-19 07:00:00');
    $this->seed(PrayerReleaseSeeder::class);
    config()->set('prayer_releases.published_at', '2026-09-28 07:00:00');
    $this->seed(PrayerReleaseSeeder::class);

    expect(PrayerRelease::query()->where('slug', PrayerReleaseSeeder::SLUG)->firstOrFail()
        ->published_at?->toDateTimeString())->toBe('2026-09-28 07:00:00');
});

it('produces five links and no duplicates when the seeder runs twice', function () {
    seedRelease();
    $this->seed(PrayerReleaseSeeder::class);
    $this->seed(PrayerReleaseSeeder::class);

    expect(PrayerRelease::query()->count())->toBe(1)
        ->and(PrayerReleaseItem::query()->count())->toBe(5)
        ->and(PrayerReleaseItem::query()->distinct()->count('release_id'))->toBe(1)
        ->and(PrayerReleaseItem::query()->distinct()->count('library_prayer_id'))->toBe(5)
        ->and(LibraryPrayer::query()->count())->toBe(5);
});

it('leaves an existing helpful count untouched', function () {
    $release = seedRelease();
    $prayerId = $release->items->first()->library_prayer_id;

    // Each helpful vote needs its own account, and the count is maintained by triggers.
    for ($vote = 0; $vote < 3; $vote++) {
        PrayerVote::query()->create([
            'id' => (string) Str::uuid(),
            'user_id' => User::factory()->create()->id,
            'prayer_id' => $prayerId,
            'created_at' => now(),
        ]);
    }

    expect(LibraryPrayer::query()->whereKey($prayerId)->value('helpful_count'))->toBe(3);

    $this->seed(PrayerReleaseSeeder::class);

    expect(LibraryPrayer::query()->whereKey($prayerId)->value('helpful_count'))->toBe(3);
});

it('keeps an archived release archived across a reseed', function () {
    $release = seedRelease();
    $release->forceFill(['archived_at' => now()])->save();

    $this->seed(PrayerReleaseSeeder::class);

    expect($release->fresh()->archived_at)->not->toBeNull();
});

it('refuses a narration asset whose transcript is not this exact content', function () {
    $release = seedRelease();
    $content = seederReleaseContent();
    $publisher = app(PrayerReleasePublisher::class);

    expect(static fn () => $publisher->attachNarration($content, 3, 'prayer-releases/new-adam.mp3', str_repeat('0', 64)))
        ->toThrow(InvalidArgumentException::class);

    $item = $publisher->attachNarration($content, 3, 'prayer-releases/new-adam.mp3', $content->contentHash($content->items[3]->title, $content->items[3]->body));

    expect($item->narration_uri)->toBe('prayer-releases/new-adam.mp3')
        ->and($item->narrationMatchesContent())->toBeTrue()
        ->and($release->fresh()->items[3]->narrationMatchesContent())->toBeTrue();

    // A content revision drops the now-stale asset instead of speaking other words.
    $this->seed(PrayerReleaseSeeder::class);
    expect(PrayerReleaseItem::query()->whereKey($content->itemId(3))->firstOrFail()->narrationMatchesContent())->toBeTrue();
});
