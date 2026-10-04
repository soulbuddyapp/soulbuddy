<?php

namespace App\Domain\Companions;

use App\Domain\Scripture\DailyScripture;
use App\Models\AppInstallation;
use Carbon\CarbonImmutable;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

final class TelegramCompanionService
{
    public function __construct(
        private readonly TelegramBotSender $sender,
        private readonly DailyScripture $scriptures,
    ) {}

    /**
     * @return array{sent: int, failed: int}
     */
    public function sendDue(?CarbonImmutable $now = null): array
    {
        $now ??= now()->utc()->toImmutable();
        $sent = 0;
        $failed = 0;

        DB::table('telegram_connections')
            ->where('daily_enabled', true)
            ->orderBy('id')
            ->chunk(100, function (Collection $connections) use ($now, &$sent, &$failed): void {
                foreach ($connections as $connection) {
                    $local = $now->setTimezone($this->timeZoneFor($connection));
                    foreach ($this->dueDeliveries($connection, $local) as $delivery) {
                        if ($this->wasDelivered($connection->id, $delivery['occurrence_key'])) {
                            continue;
                        }
                        if (! $delivery['send']()) {
                            $failed++;

                            continue;
                        }
                        $this->recordDelivery($connection->id, $delivery['kind'], $delivery['occurrence_key'], $now);
                        $sent++;
                    }
                }
            });

        return compact('sent', 'failed');
    }

    public function recordFormationActivity(int $userId, string $videoId, string $source, string $activityType = 'completed'): void
    {
        DB::table('formation_activity_events')->insert([
            'id' => (string) Str::uuid(),
            'user_id' => $userId,
            'formation_video_id' => $videoId,
            'activity_type' => $activityType,
            'source' => $source,
            'occurred_at' => now(),
            'created_at' => now(),
        ]);
    }

    public function recordTelegramFormationActivity(string $chatId, string $videoId): bool
    {
        $connection = DB::table('telegram_connections')->where('chat_id', $chatId)->first();
        if ($connection === null) {
            return false;
        }

        $this->recordFormationActivity((int) $connection->user_id, $videoId, 'telegram');

        return true;
    }

    public function setPreference(string $chatId, string $preference, bool $enabled): bool
    {
        $column = match ($preference) {
            'all' => 'daily_enabled',
            'scripture' => 'daily_enabled',
            'formation' => 'formation_enabled',
            'prayers' => 'prayer_enabled',
            'sacred' => 'sacred_hour_enabled',
            'care' => 'care_enabled',
            default => null,
        };
        if ($column === null) {
            return false;
        }

        return DB::table('telegram_connections')
            ->where('chat_id', $chatId)
            ->update([$column => $enabled, 'updated_at' => now()]) === 1;
    }

    public function isConnected(string $chatId): bool
    {
        return DB::table('telegram_connections')->where('chat_id', $chatId)->exists();
    }

    /**
     * @return array<int, array{kind: string, occurrence_key: string, send: \Closure(): bool}>
     */
    private function dueDeliveries(object $connection, CarbonImmutable $local): array
    {
        $deliveries = [];
        if ($local->hour > 5 || ($local->hour === 5 && $local->minute >= 30)) {
            $date = $local->toDateString();
            $deliveries[] = [
                'kind' => 'daily_scripture',
                'occurrence_key' => "scripture:{$date}",
                'send' => fn (): bool => $this->sender->sendDailyScripture(
                    (string) $connection->chat_id,
                    $this->scriptures->forDate($date),
                ),
            ];
        }
        if ((bool) $connection->formation_enabled
            && ($local->hour > 7 || ($local->hour === 7 && $local->minute >= 0))) {
            $formation = $this->formationFor($connection->id);
            if ($formation !== null) {
                $date = $local->toDateString();
                $deliveries[] = [
                    'kind' => 'daily_formation',
                    'occurrence_key' => "formation:{$date}",
                    'send' => fn (): bool => $this->sender->sendFormationVideo((string) $connection->chat_id, $formation),
                ];
            }
        }
        if ((bool) $connection->prayer_enabled) {
            foreach ($this->duePrayerReminders((int) $connection->user_id, $local) as $reminder) {
                $deliveries[] = [
                    'kind' => 'prayer_reminder',
                    'occurrence_key' => "prayer:{$reminder->id}:".$local->toDateString(),
                    'send' => fn (): bool => $this->sender->sendPrayerReminder(
                        (string) $connection->chat_id,
                        (string) $reminder->title,
                    ),
                ];
            }
        }
        if ((bool) $connection->sacred_hour_enabled) {
            foreach ($this->dueSacredHours((int) $connection->user_id, $local) as $hour) {
                $deliveries[] = [
                    'kind' => 'sacred_hour',
                    'occurrence_key' => "sacred:{$hour->id}:".$local->toDateString(),
                    'send' => fn (): bool => $this->sender->sendSacredHour(
                        (string) $connection->chat_id,
                        (string) $hour->name,
                    ),
                ];
            }
        }
        if ((bool) $connection->care_enabled && $local->hour >= 8) {
            foreach ($this->unattendedPeople((int) $connection->user_id, $local) as $person) {
                $anchor = $person->last_prayed_at ?? $person->created_at;
                $deliveries[] = [
                    'kind' => 'weekly_person_prayer',
                    'occurrence_key' => "person:{$person->id}:{$anchor}",
                    'send' => fn (): bool => $this->sender->sendWeeklyPersonPrayer(
                        (string) $connection->chat_id,
                        (string) $person->name,
                    ),
                ];
            }
            if ($anchor = $this->formationAttentionAnchor($connection, $local)) {
                $deliveries[] = [
                    'kind' => 'weekly_formation',
                    'occurrence_key' => "formation-return:{$anchor}",
                    'send' => fn (): bool => $this->sender->sendWeeklyFormationReturn((string) $connection->chat_id),
                ];
            }
        }

        return $deliveries;
    }

