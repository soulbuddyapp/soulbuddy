<?php

namespace Database\Seeders;

use App\Domain\PrayerReleases\PrayerReleasePublisher;
use App\Domain\PrayerReleases\ReleaseContent;
use Illuminate\Database\Seeder;

class PrayerReleaseSeeder extends Seeder
{
    public const SLUG = 'renewed-mind-and-guarded-heart-v1';

    public const HOLY_SPIRIT_SLUG = 'holy-spirit-and-gifts-v1';

    public function __construct(private readonly PrayerReleasePublisher $publisher) {}

    public function run(): void
    {
        // Only validated content may reach the database.
        foreach ([
            [self::SLUG, config('prayer_releases.published_at')],
            [self::HOLY_SPIRIT_SLUG, config('prayer_releases.holy_spirit_published_at')],
        ] as [$slug, $publishedAt]) {
            $release = ReleaseContent::fromJsonFile(
                resource_path('prayer-releases/'.$slug.'.json'),
            );
            $this->publisher->publish($release, $publishedAt);
        }
    }
}
