<?php

namespace App\Domain\Sync;

use App\Models\PersonalPrayer;
use App\Models\PersonalPrayerRevision;
use App\Models\PrayerReminder;
use App\Models\PrayerSession;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Validator;

final class ApplyPrayerPracticeMutation
{
    private const TABLES = ['prayer_reminders', 'prayer_sessions'];

    public static function supports(string $table): bool
    {
        return in_array($table, self::TABLES, true);
    }

    /** @param Collection<int, array<string, mixed>> $operations */
    public function validate(User $user, Collection $operations): ?string
    {
        foreach ($operations as $operation) {
            $kindError = $this->validateKind($operation);
            if ($kindError !== null) {
                return $kindError;
            }
            $dataError = $this->validateData($operation);
            if ($dataError !== null) {
                return $dataError;
            }
        }

        foreach ($operations as $operation) {
            $targetError = $this->validateTarget($user, $operation);
            if ($targetError !== null) {
                return $targetError;
            }
        }

        return null;
    }

    /** @param Collection<int, array<string, mixed>> $operations */
    public function apply(User $user, Collection $operations): ?string
    {
        $prayerIds = $operations
            ->map(fn (array $operation): ?string => $operation['data']['personal_prayer_id'] ?? null)
            ->filter()
            ->unique()
            ->sort()
            ->values();
        $prayers = PersonalPrayer::query()
            ->whereIn('id', $prayerIds)
            ->orderBy('id')
            ->lockForUpdate()
            ->get()
            ->keyBy('id');
        foreach ($prayers as $prayer) {
            if ($prayer->user_id !== $user->id || $prayer->archived_at !== null) {
                return 'inaccessible_record';
            }
        }

        $reminderIds = $operations
            ->flatMap(function (array $operation): array {
                $ids = [];
                if ($operation['table'] === 'prayer_reminders') {
                    $ids[] = $operation['id'];
                }
                if (($operation['data']['reminder_id'] ?? null) !== null) {
                    $ids[] = $operation['data']['reminder_id'];
                }

                return $ids;
            })
            ->unique()
            ->sort()
            ->values();
        $reminders = PrayerReminder::query()
            ->whereIn('id', $reminderIds)
            ->orderBy('id')
            ->lockForUpdate()
            ->get()
            ->keyBy('id');
        foreach ($reminders as $reminder) {
            if ($reminder->user_id !== $user->id) {
                return 'inaccessible_record';
            }
        }

        $sessionIds = $operations
            ->where('table', 'prayer_sessions')
            ->pluck('id')
            ->unique()
            ->sort()
            ->values();
        $sessions = PrayerSession::query()
            ->whereIn('id', $sessionIds)
            ->orderBy('id')
            ->lockForUpdate()
            ->get()
            ->keyBy('id');
        foreach ($sessions as $session) {
            if ($session->user_id !== $user->id) {
                return 'inaccessible_record';
            }
        }

        foreach ($operations as $operation) {
            if ($operation['table'] === 'prayer_reminders') {
                $error = $this->applyReminder($user, $operation, $reminders);
            } else {
                $error = $this->applySession($user, $operation, $sessions);
            }
            if ($error !== null) {
                return $error;
            }
        }

        return null;
    }

    private function validateKind(array $operation): ?string
    {
        if ($operation['table'] === 'prayer_reminders'
            && ! in_array($operation['type'], ['put', 'patch', 'delete'], true)) {
            return 'unsupported_operation';
        }
        if ($operation['table'] === 'prayer_sessions') {
            if ($operation['type'] === 'delete') {
                return 'immutable_session';
            }
            if (! in_array($operation['type'], ['put', 'patch'], true)) {
                return 'unsupported_operation';
            }
            if ($operation['type'] === 'patch'
                && array_keys($operation['data']) !== ['retracted_at']) {
                return 'immutable_session';
            }
        }

        return null;
    }

