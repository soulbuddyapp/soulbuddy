<?php

namespace App\Console\Commands;

use App\Domain\Notifications\FirebasePushSender;
use App\Domain\Notifications\UnregisteredPushToken;
use App\Models\AppInstallation;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Log;
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
        $invalidTokensRemoved = 0;
        AppInstallation::query()
            ->whereNotNull('push_token')
            ->whereNotNull('time_zone')
            ->orderBy('id')
            ->chunkById(200, function ($installations) use ($now, $sender, &$sent, &$failed, &$invalidTokensRemoved): void {
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
                    } catch (UnregisteredPushToken) {
                        // A token refresh can race the FCM response; only clear the rejected token.
                        $invalidTokensRemoved += AppInstallation::whereKey($installation->id)
                            ->where('push_token', $installation->push_token)
                            ->update(['push_token' => null]);
                        $failed++;
                    } catch (Throwable $exception) {
                        // HTTP exception messages can contain credentials or the request body.
                        Log::warning('Morning notification delivery failed.', [
                            'exception_type' => $exception::class,
                        ]);
                        $failed++;
                    }
                }
            });

        if ($sent > 0 || $failed > 0) {
            Log::info('Morning notification delivery summary.', [
                'accepted' => $sent,
                'failed' => $failed,
                'invalid_tokens_removed' => $invalidTokensRemoved,
            ]);
        }
        $this->components->info("Morning notifications: {$sent} accepted, {$failed} failed, {$invalidTokensRemoved} invalid tokens removed.");

        return $failed === 0 ? self::SUCCESS : self::FAILURE;
    }
}
