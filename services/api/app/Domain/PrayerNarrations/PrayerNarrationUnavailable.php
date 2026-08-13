<?php

namespace App\Domain\PrayerNarrations;

use RuntimeException;

final class PrayerNarrationUnavailable extends RuntimeException
{
    public function __construct()
    {
        parent::__construct('Prayer narration unavailable.');
    }
}