    private function validateData(array $operation): ?string
    {
        if ($operation['type'] === 'delete') {
            return $operation['data'] === [] ? null : 'invalid_data';
        }

        $rules = match ([$operation['table'], $operation['type']]) {
            ['prayer_reminders', 'put'] => [
                'owner_id' => [],
                'personal_prayer_id' => ['required', 'uuid'],
                'schedule_type' => ['required', 'in:once,daily,weekdays'],
                'local_time' => ['required', 'date_format:H:i'],
                'timezone' => ['required', 'timezone:all'],
                'once_at' => ['nullable', 'date'],
                'weekdays_mask' => ['nullable', 'integer', 'between:1,127'],
                'enabled' => ['required', 'boolean'],
                'created_at' => ['sometimes', 'date'],
                'updated_at' => ['sometimes', 'date'],
                'archived_at' => ['nullable', 'date'],
            ],
            ['prayer_reminders', 'patch'] => [
                'schedule_type' => ['sometimes', 'in:once,daily,weekdays'],
                'local_time' => ['sometimes', 'date_format:H:i'],
                'timezone' => ['sometimes', 'timezone:all'],
                'once_at' => ['sometimes', 'nullable', 'date'],
                'weekdays_mask' => ['sometimes', 'nullable', 'integer', 'between:1,127'],
                'enabled' => ['sometimes', 'boolean'],
                'updated_at' => ['sometimes', 'date'],
                'archived_at' => ['sometimes', 'nullable', 'date'],
            ],
            ['prayer_sessions', 'put'] => [
                'owner_id' => [],
                'personal_prayer_id' => ['required', 'uuid'],
                'prayer_revision_id' => ['required', 'uuid'],
                'reminder_id' => ['nullable', 'uuid'],
                'reminder_occurrence_key' => ['nullable', 'string', 'max:160'],
                'source' => ['required', 'in:reminder,manual'],
                'occurred_at' => ['required', 'date'],
                'local_date' => ['required', 'date_format:Y-m-d'],
                'timezone' => ['required', 'timezone:all'],
                'device_id' => ['required', 'string', 'max:120'],
                'retracted_at' => ['nullable', 'date'],
            ],
            ['prayer_sessions', 'patch'] => [
                'retracted_at' => ['required', 'date'],
            ],
        };
        if ($operation['data'] === []
            || array_diff(array_keys($operation['data']), array_keys($rules)) !== []
            || Validator::make($operation['data'], $rules)->fails()) {
            return 'invalid_data';
        }

        return null;
    }

    private function validateTarget(User $user, array $operation): ?string
    {
        if ($operation['table'] === 'prayer_reminders') {
            return $this->validateReminderTarget($user, $operation);
        }

        return $this->validateSessionTarget($user, $operation);
    }

    private function validateReminderTarget(User $user, array $operation): ?string
    {
        $existing = PrayerReminder::query()->find($operation['id']);
        if ($operation['type'] !== 'put') {
            if ($existing === null || $existing->user_id !== $user->id) {
                return 'inaccessible_record';
            }
        } elseif ($existing !== null && $existing->user_id !== $user->id) {
            return 'inaccessible_record';
        }

        if ($operation['type'] === 'put'
            && $existing !== null
            && ! $this->reminderMatches($existing, $operation['data'])) {
            return 'conflict';
        }

        if ($operation['type'] === 'delete') {
            return null;
        }
        $prayerId = $operation['type'] === 'put'
            ? $operation['data']['personal_prayer_id']
            : $existing->personal_prayer_id;
        $owned = PersonalPrayer::query()
            ->whereKey($prayerId)
            ->where('user_id', $user->id)
            ->whereNull('archived_at')
            ->exists();
        if (! $owned) {
            return 'inaccessible_record';
        }

        $shape = $operation['type'] === 'put'
            ? $operation['data']
            : array_replace($existing->only([
                'schedule_type', 'local_time', 'timezone', 'once_at',
                'weekdays_mask', 'enabled', 'archived_at',
            ]), $operation['data']);

        return $this->validReminderShape($shape) ? null : 'invalid_data';
    }

    private function validateSessionTarget(User $user, array $operation): ?string
    {
        $existing = PrayerSession::query()->find($operation['id']);
        if ($operation['type'] === 'patch') {
            if ($existing === null || $existing->user_id !== $user->id) {
                return 'inaccessible_record';
            }
            $retractedAt = CarbonImmutable::parse($operation['data']['retracted_at']);
            if ($retractedAt->lt($existing->occurred_at)
                || $retractedAt->gt($existing->occurred_at->addMinutes(5))) {
                return 'retraction_window_closed';
            }

            return null;
        }
        if ($existing !== null) {
            if ($existing->user_id !== $user->id) {
                return 'inaccessible_record';
            }

            return $this->sessionMatches($existing, $operation['data'])
                ? null
                : 'conflict';
        }

        $data = $operation['data'];
        $prayer = PersonalPrayer::query()
            ->whereKey($data['personal_prayer_id'])
            ->where('user_id', $user->id)
            ->whereNull('archived_at')
            ->first();
        if ($prayer === null) {
            return 'inaccessible_record';
        }
        $revision = PersonalPrayerRevision::query()
            ->whereKey($data['prayer_revision_id'])
            ->where('prayer_id', $prayer->id)
            ->where('user_id', $user->id)
            ->exists();
        if (! $revision) {
            return 'invalid_revision';
        }

        $isManual = $data['source'] === 'manual';
        $hasReminder = $data['reminder_id'] !== null
            && $data['reminder_occurrence_key'] !== null
            && trim($data['reminder_occurrence_key']) !== '';
        if ($isManual === $hasReminder) {
            return 'invalid_data';
        }
        if ($hasReminder) {
            $reminder = PrayerReminder::query()
                ->whereKey($data['reminder_id'])
                ->where('user_id', $user->id)
                ->where('personal_prayer_id', $prayer->id)
                ->where('enabled', true)
                ->whereNull('archived_at')
                ->exists();
            if (! $reminder) {
                return 'inaccessible_record';
            }
        }
        if ($data['retracted_at'] !== null) {
            $occurredAt = CarbonImmutable::parse($data['occurred_at']);
            $retractedAt = CarbonImmutable::parse($data['retracted_at']);
            if ($retractedAt->lt($occurredAt)
                || $retractedAt->gt($occurredAt->addMinutes(5))) {
                return 'retraction_window_closed';
            }
        }

        return null;
    }

