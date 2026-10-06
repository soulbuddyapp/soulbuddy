<?php

namespace Database\Seeders;

use App\Domain\PrayerReleases\PrayerReleasePublisher;
use App\Domain\PrayerReleases\ReleaseContent;
use Illuminate\Database\Seeder;

class PrayerReleaseSeeder extends Seeder
{
    public const SLUG = 'renewed-mind-and-guarded-heart-v1';

    public function __construct(private readonly PrayerReleasePublisher $publisher)
    {
    }

    public function run(): void
    {
        // Only validated content may reach the database.
        $release = ReleaseContent::fromJsonFile(
            resource_path('prayer-releases/'.self::SLUG.'.json'),
        );

        $this->publisher->publish($release, config('prayer_releases.published_at'));
    }
}
