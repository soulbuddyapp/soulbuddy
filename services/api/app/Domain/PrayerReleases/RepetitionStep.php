<?php

namespace App\Domain\PrayerReleases;

final readonly class RepetitionStep
{
    public function __construct(
        public string $phrase,
        public int $targetCount,
        public string $sourceLine,
    ) {}

    /**
     * The paced repetition text is the source line without its count suffix.
     */
    public static function sourceLineFor(string $phrase, int $targetCount): string
    {
        return $phrase." (x{$targetCount})";
    }
}
