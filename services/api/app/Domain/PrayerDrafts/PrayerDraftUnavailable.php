<?php

namespace App\Domain\PrayerDrafts;

use RuntimeException;

final class PrayerDraftUnavailable extends RuntimeException
{
    public function __construct()
    {
        parent::__construct('Prayer draft provider unavailable.');
    }
}
