<?php

namespace App\Domain\Sync;

use App\Domain\PrayerReleases\AffirmationPrayerSessionShape;
use App\Domain\PrayerReleases\ReleaseContent;
use App\Models\AffirmationPrayerSession;
use App\Models\PrayerReleaseDownload;
use App\Models\PrayerReleaseItem;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Accepts an immutable terminal counted prayer session.
 *
 * The client may save progress locally, but only a terminal record reaches the
 * server. A forged completed record with incomplete counts, a session for an item
 * the person never added, and any attempt to rewrite a stored session are all
 * refused.
 */
class ApplyAffirmationPrayerSessionMutation
{
    public const TABLE = 'affirmation_prayer_sessions';

    private const KEYS = [
        'owner_id',
        'release_item_id',
        'local_date',
        'started_at',
        'ended_at',
        'outcome',
        'step_one_count',
        'step_two_count',
        'sound_key',
        'narration_speed',
    ];

    public static function supports(string $table): bool
    {
        return $table === self::TABLE;
    }

    /** @param Collection<int, array<string, mixed>> $operations */
    public function validate(User $user, Collection $operations): ?string
    {
        $shape = new AffirmationPrayerSessionShape;

        foreach ($operations as $operation) {
            if ($operation['type'] !== 'put') {
                return 'unsupported_operation';
            }

            $data = $operation['data'];
            if (array_diff(array_keys($data), self::KEYS) !== []) {
                return 'invalid_data';
            }
            foreach (['release_item_id', 'local_date', 'started_at', 'ended_at', 'outcome', 'step_one_count', 'step_two_count'] as $required) {
                if (! array_key_exists($required, $data) || $data[$required] === null) {
                    return 'invalid_data';
                }
            }
            if (
                ! is_string($data['release_item_id'])
                || ! is_string($data['local_date'])
                || ! is_string($data['started_at'])
                || ! is_string($data['ended_at'])
                || ! is_string($data['outcome'])
                || ! is_int($data['step_one_count'])
                || ! is_int($data['step_two_count'])
            ) {
                return 'invalid_data';
            }
            if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $data['local_date']) !== 1) {
                return 'invalid_data';
            }
            if (
                $data['sound_key'] !== null
                && (! is_string($data['sound_key']) || $data['sound_key'] === '')
            ) {
                return 'invalid_data';
            }
            if (
                $data['narration_speed'] !== null
                && (! is_string($data['narration_speed']) || ! $shape->isSpeed($data['narration_speed']))
            ) {
                return 'invalid_data';
            }

            $normalized = $shape->normalize(
                $data['outcome'],
                $data['step_one_count'],
                $data['step_two_count'],
            );
            if ($normalized === null) {
                return 'invalid_data';
            }

            $startedAt = $this->parseDate($data['started_at']);
            $endedAt = $this->parseDate($data['ended_at']);
            if ($startedAt === null || $endedAt === null || $endedAt->lt($startedAt)) {
                return 'invalid_data';
            }

            $stored = AffirmationPrayerSession::query()->whereKey($operation['id'])->first();
            if ($stored !== null) {
                // A terminal record is never rewritten.
                return $stored->user_id === $user->id ? 'immutable_session' : 'forbidden';
            }
        }

        $itemIds = $operations
            ->map(fn (array $operation): string => $operation['data']['release_item_id'])
            ->unique()
            ->sort()
            ->values();

        $items = PrayerReleaseItem::query()
            ->whereIn('id', $itemIds)
            ->get()
            ->keyBy('id');
        if ($items->count() !== $itemIds->count()) {
            return 'missing_record';
        }

        foreach ($operations as $operation) {
            $item = $items->get($operation['data']['release_item_id']);
            if (! $item->hasRepetitionPractice()) {
                return 'inaccessible_record';
            }

            // The profile must still rebuild its own source lines.
            $practice = $item->practice_mode === ReleaseContent::PRACTICE_MODE_AFFIRMATION_REPETITION
                ? $item->practice_steps
                : null;
            if (! is_array($practice) || ! $this->profileRebuilds($practice)) {
                return 'invalid_data';
            }

            $added = PrayerReleaseDownload::query()
                ->where('user_id', $user->id)
                ->where('release_id', $item->release_id)
                ->exists();
            if (! $added) {
                return 'inaccessible_record';
            }
        }

        return null;
    }

    /** @param Collection<int, array<string, mixed>> $operations */
    public function apply(User $user, Collection $operations): ?string
    {
        foreach ($operations as $operation) {
            $data = $operation['data'];

            $existing = AffirmationPrayerSession::query()
                ->whereKey($operation['id'])
                ->lockForUpdate()
                ->first();
            if ($existing !== null) {
                // A replayed operation is accepted only when it is the same record.
                if ($existing->matchesPayload($data)) {
                    continue;
                }

                return 'conflict';
            }

            AffirmationPrayerSession::query()->create([
                'id' => $operation['id'],
                'user_id' => $user->id,
                'release_item_id' => $data['release_item_id'],
                'local_date' => $data['local_date'],
                'started_at' => $data['started_at'],
                'ended_at' => $data['ended_at'],
                'outcome' => $data['outcome'],
                'step_one_count' => $data['step_one_count'],
                'step_two_count' => $data['step_two_count'],
                'sound_key' => $data['sound_key'] ?? null,
                'narration_speed' => $data['narration_speed'] ?? null,
            ]);
        }

        return null;
    }

    /**
     * @param  array<int, mixed>  $steps
     */
    private function profileRebuilds(array $steps): bool
    {
        if ($steps === []) {
            return false;
        }

        foreach ($steps as $step) {
            if (! is_array($step) || ! isset($step['phrase'], $step['target_count'], $step['source_line'])) {
                return false;
            }
            $expected = $step['phrase'].' (x'.(int) $step['target_count'].')';
            if (! is_string($step['source_line']) || ! hash_equals($expected, $step['source_line'])) {
                return false;
            }
        }

        return true;
    }

    private function parseDate(string $value): ?Carbon
    {
        try {
            return Carbon::parse($value);
        } catch (\Throwable) {
            return null;
        }
    }

    /**
     * Used by the caller inside an existing transaction.
     */
    public function lockAccount(User $user): void
    {
        User::query()->whereKey($user->id)->lockForUpdate()->firstOrFail();
    }

    /** Exposed for the composite engine's transaction ordering. */
    public function table(): string
    {
        return self::TABLE;
    }

    /** @return array<int, string> */
    public static function tables(): array
    {
        return [self::TABLE];
    }

    public static function withinTransaction(): bool
    {
        return DB::transactionLevel() > 0;
    }
}
