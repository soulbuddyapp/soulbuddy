<?php

namespace App\Domain\PrayerReleases;

use App\Domain\Companions\TelegramBotSender;
use App\Domain\Notifications\FirebasePushSender;
use App\Domain\Notifications\UnregisteredPushToken;
use App\Models\AppInstallation;
use App\Models\PrayerRelease;
use Illuminate\Database\QueryException;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Throwable;

/**
 * Sends the one weekly notice a release is allowed per person.
 *
 * Delivery is opt-in, timezone-aware, and recorded only after a channel accepts
 * it, so a retry can never produce a second notice. Notification copy never
 * names the subject matter of a prayer collection.
 */
class PrayerReleaseDeliveryService
{
    public const CHANNEL_FCM = 'fcm';

    public const CHANNEL_TELEGRAM = 'telegram';

    public const FCM_CHANNEL_ID = 'soulbuddy_weekly_prayers_v1';

    public const FCM_TAG_PREFIX = 'soulbuddy-weekly-prayers-';

    public const NOTICE_TITLE = 'A new prayer collection is ready';

    private const RELEASE_KIND = 'weekly_prayer';

    public function __construct(
        private readonly FirebasePushSender $push,
        private readonly TelegramBotSender $telegram,
    ) {
    }

    /**
     * @return array{sent: int, failed: int, invalid_tokens_removed: int}
     */
    public function sendDue(?Carbon $now = null): array
    {
        $now ??= now()->utc();
        $sent = 0;
        $failed = 0;
        $invalidTokensRemoved = 0;

        foreach ($this->deliverableReleases($now) as $release) {
            foreach ($this->optedInPeople() as $userId => $timeZone) {
                if (! $this->isDueIn($release, $now, $timeZone)) {
                    continue;
                }

                $result = $this->deliverToPerson($release, (int) $userId);
                $sent += $result['sent'];
                $failed += $result['failed'];
                $invalidTokensRemoved += $result['invalid_tokens_removed'];
            }
        }

        if ($sent > 0 || $failed > 0) {
            Log::info('Prayer release delivery summary.', [
                'accepted' => $sent,
                'failed' => $failed,
                'invalid_tokens_removed' => $invalidTokensRemoved,
            ]);
        }

        return [
            'sent' => $sent,
            'failed' => $failed,
            'invalid_tokens_removed' => $invalidTokensRemoved,
        ];
    }

    /**
     * @return Collection<int, PrayerRelease>
     */
    private function deliverableReleases(Carbon $now): Collection
    {
        return PrayerRelease::query()
            ->whereNotNull('published_at')
            ->whereNull('archived_at')
            ->orderBy('id')
            ->get()
            ->filter(fn (PrayerRelease $release): bool => $this->isPublished($release, $now))
            ->values();
    }

    private function isPublished(PrayerRelease $release, Carbon $now): bool
    {
        return $release->published_at !== null
            && ! $release->published_at->copy()->utc()->greaterThan($now);
    }

    /**
     * Only an explicit opt-in with a usable IANA time zone can receive a notice.
     *
     * @return array<int, string>
     */
    private function optedInPeople(): array
    {
        return DB::table('prayer_release_preferences')
            ->where('weekly_enabled', true)
            ->where('notification_enabled', true)
            ->whereNotNull('time_zone')
            ->orderBy('user_id')
            ->pluck('time_zone', 'user_id')
            ->filter(
                static fn ($timeZone): bool => is_string($timeZone)
                    && in_array($timeZone, timezone_identifiers_list(), true),
            )
            ->all();
    }

    /**
     * Monday 07:00 in the person's own time zone, on or after the release's own
     * week. An earlier week is never backfilled.
     */
    private function isDueIn(PrayerRelease $release, Carbon $now, string $timeZone): bool
    {
        $published = $release->published_at->copy()->utc();

        // The release week is chosen in UTC so the Monday is the same date for
        // everyone, then that Monday's 07:00 is read in this person's own zone.
        $publishedDate = $published->dayOfWeek === Carbon::SUNDAY
            ? $published->copy()->addDay()
            : $published;
        $monday = $publishedDate->startOfWeek(Carbon::MONDAY);
        $weeklyDelivery = Carbon::parse(
            $monday->toDateString().' 07:00:00',
            $timeZone,
        );

        // The notice waits for whichever comes last: the release's Monday 07:00
        // here, or its own publication. Nothing is ever backfilled.
        $firstDelivery = $weeklyDelivery->greaterThan($published)
            ? $weeklyDelivery
            : $published;

        return $now->copy()->utc()->greaterThanOrEqualTo($firstDelivery);
    }

