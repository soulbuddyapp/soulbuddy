<?php

namespace App\Domain\Sync;

use App\Models\AltarItem;
use App\Models\AltarRitual;
use App\Models\Encounter;
use App\Models\LibraryPrayer;
use App\Models\PersonalPrayer;
use App\Models\PersonalPrayerRevision;
use App\Models\User;
use App\Models\VoiceTablet;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Validator;

final class ApplyVoiceTabletAltarMutation
{
    private const TABLES = ['voice_tablets', 'altar_items', 'altar_rituals'];

    public static function supports(string $table): bool
    {
        return in_array($table, self::TABLES, true);
    }

    /** @param Collection<int, array<string, mixed>> $operations */
    public function validate(User $user, Collection $operations, ?Collection $personalPrayerOperations = null): ?string
    {
        foreach ($operations as $operation) {
            $error = $this->validateKindAndData($operation);
            if ($error !== null) {
                return $error;
            }
        }

        // Two prayers must not both claim a new tablet ID while apply() keeps
        // only the first source. Equivalent retries remain safe to accept.
        foreach ($operations->where('table', 'voice_tablets')->where('type', 'put')->groupBy('id') as $duplicates) {
            $expected = Arr::except($duplicates->first()['data'], ['owner_id', 'created_at', 'updated_at']);
            ksort($expected);
            foreach ($duplicates as $operation) {
                $candidate = Arr::except($operation['data'], ['owner_id', 'created_at', 'updated_at']);
                ksort($candidate);
                if ($candidate !== $expected) {
                    return 'conflict';
                }
            }
        }

        $pendingTabletIds = $operations->where('table', 'voice_tablets')->where('type', 'put')->pluck('id');
        $pendingAltarItemIds = $operations->where('table', 'altar_items')->where('type', 'put')->pluck('id');
        foreach ($operations as $operation) {
            $error = $this->validateTarget($user, $operation, $pendingTabletIds, $pendingAltarItemIds, $personalPrayerOperations ?? collect());
            if ($error !== null) {
                return $error;
            }
        }

        return null;
    }

    /** @param Collection<int, array<string, mixed>> $operations */
    public function apply(User $user, Collection $operations): ?string
    {
        foreach (['voice_tablets', 'altar_items', 'altar_rituals'] as $table) {
            foreach ($operations->where('table', $table) as $operation) {
                $model = $this->modelFor($table)::query()->lockForUpdate()->find($operation['id']);
                if ($model !== null && $model->user_id !== $user->id) {
                    return 'inaccessible_record';
                }
                if ($operation['type'] === 'delete') {
                    if ($model === null) {
                        return 'inaccessible_record';
                    }
                    $attributes = ['archived_at' => now()];
                    if ($table === 'altar_rituals') {
                        $attributes['enabled'] = false;
                    }
                    $model->forceFill($attributes)->save();

                    continue;
                }
                if ($operation['type'] === 'patch') {
                    if ($model === null) {
                        return 'inaccessible_record';
                    }
                    $model->forceFill(Arr::except($operation['data'], ['owner_id', 'updated_at']))->save();

                    continue;
                }
                if ($model === null) {
                    $attributes = Arr::except($operation['data'], ['owner_id']);
                    $attributes['id'] = $operation['id'];
                    $attributes['user_id'] = $user->id;
                    $this->modelFor($table)::create($attributes);
                }
            }
        }

        return null;
    }

    private function validateKindAndData(array $operation): ?string
    {
        if (! in_array($operation['type'], ['put', 'patch', 'delete'], true)) {
            return 'unsupported_operation';
        }
        if ($operation['type'] === 'delete') {
            return $operation['data'] === [] ? null : 'invalid_data';
        }

        $rules = $this->rules($operation['table'], $operation['type']);
        if ($operation['data'] === []
            || array_diff(array_keys($operation['data']), array_keys($rules)) !== []
            || Validator::make($operation['data'], $rules)->fails()) {
            return 'invalid_data';
        }
        if ($operation['type'] === 'put' && ! $this->validShape($operation['table'], $operation['data'])) {
            return 'invalid_data';
        }

        return null;
    }

