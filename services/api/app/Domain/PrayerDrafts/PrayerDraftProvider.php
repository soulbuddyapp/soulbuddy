<?php

namespace App\Domain\PrayerDrafts;

interface PrayerDraftProvider
{
    /** @param null|list<string> $repairCodes */
    public function generate(PrayerDraftInput $input, ?array $repairCodes): PrayerDraftResult;
}
