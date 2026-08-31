<?php

namespace App\Domain\Sync;

use App\Models\LibraryPrayer;
use App\Models\PersonalPrayer;
use App\Models\PrayerPerson;
use App\Models\PrayerSession;
use App\Models\SacredHour;
use App\Models\SacredHourOccurrence;
use App\Models\User;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Validator;

final class ApplySacredHourMutation
{
    private const TABLES = ['sacred_hours', 'sacred_hour_occurrences'];

    public static function supports(string $table): bool
    {
        return in_array($table, self::TABLES, true);
    }

    /**
     * @param  Collection<int, array<string, mixed>>  $operations
     * @param  Collection<int, string>|null  $pendingPersonalPrayerIds
     * @param  Collection<int, string>|null  $pendingPersonIds
     */
    public function validate(
        User $user,
        Collection $operations,
        ?Collection $pendingPersonalPrayerIds = null,
        ?Collection $pendingPersonIds = null,
    ): ?string {
        $pendingPersonalPrayerIds ??= collect();
        $pendingPersonIds ??= collect();
        $pendingHours = $operations
            ->where('table', 'sacred_hours')
            ->where('type', 'put')
            ->pluck('id');

        foreach ($operations as $operation) {
            if (! in_array($operation['type'], ['put', 'patch', 'delete'], true)) {
                return 'unsupported_operation';
            }
            if ($operation['table'] === 'sacred_hour_occurrences'
                && $operation['type'] === 'delete') {
                return 'invalid_data';
            }
            if ($operation['type'] === 'delete') {
                if ($operation['data'] !== []) {
                    return 'invalid_data';
                }
            } else {
                $rules = $this->rules($operation['table'], $operation['type']);
                if ($operation['data'] === []
                    || array_diff(array_keys($operation['data']), array_keys($rules)) !== []
                    || Validator::make($operation['data'], $rules)->fails()) {
                    return 'invalid_data';
                }
            }

            $modelClass = $this->modelFor($operation['table']);
            $existing = $modelClass::query()->find($operation['id']);
            if ($existing !== null && $existing->user_id !== $user->id) {
                return 'inaccessible_record';
            }
            if ($existing === null && $operation['type'] !== 'put') {
                return 'inaccessible_record';
            }
            if ($operation['type'] === 'delete') {
                continue;
            }

            if ($operation['table'] === 'sacred_hours') {
                $linkError = $this->validateHourLinks(
                    $user,
                    $operation,
                    $existing,
                    $pendingPersonalPrayerIds,
                    $pendingPersonIds,
                );
                if ($linkError !== null) {
                    return $linkError;
                }

                continue;
            }

            $hourId = $operation['data']['sacred_hour_id']
                ?? $existing?->sacred_hour_id;
            $ownedHour = SacredHour::query()
                ->whereKey($hourId)
                ->where('user_id', $user->id)
                ->whereNull('archived_at')
                ->exists();
            if (! $ownedHour && ! $pendingHours->contains($hourId)) {
                return 'inaccessible_record';
            }
            $sessionId = $operation['data']['prayer_session_id']
                ?? $existing?->prayer_session_id;
            if ($sessionId !== null && ! PrayerSession::query()
                ->whereKey($sessionId)
                ->where('user_id', $user->id)
                ->exists()) {
                return 'inaccessible_record';
            }
        }

        return null;
    }

    /** @param Collection<int, array<string, mixed>> $operations */
    public function apply(User $user, Collection $operations): ?string
    {
        foreach (self::TABLES as $table) {
            foreach ($operations->where('table', $table) as $operation) {
                $modelClass = $this->modelFor($table);
                $model = $modelClass::query()->lockForUpdate()->find($operation['id']);
                if ($operation['type'] === 'delete') {
                    $model->forceFill([
                        'enabled' => false,
                        'archived_at' => now(),
                        'updated_at' => now(),
                    ])->save();

                    continue;
                }
                if ($operation['type'] === 'patch') {
                    $attributes = Arr::except($operation['data'], ['owner_id', 'created_at']);
                    if ($table === 'sacred_hours'
                        && array_key_exists('archived_at', $attributes)
                        && $attributes['archived_at'] !== null) {
                        $attributes['enabled'] = false;
                    }
                    $model->forceFill($attributes)->save();

                    continue;
                }
                if ($model === null) {
                    $attributes = Arr::except($operation['data'], ['owner_id']);
                    $attributes['id'] = $operation['id'];
                    $attributes['user_id'] = $user->id;
                    $modelClass::create($attributes);
                }
            }
        }

        return null;
    }

