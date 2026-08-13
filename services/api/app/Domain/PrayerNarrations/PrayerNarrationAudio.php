<?php

namespace App\Domain\PrayerNarrations;

final readonly class PrayerNarrationAudio
{
    public function __construct(
        public string $bytes,
        public string $contentType,
    ) {}
}