    private function timeZoneFor(object $connection): string
    {
        $zone = AppInstallation::query()
            ->where('user_id', $connection->user_id)
            ->whereNotNull('time_zone')
            ->latest('updated_at')
            ->value('time_zone');

        return is_string($zone) && in_array($zone, timezone_identifiers_list(), true)
            ? $zone
            : config('app.timezone', 'UTC');
    }

    private function wasDelivered(string $connectionId, string $occurrenceKey): bool
    {
        return DB::table('telegram_companion_deliveries')
            ->where('telegram_connection_id', $connectionId)
            ->where('occurrence_key', $occurrenceKey)
            ->exists();
    }

    private function recordDelivery(string $connectionId, string $kind, string $occurrenceKey, CarbonImmutable $now): void
    {
        DB::table('telegram_companion_deliveries')->insert([
            'id' => (string) Str::uuid(),
            'telegram_connection_id' => $connectionId,
            'kind' => $kind,
            'occurrence_key' => $occurrenceKey,
            'delivered_at' => $now,
            'created_at' => $now,
        ]);
    }

    private function formationFor(string $connectionId): ?object
    {
        $version = DB::table('formation_catalog_versions')->where('published', true)->first();
        if ($version === null) {
            return null;
        }
        $sent = DB::table('telegram_companion_deliveries')
            ->where('telegram_connection_id', $connectionId)
            ->where('kind', 'daily_formation')
            ->count();
        $day = DB::table('formation_days')
            ->where('catalog_version_id', $version->id)
            ->orderBy('canonical_day')
            ->skip($sent)
            ->first();
        if ($day === null) {
            $day = DB::table('formation_days')
                ->where('catalog_version_id', $version->id)
                ->orderBy('canonical_day')
                ->first();
        }
        if ($day === null) {
            return null;
        }
        $ids = json_decode($day->video_ids, true);
        if (! is_array($ids) || $ids === []) {
            return null;
        }

        return DB::table('formation_videos')
            ->where('catalog_version_id', $version->id)
            ->where('stable_id', $ids[0])
            ->first();
    }

    /** @return Collection<int, object> */
    private function duePrayerReminders(int $userId, CarbonImmutable $local): Collection
    {
        return DB::table('prayer_reminders')
            ->join('personal_prayers', 'personal_prayers.id', '=', 'prayer_reminders.personal_prayer_id')
            ->where('prayer_reminders.user_id', $userId)
            ->where('prayer_reminders.enabled', true)
            ->whereNull('prayer_reminders.archived_at')
            ->whereNull('personal_prayers.archived_at')
            ->where('prayer_reminders.local_time', '<=', $local->format('H:i'))
            ->where(function ($query) use ($local): void {
                $query->where('prayer_reminders.schedule_type', 'daily')
                    ->orWhere(function ($once) use ($local): void {
                        $once->where('prayer_reminders.schedule_type', 'once')
                            ->whereDate('prayer_reminders.once_at', $local->toDateString());
                    })
                    ->orWhere(function ($weekdays) use ($local): void {
                        $mask = 1 << ($local->dayOfWeekIso - 1);
                        $weekdays->where('prayer_reminders.schedule_type', 'weekdays')
                            ->whereRaw('(prayer_reminders.weekdays_mask & ?) != 0', [$mask]);
                    });
            })
            ->select('prayer_reminders.id', 'personal_prayers.title')
            ->get();
    }

    /** @return Collection<int, object> */
    private function dueSacredHours(int $userId, CarbonImmutable $local): Collection
    {
        return DB::table('sacred_hours')
            ->where('user_id', $userId)
            ->where('enabled', true)
            ->whereNull('archived_at')
            ->where('local_time', '<=', $local->format('H:i'))
            ->select('id', 'name')
            ->get();
    }

    /** @return Collection<int, object> */
    private function unattendedPeople(int $userId, CarbonImmutable $local): Collection
    {
        $cutoff = $local->subDays(7)->utc();

        return DB::table('prayer_people')
            ->where('user_id', $userId)
            ->whereNull('archived_at')
            ->where('created_at', '<=', $cutoff)
            ->whereNotExists(function ($query) use ($userId, $cutoff): void {
                $query->selectRaw('1')
                    ->from('person_prayer_occurrences')
                    ->whereColumn('person_prayer_occurrences.person_id', 'prayer_people.id')
                    ->where('person_prayer_occurrences.user_id', $userId)
                    ->where('person_prayer_occurrences.prayed_at', '>=', $cutoff);
            })
            ->select('id', 'name', 'created_at')
            ->selectSub(
                DB::table('person_prayer_occurrences')
                    ->selectRaw('MAX(prayed_at)')
                    ->whereColumn('person_prayer_occurrences.person_id', 'prayer_people.id')
                    ->where('person_prayer_occurrences.user_id', $userId),
                'last_prayed_at',
            )
            ->get();
    }

    private function formationAttentionAnchor(object $connection, CarbonImmutable $local): ?string
    {
        $latest = DB::table('formation_activity_events')
            ->where('user_id', $connection->user_id)
            ->max('occurred_at');
        $anchor = $latest ?? $connection->created_at;
        if (CarbonImmutable::parse($anchor)->greaterThan($local->subDays(7)->utc())) {
            return null;
        }

        return CarbonImmutable::parse($anchor)->utc()->toIso8601String();
    }
}
