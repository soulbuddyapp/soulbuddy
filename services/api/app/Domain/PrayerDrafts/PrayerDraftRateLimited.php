<?php

namespace App\Domain\PrayerDrafts;

use RuntimeException;

final class PrayerDraftRateLimited extends RuntimeException
{
    public function __construct(public readonly ?int $retryAfter = null)
    {
        parent::__construct('Prayer draft provider rate limited.');
    }
}
