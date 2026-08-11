<?php

namespace App\Domain\PrayerDrafts;

use RuntimeException;

final class PrayerDraftInvalidResponse extends RuntimeException
{
    public function __construct()
    {
        parent::__construct('Prayer draft provider returned an invalid response.');
    }
}
