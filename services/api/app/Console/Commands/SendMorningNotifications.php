<?php

namespace App\Console\Commands;

use App\Domain\Notifications\FirebasePushSender;
use App\Models\AppInstallation;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Throwable;

class SendMorningNotifications extends Command
{
    protected $signature = 'morning-notifications:send';

    protected $description = 'Send the daily 5:30 a.m. notification in each installation’s local time';

    public function handle(FirebasePushSender $sender): int
    {
        $now = now()->utc();
        $sent = 0;
        $failed = 0;
        AppInstallation::query()
            ->whereNotNull('push_token')
            ->whereNotNull('time_zone')
            ->orderBy('id')
            ->chunk(200, function ($installations) use ($now, $sender, &$sent, &$failed): void {
                foreach ($installations as $installation) {
                    try {
                        $local = $now->copy()->setTimezone($installation->time_zone);
                        if ($local->hour < 5 || ($local->hour === 5 && $local->minute < 30)) {
                            continue;
                        }
                        $date = $local->toDateString();
                        if ($installation->last_morning_sent_on?->toDateString() === $date) {
                            continue;
                        }
                        if (! $sender->sendMorning($installation->push_token)) {
                            $failed++;

                            continue;
                        }
                        $installation->forceFill(['last_morning_sent_on' => Carbon::parse($date)])->save();
                        $sent++;
                    } catch (Throwable $exception) {
                        report($exception);
                        $failed++;
                    }
                }
            });

        $this->components->info("Morning notifications: {$sent} sent, {$failed} failed.");

        return $failed === 0 ? self::SUCCESS : self::FAILURE;
    }
}
