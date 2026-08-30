<?php

namespace App\Domain\Sync;

use App\Models\Encounter;
use App\Models\EncounterPersonLink;
use App\Models\PersonPrayerOccurrence;
use App\Models\PrayerPerson;
use App\Models\User;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Validator;

final class ApplyPersonPrayerMutation
{
    private const TABLES = [
        'prayer_people',
        'person_prayer_occurrences',
        'encounter_person_links',
    ];

    public static function supports(string $table): bool
    {
        return in_array($table, self::TABLES, true);
    }

    /** @param Collection<int, array<string, mixed>> $operations */
    public function validate(User $user, Collection $operations): ?string
    {
        $pendingPeople = $operations->where('table', 'prayer_people')->where('type', 'put')->pluck('id');
        foreach ($operations as $operation) {
            if (! in_array($operation['type'], ['put', 'patch', 'delete'], true)) {
                return 'unsupported_operation';
            }
            if ($operation['table'] === 'person_prayer_occurrences' && $operation['type'] !== 'put') {
                return 'immutable_occurrence';
            }
            if ($operation['type'] === 'delete') {
                if ($operation['data'] !== [] || $operation['table'] === 'person_prayer_occurrences') {
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
            $existing = $this->modelFor($operation['table'])::query()->find($operation['id']);
            if ($existing !== null) {
                if ($existing->user_id !== $user->id) {
                    return 'inaccessible_record';
                }
                if ($operation['table'] === 'person_prayer_occurrences') {
                    return 'immutable_occurrence';
                }
            } elseif ($operation['type'] !== 'put') {
                return 'inaccessible_record';
            }
            if ($operation['type'] !== 'put' || $operation['table'] === 'prayer_people') {
                continue;
            }
            $personId = $operation['data']['person_id'];
            $ownsPerson = PrayerPerson::query()
                ->whereKey($personId)->where('user_id', $user->id)
                ->whereNull('archived_at')->exists();
            if (! $ownsPerson && ! $pendingPeople->contains($personId)) {
                return 'inaccessible_record';
            }
            if ($operation['table'] === 'person_prayer_occurrences'
                && $operation['data']['occurrence_key'] !== $personId.':'.$operation['data']['local_date']) {
                return 'invalid_occurrence';
            }
            if ($operation['table'] === 'encounter_person_links') {
                $encounter = Encounter::query()->whereKey($operation['data']['encounter_id'])
                    ->where('user_id', $user->id)->whereNull('archived_at')->exists();
                if (! $encounter) {
                    return 'inaccessible_record';
                }
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
                    if ($table === 'prayer_people') {
                        $model->forceFill(['archived_at' => now()])->save();
                    } else {
                        $model->delete();
                    }

                    continue;
                }
                if ($operation['type'] === 'patch') {
                    $model->forceFill(Arr::except($operation['data'], ['owner_id', 'updated_at']))->save();

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

    private function rules(string $table, string $type): array
    {
        if ($type === 'patch') {
            return [
                'name' => ['sometimes', 'string', 'max:120'],
                'relationship' => ['sometimes', 'nullable', 'string', 'max:80'],
                'cadence' => ['sometimes', 'in:daily,weekly,selected_days'],
                'local_time' => ['sometimes', 'nullable', 'date_format:H:i'],
                'timezone' => ['sometimes', 'nullable', 'timezone:all'],
                'weekdays_mask' => ['sometimes', 'integer', 'between:0,127'],
                'updated_at' => ['sometimes', 'date'],
                'archived_at' => ['sometimes', 'nullable', 'date'],
            ];
        }

        return match ($table) {
            'prayer_people' => [
                'owner_id' => [], 'name' => ['required', 'string', 'max:120'],
                'relationship' => ['present', 'nullable', 'string', 'max:80'],
                'cadence' => ['required', 'in:daily,weekly,selected_days'],
                'local_time' => ['present', 'nullable', 'date_format:H:i'],
                'timezone' => ['present', 'nullable', 'timezone:all'],
                'weekdays_mask' => ['required', 'integer', 'between:0,127'],
                'created_at' => ['sometimes', 'date'], 'updated_at' => ['sometimes', 'date'],
                'archived_at' => ['present', 'nullable', 'date'],
            ],
            'person_prayer_occurrences' => [
                'owner_id' => [], 'person_id' => ['required', 'uuid'],
                'local_date' => ['required', 'date_format:Y-m-d'],
                'occurrence_key' => ['required', 'string', 'max:180'],
                'prayed_at' => ['required', 'date'], 'device_id' => ['required', 'string', 'max:120'],
            ],
            'encounter_person_links' => [
                'owner_id' => [], 'encounter_id' => ['required', 'uuid'],
                'person_id' => ['required', 'uuid'], 'created_at' => ['required', 'date'],
            ],
        };
    }

    /** @return class-string */
    private function modelFor(string $table): string
    {
        return match ($table) {
            'prayer_people' => PrayerPerson::class,
            'person_prayer_occurrences' => PersonPrayerOccurrence::class,
            'encounter_person_links' => EncounterPersonLink::class,
        };
    }
}