    private function validReminderShape(array $data): bool
    {
        $onceAt = $data['once_at'] ?? null;
        $weekdays = $data['weekdays_mask'] ?? null;

        return match ($data['schedule_type']) {
            'once' => $onceAt !== null && $weekdays === null,
            'daily' => $onceAt === null && $weekdays === null,
            'weekdays' => $onceAt === null
                && is_int($weekdays) && $weekdays >= 1 && $weekdays <= 127,
            default => false,
        };
    }

    private function applyReminder(
        User $user,
        array $operation,
        Collection $reminders,
    ): ?string {
        $existing = $reminders->get($operation['id']);
        if ($operation['type'] === 'delete') {
            if ($existing === null) {
                return 'inaccessible_record';
            }
            $existing->forceFill([
                'enabled' => false,
                'archived_at' => now(),
            ])->save();

            return null;
        }
        if ($operation['type'] === 'patch') {
            if ($existing === null) {
                return 'inaccessible_record';
            }
            $existing->forceFill(Arr::only($operation['data'], [
                'schedule_type', 'local_time', 'timezone', 'once_at',
                'weekdays_mask', 'enabled', 'archived_at',
            ]))->save();

            return null;
        }
        if ($existing !== null
            && ! $this->reminderMatches($existing, $operation['data'])) {
            return 'conflict';
        }
        if ($existing === null) {
            $data = $operation['data'];
            $created = PrayerReminder::create([
                'id' => $operation['id'],
                'user_id' => $user->id,
                'personal_prayer_id' => $data['personal_prayer_id'],
                'schedule_type' => $data['schedule_type'],
                'local_time' => $data['local_time'],
                'timezone' => $data['timezone'],
                'once_at' => $data['once_at'],
                'weekdays_mask' => $data['weekdays_mask'],
                'enabled' => $data['enabled'],
                'created_at' => $data['created_at'] ?? now(),
                'updated_at' => $data['updated_at'] ?? now(),
                'archived_at' => $data['archived_at'],
            ]);
            $reminders->put($created->id, $created);
        }

        return null;
    }

    private function applySession(
        User $user,
        array $operation,
        Collection $sessions,
    ): ?string {
        $existing = $sessions->get($operation['id']);
        if ($operation['type'] === 'patch') {
            if ($existing === null) {
                return 'inaccessible_record';
            }
            $existing->forceFill([
                'retracted_at' => $operation['data']['retracted_at'],
            ])->save();

            return null;
        }
        if ($existing !== null
            && ! $this->sessionMatches($existing, $operation['data'])) {
            return 'conflict';
        }
        if ($existing === null) {
            $data = $operation['data'];
            $created = PrayerSession::create([
                'id' => $operation['id'],
                'user_id' => $user->id,
                'personal_prayer_id' => $data['personal_prayer_id'],
                'prayer_revision_id' => $data['prayer_revision_id'],
                'reminder_id' => $data['reminder_id'],
                'reminder_occurrence_key' => $data['reminder_occurrence_key'],
                'source' => $data['source'],
                'occurred_at' => $data['occurred_at'],
                'local_date' => $data['local_date'],
                'timezone' => $data['timezone'],
                'device_id' => $data['device_id'],
                'retracted_at' => $data['retracted_at'],
            ]);
            $sessions->put($created->id, $created);
        }

        return null;
    }

    private function sessionMatches(PrayerSession $session, array $data): bool
    {
        return $session->personal_prayer_id === $data['personal_prayer_id']
            && $session->prayer_revision_id === $data['prayer_revision_id']
            && $session->reminder_id === $data['reminder_id']
            && $session->reminder_occurrence_key === $data['reminder_occurrence_key']
            && $session->source === $data['source']
            && $session->occurred_at->equalTo(CarbonImmutable::parse($data['occurred_at']))
            && $session->local_date->format('Y-m-d') === $data['local_date']
            && $session->timezone === $data['timezone']
            && $session->device_id === $data['device_id']
            && $this->dateMatches($session->retracted_at, $data['retracted_at']);
    }

    private function reminderMatches(PrayerReminder $reminder, array $data): bool
    {
        return $reminder->personal_prayer_id === $data['personal_prayer_id']
            && $reminder->schedule_type === $data['schedule_type']
            && $reminder->local_time === $data['local_time']
            && $reminder->timezone === $data['timezone']
            && $this->dateMatches($reminder->once_at, $data['once_at'])
            && $reminder->weekdays_mask === $data['weekdays_mask']
            && $reminder->enabled === $data['enabled']
            && $this->dateMatches($reminder->archived_at, $data['archived_at']);
    }

    private function dateMatches(mixed $stored, mixed $wireValue): bool
    {
        if ($stored === null || $wireValue === null) {
            return $stored === null && $wireValue === null;
        }

        return $stored->equalTo(CarbonImmutable::parse($wireValue));
    }
}