    /**
     * @return array{sent: int, failed: int, invalid_tokens_removed: int}
     */
    private function deliverToPerson(PrayerRelease $release, int $userId): array
    {
        $sent = 0;
        $failed = 0;
        $invalidTokensRemoved = 0;

        if (! $this->alreadyDelivered($release, $userId, self::CHANNEL_FCM)) {
            foreach ($this->pushInstallations($userId) as $installation) {
                $outcome = $this->deliverToInstallation($release, $installation);
                $sent += $outcome['sent'];
                $failed += $outcome['failed'];
                $invalidTokensRemoved += $outcome['invalid_tokens_removed'];

                if ($outcome['sent'] > 0) {
                    // The account has been notified; sibling installations skip.
                    break;
                }
            }
        }

        if (! $this->alreadyDelivered($release, $userId, self::CHANNEL_TELEGRAM)) {
            foreach ($this->telegramConnections($userId) as $connection) {
                if ($this->deliverToTelegram($release, $connection)) {
                    $sent++;
                    break;
                }
            }
        }

        return ['sent' => $sent, 'failed' => $failed, 'invalid_tokens_removed' => $invalidTokensRemoved];
    }

    /**
     * @return Collection<int, AppInstallation>
     */
    private function pushInstallations(int $userId): Collection
    {
        return AppInstallation::query()
            ->where('user_id', $userId)
            ->whereNotNull('push_token')
            ->orderBy('id')
            ->get();
    }

    /**
     * @return Collection<int, object>
     */
    private function telegramConnections(int $userId): Collection
    {
        return DB::table('telegram_connections')
            ->where('user_id', $userId)
            ->where('daily_enabled', true)
            ->orderBy('id')
            ->get();
    }

    /**
     * @return array{sent: int, failed: int, invalid_tokens_removed: int}
     */
    private function deliverToInstallation(PrayerRelease $release, AppInstallation $installation): array
    {
        try {
            $accepted = $this->push->sendNotice((string) $installation->push_token, $this->notice($release));
        } catch (UnregisteredPushToken) {
            // Only the rejected token is cleared, and nothing is recorded as sent.
            $removed = AppInstallation::query()
                ->whereKey($installation->id)
                ->where('push_token', $installation->push_token)
                ->update(['push_token' => null]);

            return ['sent' => 0, 'failed' => 1, 'invalid_tokens_removed' => $removed];
        } catch (Throwable $exception) {
            // HTTP exception messages can carry credentials or the request body.
            Log::warning('Prayer release notification delivery failed.', [
                'kind' => self::RELEASE_KIND,
                'exception_type' => $exception::class,
            ]);

            return ['sent' => 0, 'failed' => 1, 'invalid_tokens_removed' => 0];
        }

        if (! $accepted) {
            return ['sent' => 0, 'failed' => 1, 'invalid_tokens_removed' => 0];
        }

        // Recorded only after acceptance, so a retry cannot duplicate the notice.
        $this->record($release, (int) $installation->user_id, self::CHANNEL_FCM, [
            'app_installation_id' => $installation->id,
        ]);

        return ['sent' => 1, 'failed' => 0, 'invalid_tokens_removed' => 0];
    }

    private function deliverToTelegram(PrayerRelease $release, object $connection): bool
    {
        if (! $this->telegram->sendWeeklyPrayerRelease(
            $connection->chat_id,
            $release->title,
            $release->slug,
        )) {
            return false;
        }

        $this->record($release, (int) $connection->user_id, self::CHANNEL_TELEGRAM, [
            'telegram_connection_id' => $connection->id,
        ]);

        return true;
    }

    /**
     * @return array{title: string, body: string, route: string, kind: string, channel_id: string, tag: string}
     */
    private function notice(PrayerRelease $release): array
    {
        return [
            'title' => self::NOTICE_TITLE,
            // The collection title alone; no subject matter reaches the notice.
            'body' => $release->title,
            'route' => '/prayers/releases/'.$release->slug,
            'kind' => self::RELEASE_KIND,
            'channel_id' => self::FCM_CHANNEL_ID,
            'tag' => self::FCM_TAG_PREFIX.$release->slug,
        ];
    }

    private function alreadyDelivered(PrayerRelease $release, int $userId, string $channel): bool
    {
        return DB::table('prayer_release_deliveries')
            ->where('release_id', $release->id)
            ->where('user_id', $userId)
            ->where('channel', $channel)
            ->exists();
    }

    /**
     * @param  array<string, mixed>  $attribution
     */
    private function record(PrayerRelease $release, int $userId, string $channel, array $attribution): void
    {
        try {
            DB::table('prayer_release_deliveries')->insert([
                'id' => (string) Str::uuid(),
                'release_id' => $release->id,
                'user_id' => $userId,
                'channel' => $channel,
                'app_installation_id' => $attribution['app_installation_id'] ?? null,
                'telegram_connection_id' => $attribution['telegram_connection_id'] ?? null,
                'delivered_at' => now(),
                'created_at' => now(),
            ]);
        } catch (QueryException $exception) {
            if (! str_starts_with((string) ($exception->errorInfo[0] ?? $exception->getCode()), '23')) {
                throw $exception;
            }

            // A concurrent run already recorded the same single notice.
        }
    }
}
