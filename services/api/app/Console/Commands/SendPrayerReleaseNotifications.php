<?php

namespace App\Console\Commands;

use App\Domain\PrayerReleases\PrayerReleaseDeliveryService;
use Illuminate\Console\Command;

class SendPrayerReleaseNotifications extends Command
{
    protected $signature = 'prayer-releases:notify';

    protected $description = 'Send each opted-in person one weekly prayer release notice in their own time zone';

    public function handle(PrayerReleaseDeliveryService $delivery): int
    {
        $result = $delivery->sendDue();

        $this->components->info(
            "Prayer release notices: {$result['sent']} accepted, {$result['failed']} failed, "
            ."{$result['invalid_tokens_removed']} invalid tokens removed.",
        );

        return $result['failed'] === 0 ? self::SUCCESS : self::FAILURE;
    }
}
