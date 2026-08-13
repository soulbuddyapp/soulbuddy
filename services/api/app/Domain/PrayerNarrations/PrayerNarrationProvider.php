<?php

namespace App\Domain\PrayerNarrations;

interface PrayerNarrationProvider
{
    public function synthesize(string $text): PrayerNarrationAudio;
}