    private function rules(string $table, string $type): array
    {
        if ($type === 'patch') {
            return match ($table) {
                'voice_tablets' => [
                    'title' => ['sometimes', 'string', 'max:120'],
                    'full_audio_id' => ['sometimes', 'uuid'],
                    'refrain_audio_id' => ['sometimes', 'nullable', 'uuid'],
                    'recording_device_id' => ['sometimes', 'string', 'max:120'],
                    'updated_at' => ['sometimes', 'date'],
                    'archived_at' => ['sometimes', 'nullable', 'date'],
                ],
                'altar_items' => [
                    'updated_at' => ['sometimes', 'date'],
                    'archived_at' => ['sometimes', 'nullable', 'date'],
                ],
                'altar_rituals' => [
                    'schedule_type' => ['sometimes', 'in:daily,weekdays'],
                    'local_time' => ['sometimes', 'date_format:H:i'],
                    'timezone' => ['sometimes', 'timezone:all'],
                    'weekdays_mask' => ['sometimes', 'nullable', 'integer', 'between:1,127'],
                    'playback_mode' => ['sometimes', 'in:refrain,full_prayer,open_quietly'],
                    'enabled' => ['sometimes', 'boolean'],
                    'updated_at' => ['sometimes', 'date'],
                    'archived_at' => ['sometimes', 'nullable', 'date'],
                ],
            };
        }

        return match ($table) {
            'voice_tablets' => [
                'owner_id' => [],
                'source_type' => ['required', 'in:personal_prayer,library_prayer'],
                'personal_prayer_id' => ['present', 'nullable', 'uuid'],
                'library_prayer_id' => ['present', 'nullable', 'uuid'],
                'prayer_revision_id' => ['present', 'nullable', 'uuid'],
                'title' => ['required', 'string', 'max:120'],
                'full_audio_id' => ['required', 'uuid'],
                'refrain_audio_id' => ['present', 'nullable', 'uuid'],
                'recording_device_id' => ['required', 'string', 'max:120'],
                'created_at' => ['sometimes', 'date'],
                'updated_at' => ['sometimes', 'date'],
                'archived_at' => ['present', 'nullable', 'date'],
            ],
            'altar_items' => [
                'owner_id' => [],
                'target_type' => ['required', 'in:encounter,personal_prayer,library_prayer,voice_tablet'],
                'encounter_id' => ['present', 'nullable', 'uuid'],
                'personal_prayer_id' => ['present', 'nullable', 'uuid'],
                'library_prayer_id' => ['present', 'nullable', 'uuid'],
                'voice_tablet_id' => ['present', 'nullable', 'uuid'],
                'created_at' => ['sometimes', 'date'],
                'updated_at' => ['sometimes', 'date'],
                'archived_at' => ['present', 'nullable', 'date'],
            ],
            'altar_rituals' => [
                'owner_id' => [],
                'altar_item_id' => ['required', 'uuid'],
                'schedule_type' => ['required', 'in:daily,weekdays'],
                'local_time' => ['required', 'date_format:H:i'],
                'timezone' => ['required', 'timezone:all'],
                'weekdays_mask' => ['present', 'nullable', 'integer', 'between:1,127'],
                'playback_mode' => ['required', 'in:refrain,full_prayer,open_quietly'],
                'enabled' => ['required', 'boolean'],
                'created_at' => ['sometimes', 'date'],
                'updated_at' => ['sometimes', 'date'],
                'archived_at' => ['present', 'nullable', 'date'],
            ],
        };
    }

    private function validShape(string $table, array $data): bool
    {
        if ($table === 'voice_tablets') {
            return $data['source_type'] === 'personal_prayer'
                ? $data['personal_prayer_id'] !== null && $data['prayer_revision_id'] !== null && $data['library_prayer_id'] === null
                : $data['personal_prayer_id'] === null && $data['prayer_revision_id'] === null && $data['library_prayer_id'] !== null;
        }
        if ($table === 'altar_items') {
            $target = $data[$data['target_type'].'_id'] ?? null;
            $set = collect(['encounter_id', 'personal_prayer_id', 'library_prayer_id', 'voice_tablet_id'])->filter(fn ($key) => $data[$key] !== null);

            return $target !== null && $set->count() === 1;
        }
        if ($table === 'altar_rituals') {
            return $data['schedule_type'] === 'daily'
                ? $data['weekdays_mask'] === null
                : is_int($data['weekdays_mask']) && $data['weekdays_mask'] >= 1 && $data['weekdays_mask'] <= 127;
        }

        return false;
    }