    /**
     * @param  array<string, mixed>  $operation
     * @param  Collection<int, string>  $pendingPersonalPrayerIds
     * @param  Collection<int, string>  $pendingPersonIds
     */
    private function validateHourLinks(
        User $user,
        array $operation,
        ?SacredHour $existing,
        Collection $pendingPersonalPrayerIds,
        Collection $pendingPersonIds,
    ): ?string {
        $data = $operation['data'];
        $prayerType = array_key_exists('prayer_type', $data)
            ? $data['prayer_type']
            : $existing?->prayer_type;
        $prayerId = array_key_exists('prayer_id', $data)
            ? $data['prayer_id']
            : $existing?->prayer_id;
        if (($prayerType === null) !== ($prayerId === null)) {
            return 'invalid_data';
        }
        if ($prayerType === 'library') {
            $available = LibraryPrayer::query()
                ->whereKey($prayerId)
                ->whereNotNull('published_at')
                ->whereNull('archived_at')
                ->exists();
            if (! $available) {
                return 'inaccessible_record';
            }
        }
        if ($prayerType === 'personal') {
            $owned = PersonalPrayer::query()
                ->whereKey($prayerId)
                ->where('user_id', $user->id)
                ->whereNull('archived_at')
                ->exists();
            if (! $owned && ! $pendingPersonalPrayerIds->contains($prayerId)) {
                return 'inaccessible_record';
            }
        }

        $personId = array_key_exists('person_id', $data)
            ? $data['person_id']
            : $existing?->person_id;
        if ($personId !== null) {
            $owned = PrayerPerson::query()
                ->whereKey($personId)
                ->where('user_id', $user->id)
                ->whereNull('archived_at')
                ->exists();
            if (! $owned && ! $pendingPersonIds->contains($personId)) {
                return 'inaccessible_record';
            }
        }

        return null;
    }

    /** @return array<string, array<int, mixed>> */
    private function rules(string $table, string $type): array
    {
        if ($table === 'sacred_hours' && $type === 'patch') {
            return [
                'purpose_key' => ['sometimes', 'nullable', 'in:morning,evening'],
                'name' => ['sometimes', 'string', 'max:120'],
                'local_time' => ['sometimes', 'date_format:H:i'],
                'timezone' => ['sometimes', 'timezone:all', 'max:64'],
                'duration_minutes' => ['sometimes', 'integer', 'in:60'],
                'prayer_minutes' => ['sometimes', 'integer', 'in:5,15,30'],
                'enabled' => ['sometimes', 'boolean'],
                'sound_key' => ['sometimes', 'in:gentle_chime,dawn_chime,still_bell,evening_chime,device,silent'],
                'prayer_type' => ['sometimes', 'nullable', 'in:library,personal'],
                'prayer_id' => ['sometimes', 'nullable', 'uuid'],
                'person_id' => ['sometimes', 'nullable', 'uuid'],
                'updated_at' => ['sometimes', 'date'],
                'archived_at' => ['sometimes', 'nullable', 'date'],
            ];
        }
        if ($table === 'sacred_hour_occurrences' && $type === 'patch') {
            return [
                'status' => ['sometimes', 'in:due,begun,completed,dismissed'],
                'prayer_session_id' => ['sometimes', 'nullable', 'uuid'],
                'updated_at' => ['sometimes', 'date'],
            ];
        }

        return match ($table) {
            'sacred_hours' => [
                'owner_id' => [],
                'purpose_key' => ['present', 'nullable', 'in:morning,evening'],
                'name' => ['required', 'string', 'max:120'],
                'local_time' => ['required', 'date_format:H:i'],
                'timezone' => ['required', 'timezone:all', 'max:64'],
                'duration_minutes' => ['required', 'integer', 'in:60'],
                'prayer_minutes' => ['required', 'integer', 'in:5,15,30'],
                'enabled' => ['required', 'boolean'],
                'sound_key' => ['required', 'in:gentle_chime,dawn_chime,still_bell,evening_chime,device,silent'],
                'prayer_type' => ['present', 'nullable', 'in:library,personal'],
                'prayer_id' => ['present', 'nullable', 'uuid'],
                'person_id' => ['present', 'nullable', 'uuid'],
                'created_at' => ['sometimes', 'date'],
                'updated_at' => ['sometimes', 'date'],
                'archived_at' => ['present', 'nullable', 'date'],
            ],
            'sacred_hour_occurrences' => [
                'owner_id' => [],
                'sacred_hour_id' => ['required', 'uuid'],
                'due_at' => ['required', 'date'],
                'local_date' => ['required', 'date_format:Y-m-d'],
                'status' => ['required', 'in:due,begun,completed,dismissed'],
                'prayer_session_id' => ['present', 'nullable', 'uuid'],
                'created_at' => ['sometimes', 'date'],
                'updated_at' => ['sometimes', 'date'],
            ],
        };
    }

    /** @return class-string */
    private function modelFor(string $table): string
    {
        return match ($table) {
            'sacred_hours' => SacredHour::class,
            'sacred_hour_occurrences' => SacredHourOccurrence::class,
        };
    }
}