    private function validateTarget(User $user, array $operation, Collection $pendingTabletIds, Collection $pendingAltarItemIds, Collection $personalPrayerOperations): ?string
    {
        $modelClass = $this->modelFor($operation['table']);
        $existing = $modelClass::query()->find($operation['id']);
        if ($operation['type'] !== 'put') {
            if ($existing === null || $existing->user_id !== $user->id) {
                return 'inaccessible_record';
            }

            return $operation['table'] === 'altar_rituals' && $operation['type'] === 'patch'
                ? $this->validateRitualPatchShape($existing, $operation['data'])
                : null;
        }
        if ($existing !== null) {
            if ($existing->user_id !== $user->id) {
                return 'inaccessible_record';
            }

            return $this->storedMatches($existing, $operation['data']) ? null : 'conflict';
        }

        $data = $operation['data'];
        if ($operation['table'] === 'voice_tablets') {
            return $this->validateVoiceSource($user, $data, $personalPrayerOperations);
        }
        if ($operation['table'] === 'altar_items') {
            return $this->validateAltarTarget($user, $data, $pendingTabletIds);
        }

        $altarItem = AltarItem::query()->whereKey($data['altar_item_id'])->where('user_id', $user->id)->whereNull('archived_at')->exists();

        return $altarItem || $pendingAltarItemIds->contains($data['altar_item_id']) ? null : 'inaccessible_record';
    }

    private function validateVoiceSource(User $user, array $data, Collection $pending): ?string
    {
        if ($data['source_type'] === 'library_prayer') {
            return LibraryPrayer::query()->whereKey($data['library_prayer_id'])->whereNotNull('published_at')->whereNull('archived_at')->exists()
                ? null : 'inaccessible_record';
        }
        $prayer = PersonalPrayer::query()->whereKey($data['personal_prayer_id'])->first();
        if ($prayer !== null && ($prayer->user_id !== $user->id || $prayer->archived_at !== null)) {
            return 'inaccessible_record';
        }
        $pendingPrayer = $pending->where('table', 'personal_prayers')->where('type', 'put')
            ->contains(fn (array $operation): bool => $operation['id'] === $data['personal_prayer_id']
                && ($operation['data']['archived_at'] ?? null) === null);
        if ($prayer === null && ! $pendingPrayer) {
            return 'inaccessible_record';
        }
        $revision = PersonalPrayerRevision::query()->whereKey($data['prayer_revision_id'])->first();
        if ($revision !== null) {
            return $revision->prayer_id === $data['personal_prayer_id'] && $revision->user_id === $user->id
                ? null : 'invalid_revision';
        }
        $pendingRevision = $pending->where('table', 'personal_prayer_revisions')->where('type', 'put')
            ->contains(fn (array $operation): bool => $operation['id'] === $data['prayer_revision_id']
                && ($operation['data']['prayer_id'] ?? null) === $data['personal_prayer_id']);

        return $pendingRevision ? null : 'invalid_revision';
    }

    private function validateAltarTarget(User $user, array $data, Collection $pendingTabletIds): ?string
    {
        $query = match ($data['target_type']) {
            'encounter' => Encounter::query()->whereKey($data['encounter_id'])->where('user_id', $user->id)->whereNull('archived_at'),
            'personal_prayer' => PersonalPrayer::query()->whereKey($data['personal_prayer_id'])->where('user_id', $user->id)->whereNull('archived_at'),
            'library_prayer' => LibraryPrayer::query()->whereKey($data['library_prayer_id'])->whereNotNull('published_at')->whereNull('archived_at'),
            'voice_tablet' => VoiceTablet::query()->whereKey($data['voice_tablet_id'])->where('user_id', $user->id)->whereNull('archived_at'),
        };
        if ($query->exists()) {
            return null;
        }

        return $data['target_type'] === 'voice_tablet' && $pendingTabletIds->contains($data['voice_tablet_id'])
            ? null : 'inaccessible_record';
    }

    private function validateRitualPatchShape(AltarRitual $ritual, array $patch): ?string
    {
        $shape = array_replace($ritual->only(['schedule_type', 'weekdays_mask']), $patch);

        return $this->validShape('altar_rituals', $shape) ? null : 'invalid_data';
    }

    private function storedMatches(object $model, array $data): bool
    {
        foreach (Arr::except($data, ['owner_id', 'created_at', 'updated_at']) as $key => $value) {
            $stored = $model->{$key};
            if ($stored instanceof \DateTimeInterface) {
                $stored = $stored->format('c');
                $value = $value === null ? null : date('c', strtotime($value));
            }
            if ($stored !== $value) {
                return false;
            }
        }

        return true;
    }

    /** @return class-string */
    private function modelFor(string $table): string
    {
        return match ($table) {
            'voice_tablets' => VoiceTablet::class,
            'altar_items' => AltarItem::class,
            'altar_rituals' => AltarRitual::class,
        };
    }
}
