<?php

namespace App\Domain\Sync;

use App\Models\Encounter;
use App\Models\EncounterRevision;
use App\Models\LibraryPrayer;
use App\Models\MemoryReflection;
use App\Models\PersonalPrayer;
use App\Models\PrayerRecordAlias;
use App\Models\PrayerVote;
use App\Models\SyncOperation;
use App\Models\TodayPrayer;
use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Database\QueryException;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Validator;

class ApplySyncMutation
{
    private const SUPPORTED_TABLES = [
        'encounters',
        'encounter_revisions',
        'memory_reflections',
        'prayer_votes',
        'today_prayers',
        'personal_prayers',
        'personal_prayer_revisions',
        'personal_prayer_links',
        'prayer_reminders',
        'prayer_sessions',
        'voice_tablets',
        'altar_items',
        'altar_rituals',
        'prayer_people',
        'person_prayer_occurrences',
        'encounter_person_links',
        'sacred_hours',
        'sacred_hour_occurrences',
        ApplyAffirmationPrayerSessionMutation::TABLE,
    ];

    public function apply(User $user, array $operations): array
    {
        $stored = SyncOperation::query()
            ->whereIn('operation_id', collect($operations)->pluck('operation_id'))
            ->get()
            ->keyBy('operation_id');
        $duplicates = 0;
        $hasConflict = false;
        $pending = new Collection;

        foreach ($operations as $operation) {
            $existing = $stored->get($operation['operation_id']);
            if ($existing === null) {
                $pending->push($operation);

                continue;
            }

            if ($this->isSameOperation($existing, $user, $operation)) {
                $duplicates++;
            } else {
                $hasConflict = true;
            }
        }

        if ($hasConflict) {
            return $this->result(
                $duplicates,
                count($operations) - $duplicates,
                $duplicates,
                'operation_conflict',
            );
        }

        if ($pending->isEmpty()) {
            return $this->result(count($operations), 0, $duplicates);
        }

        if ($pending->contains(fn (array $operation) => ! in_array(
            $operation['table'],
            self::SUPPORTED_TABLES,
            true,
        ))) {
            return $this->result($duplicates, $pending->count(), $duplicates, 'unsupported_table');
        }

        $kindError = $this->validateOperationKinds($pending->all());
        if ($kindError !== null) {
            return $this->result($duplicates, $pending->count(), $duplicates, $kindError);
        }

        $encounterOperations = $pending
            ->whereIn('table', ['encounters', 'encounter_revisions', 'memory_reflections'])
            ->all();
        $prayerOperations = $pending
            ->whereIn('table', ['prayer_votes', 'today_prayers'])
            ->all();
        $personalPrayerOperations = $pending
            ->filter(fn (array $operation): bool => ApplyPersonalPrayerMutation::supports($operation['table']));
        $practiceOperations = $pending
            ->filter(fn (array $operation): bool => ApplyPrayerPracticeMutation::supports($operation['table']));
        $voiceTabletAltarOperations = $pending
            ->filter(fn (array $operation): bool => ApplyVoiceTabletAltarMutation::supports($operation['table']));
        $personPrayerOperations = $pending
            ->filter(fn (array $operation): bool => ApplyPersonPrayerMutation::supports($operation['table']));
        $affirmationSessionOperations = $pending
            ->filter(fn (array $operation): bool => ApplyAffirmationPrayerSessionMutation::supports($operation['table']));
        $sacredHourOperations = $pending
            ->filter(fn (array $operation): bool => ApplySacredHourMutation::supports($operation['table']));
        $pendingEncounterIds = collect($encounterOperations)
            ->where('table', 'encounters')
            ->where('type', 'put')
            ->filter(fn (array $operation): bool => ($operation['data']['archived_at'] ?? null) === null)
            ->pluck('id');

        $encounterTargetError = $this->validateTargets($user, $encounterOperations);
        if ($encounterTargetError !== null) {
            return $this->result($duplicates, $pending->count(), $duplicates, $encounterTargetError);
        }

        $pairError = $this->validatePairs($encounterOperations);
        if ($pairError !== null) {
            return $this->result($duplicates, $pending->count(), $duplicates, $pairError);
        }

        $personalPrayerError = app(ApplyPersonalPrayerMutation::class)
            ->validate($user, $personalPrayerOperations, $voiceTabletAltarOperations);
        if ($personalPrayerError !== null) {
            return $this->result($duplicates, $pending->count(), $duplicates, $personalPrayerError);
        }

        $practiceError = app(ApplyPrayerPracticeMutation::class)
            ->validate($user, $practiceOperations);
        if ($practiceError !== null) {
            return $this->result($duplicates, $pending->count(), $duplicates, $practiceError);
        }

        $voiceTabletAltarError = app(ApplyVoiceTabletAltarMutation::class)
            ->validate($user, $voiceTabletAltarOperations, $personalPrayerOperations);
        if ($voiceTabletAltarError !== null) {
            return $this->result($duplicates, $pending->count(), $duplicates, $voiceTabletAltarError);
        }

        $personPrayerError = app(ApplyPersonPrayerMutation::class)
            ->validate($user, $personPrayerOperations, $pendingEncounterIds);
        if ($personPrayerError !== null) {
            return $this->result($duplicates, $pending->count(), $duplicates, $personPrayerError);
        }

        $affirmationSessionError = app(ApplyAffirmationPrayerSessionMutation::class)
            ->validate($user, $affirmationSessionOperations);
        if ($affirmationSessionError !== null) {
            return $this->result($duplicates, $pending->count(), $duplicates, $affirmationSessionError);
        }

        $sacredHourError = app(ApplySacredHourMutation::class)->validate(
            $user,
            $sacredHourOperations,
            $personalPrayerOperations
                ->where('table', 'personal_prayers')
                ->where('type', 'put')
                ->pluck('id'),
            $personPrayerOperations
                ->where('table', 'prayer_people')
                ->where('type', 'put')
                ->pluck('id'),
        );
        if ($sacredHourError !== null) {
            return $this->result($duplicates, $pending->count(), $duplicates, $sacredHourError);
        }

        foreach ([$encounterOperations, $prayerOperations] as $domainOperations) {
            $validationError = $this->validateData($domainOperations);
            if ($validationError !== null) {
                return $this->result($duplicates, $pending->count(), $duplicates, $validationError);
            }
        }

        try {
            DB::transaction(function () use ($user, $pending, $prayerOperations, $personalPrayerOperations, $practiceOperations, $voiceTabletAltarOperations, $personPrayerOperations, $sacredHourOperations, $affirmationSessionOperations): void {
                User::query()->whereKey($user->id)->lockForUpdate()->firstOrFail();
                $prayerContexts = [];
                if ($prayerOperations !== []) {
                    $prepared = $this->preparePrayerMutations($user, $prayerOperations);
                    $prayerContexts = $prepared['contexts'];
                    $lockedPrayers = $this->lockPrayers($prepared['prayer_ids']);
                    $lockedPersonalPrayers = $this->lockPersonalPrayers(
                        $prepared['personal_prayer_ids'],
                    );
                    $prayerError = $this->validatePreparedPrayerMutations(
                        $user,
                        $prayerOperations,
                        $prayerContexts,
                        $lockedPrayers,
                        $lockedPersonalPrayers,
                        $personalPrayerOperations
                            ->where('table', 'personal_prayers')
                            ->where('type', 'put')
                            ->pluck('id')
                            ->all(),
                    );
                    if ($prayerError !== null) {
                        throw new SyncMutationRejected($prayerError);
                    }
                }

                $personalPrayerError = app(ApplyPersonalPrayerMutation::class)
                    ->apply($user, $personalPrayerOperations);
                if ($personalPrayerError !== null) {
                    throw new SyncMutationRejected($personalPrayerError);
                }

                $practiceError = app(ApplyPrayerPracticeMutation::class)
                    ->apply($user, $practiceOperations);
                if ($practiceError !== null) {
                    throw new SyncMutationRejected($practiceError);
                }

                $voiceTabletAltarError = app(ApplyVoiceTabletAltarMutation::class)
                    ->apply($user, $voiceTabletAltarOperations);
                if ($voiceTabletAltarError !== null) {
                    throw new SyncMutationRejected($voiceTabletAltarError);
                }

                foreach ($pending->sortBy(fn (array $operation) => $operation['table'] === 'encounters' ? 0 : 1) as $operation) {
                    if (! ApplyPersonalPrayerMutation::supports($operation['table'])
                        && ! ApplyPrayerPracticeMutation::supports($operation['table'])
                        && ! ApplyVoiceTabletAltarMutation::supports($operation['table'])
                        && ! ApplyPersonPrayerMutation::supports($operation['table'])
                        && ! ApplySacredHourMutation::supports($operation['table'])
                        && ! ApplyAffirmationPrayerSessionMutation::supports($operation['table'])) {
                        match ($operation['table']) {
                            'encounters' => $this->applyEncounter($user, $operation),
                            'encounter_revisions' => $this->applyRevision($user, $operation),
                            'memory_reflections' => $this->applyReflection($user, $operation),
                            'prayer_votes' => $this->applyPrayerVote(
                                $user,
                                $operation,
                                $prayerContexts[$operation['operation_id']],
                            ),
                            'today_prayers' => $this->applyTodayPrayer(
                                $user,
                                $operation,
                                $prayerContexts[$operation['operation_id']],
                            ),
                        };
                    }
                }

                $personPrayerError = app(ApplyPersonPrayerMutation::class)
                    ->apply($user, $personPrayerOperations);
                if ($personPrayerError !== null) {
                    throw new SyncMutationRejected($personPrayerError);
                }

                $sacredHourError = app(ApplySacredHourMutation::class)
                    ->apply($user, $sacredHourOperations);
                if ($sacredHourError !== null) {
                    throw new SyncMutationRejected($sacredHourError);
                }

                $affirmationSessionError = app(ApplyAffirmationPrayerSessionMutation::class)
                    ->apply($user, $affirmationSessionOperations);
                if ($affirmationSessionError !== null) {
                    throw new SyncMutationRejected($affirmationSessionError);
                }

                foreach ($pending as $operation) {
                    $this->storeSyncOperation($user, $operation);
                }
            });
        } catch (SyncMutationRejected $rejection) {
            return $this->result($duplicates, $pending->count(), $duplicates, $rejection->syncCode);
        } catch (AuthorizationException) {
            return $this->result($duplicates, $pending->count(), $duplicates, 'forbidden');
        } catch (QueryException $exception) {
            if ($this->isConstraintViolation($exception)) {
                $replay = $this->concurrentReplayResult(
                    $user,
                    $pending,
                    $duplicates,
                    count($operations),
                );
                if ($replay !== null) {
                    return $replay;
                }

                return $this->result($duplicates, $pending->count(), $duplicates, 'conflict');
            }

            throw $exception;
        }

        return $this->result(count($operations), 0, $duplicates);
    }

    private function validateOperationKinds(array $operations): ?string
    {
        foreach ($operations as $operation) {
            if ($operation['table'] === 'encounter_revisions' && $operation['type'] !== 'put') {
                return 'immutable_revision';
            }
            if ($operation['table'] === 'memory_reflections' && $operation['type'] !== 'put') {
                return 'immutable_reflection';
            }
            if ($operation['table'] === 'prayer_votes' && $operation['type'] === 'patch') {
                return 'unsupported_operation';
            }
        }

        return null;
    }

    private function validateTargets(User $user, array $operations): ?string
    {
        foreach ($operations as $operation) {
            if ($operation['table'] === 'encounters'
                && $operation['type'] !== 'put'
                && ! Encounter::whereKey($operation['id'])->exists()) {
                return 'missing_record';
            }
            if ($operation['table'] === 'encounter_revisions') {
                $revision = EncounterRevision::find($operation['id']);
                if ($revision !== null) {
                    return $revision->user_id === $user->id
                        ? 'immutable_revision'
                        : 'forbidden';
                }
            }
            if ($operation['table'] === 'memory_reflections') {
                $reflection = MemoryReflection::find($operation['id']);
                if ($reflection !== null) {
                    return $reflection->user_id === $user->id
                        ? 'immutable_reflection'
                        : 'forbidden';
                }
                $encounterId = $operation['data']['encounter_id'] ?? null;
                $encounterInBatch = collect($operations)
                    ->where('table', 'encounters')
                    ->where('type', 'put')
                    ->contains('id', $encounterId);
                if (! $encounterInBatch && ! Encounter::whereKey($encounterId)->exists()) {
                    return 'missing_record';
                }
                $audioEncounterId = $operation['data']['audio_encounter_id'] ?? null;
                if ($audioEncounterId !== null) {
                    $audioInBatch = collect($operations)
                        ->where('table', 'encounters')
                        ->where('type', 'put')
                        ->contains('id', $audioEncounterId);
                    $ownedAudio = Encounter::query()
                        ->whereKey($audioEncounterId)
                        ->where('user_id', $user->id)
                        ->exists();
                    if (! $audioInBatch && ! $ownedAudio) {
                        return 'inaccessible_record';
                    }
                }
            }
        }

        return null;
    }

    private function validatePairs(array $operations): ?string
    {
        $encounters = collect($operations)->where('table', 'encounters');
        $revisions = collect($operations)->where('table', 'encounter_revisions');

        foreach ($encounters as $encounter) {
            if ($encounter['type'] === 'delete') {
                continue;
            }
            if ($encounter['type'] === 'patch'
                && ! array_key_exists('current_revision_id', $encounter['data'])) {
                continue;
            }
            $revisionId = $encounter['data']['current_revision_id'] ?? null;
            $paired = $revisions->contains(
                fn (array $revision) => $revision['id'] === $revisionId
                    && ($revision['data']['encounter_id'] ?? null) === $encounter['id']
            );
            $existingPair = EncounterRevision::query()
                ->whereKey($revisionId)
                ->where('encounter_id', $encounter['id'])
                ->exists();
            if (! $paired && ! $existingPair) {
                return 'incomplete_revision_pair';
            }
        }

        foreach ($revisions as $revision) {
            $encounterId = $revision['data']['encounter_id'] ?? null;
            if (! $encounters->contains('id', $encounterId) && ! Encounter::whereKey($encounterId)->exists()) {
                return 'incomplete_revision_pair';
            }
        }

        return null;
    }

    private function validateData(array $operations): ?string
    {
        $memorySnapshotKeys = [
            'memory_type',
            'sensitive',
            'recall_enabled',
            'recall_paused',
            'recall_interval_days',
        ];
        foreach ($operations as $operation) {
            if ($operation['type'] === 'delete') {
                if (in_array($operation['table'], ['prayer_votes', 'today_prayers'], true)
                    && $operation['data'] !== []) {
                    return 'invalid_data';
                }

                continue;
            }

            $rules = match ([$operation['table'], $operation['type']]) {
                ['encounters', 'put'] => ['title' => ['required', 'string', 'max:120'], 'body' => ['nullable', 'string', 'max:4000'], 'occurred_on' => ['required', 'date_format:Y-m-d'], 'is_altar' => ['required', 'boolean'], 'current_revision_id' => ['required', 'uuid'], 'archived_at' => ['nullable', 'date'], 'memory_type' => ['sometimes', 'in:encounter,promise,left_behind,revelation,scripture,person,family,lesson,testimony'], 'sensitive' => ['sometimes', 'boolean'], 'recall_enabled' => ['sometimes', 'boolean'], 'recall_paused' => ['sometimes', 'boolean'], 'recall_interval_days' => ['sometimes', 'integer', 'min:1', 'max:365']],
                ['encounters', 'patch'] => ['title' => ['sometimes', 'string', 'max:120'], 'body' => ['sometimes', 'nullable', 'string', 'max:4000'], 'occurred_on' => ['sometimes', 'date_format:Y-m-d'], 'is_altar' => ['sometimes', 'boolean'], 'current_revision_id' => ['sometimes', 'uuid'], 'archived_at' => ['sometimes', 'nullable', 'date'], 'updated_at' => ['sometimes', 'date'], 'memory_type' => ['sometimes', 'in:encounter,promise,left_behind,revelation,scripture,person,family,lesson,testimony'], 'sensitive' => ['sometimes', 'boolean'], 'recall_enabled' => ['sometimes', 'boolean'], 'recall_paused' => ['sometimes', 'boolean'], 'recall_interval_days' => ['sometimes', 'integer', 'min:1', 'max:365']],
                ['encounter_revisions', 'put'] => ['encounter_id' => ['required', 'uuid'], 'title' => ['required', 'string', 'max:120'], 'body' => ['nullable', 'string', 'max:4000'], 'device_id' => ['required', 'string', 'max:120'], 'memory_type' => ['sometimes', 'in:encounter,promise,left_behind,revelation,scripture,person,family,lesson,testimony'], 'sensitive' => ['sometimes', 'boolean'], 'recall_enabled' => ['sometimes', 'boolean'], 'recall_paused' => ['sometimes', 'boolean'], 'recall_interval_days' => ['sometimes', 'integer', 'min:1', 'max:365']],
                ['memory_reflections', 'put'] => ['encounter_id' => ['required', 'uuid'], 'owner_id' => [], 'body' => ['required_without:audio_encounter_id', 'nullable', 'string', 'max:4000'], 'audio_encounter_id' => ['sometimes', 'nullable', 'uuid'], 'local_date' => ['required', 'date_format:Y-m-d'], 'created_at' => ['required', 'date'], 'device_id' => ['required', 'string', 'max:120']],
                ['prayer_votes', 'put'] => ['owner_id' => [], 'prayer_id' => ['required', 'uuid'], 'created_at' => ['sometimes', 'date']],
                ['today_prayers', 'put'] => ['owner_id' => [], 'local_date' => ['required', 'date_format:Y-m-d'], 'prayer_id' => ['sometimes', 'nullable', 'uuid'], 'personal_prayer_id' => ['sometimes', 'nullable', 'uuid'], 'include_action' => ['required', 'boolean'], 'action_completed' => ['required', 'boolean'], 'created_at' => ['sometimes', 'date'], 'updated_at' => ['sometimes', 'date']],
                ['today_prayers', 'patch'] => ['prayer_id' => ['sometimes', 'nullable', 'uuid'], 'personal_prayer_id' => ['sometimes', 'nullable', 'uuid'], 'include_action' => ['sometimes', 'boolean'], 'action_completed' => ['sometimes', 'boolean']],
            };

            if ($this->hasUnexpectedPrayerFields($operation, array_keys($rules))) {
                return 'invalid_data';
            }
            if (in_array($operation['table'], ['encounters', 'encounter_revisions', 'memory_reflections'], true)
                && array_diff(array_keys($operation['data']), array_keys($rules)) !== []) {
                return 'invalid_data';
            }
            if (Validator::make($operation['data'], $rules)->fails()) {
                return 'invalid_data';
            }
            if ($operation['table'] === 'today_prayers') {
                $hasLibrary = ($operation['data']['prayer_id'] ?? null) !== null;
                $hasPersonal = ($operation['data']['personal_prayer_id'] ?? null) !== null;
                $changesSource = array_key_exists('prayer_id', $operation['data'])
                    || array_key_exists('personal_prayer_id', $operation['data']);
                if (($operation['type'] === 'put' || $changesSource)
                    && $hasLibrary === $hasPersonal) {
                    return 'invalid_data';
                }
            }
            if ($operation['type'] === 'patch' && $operation['data'] === []) {
                return 'invalid_data';
            }
        }

        $encounters = collect($operations)->where('table', 'encounters')->where('type', 'put');
        $revisions = collect($operations)->where('table', 'encounter_revisions');
        foreach ($encounters as $encounter) {
            $revision = $revisions->firstWhere('id', $encounter['data']['current_revision_id']);
            if ($revision === null) {
                continue;
            }
            foreach ($memorySnapshotKeys as $key) {
                $default = match ($key) {
                    'memory_type' => 'encounter',
                    'recall_interval_days' => 7,
                    'recall_enabled' => true,
                    default => false,
                };
                if (($encounter['data'][$key] ?? $default) !== ($revision['data'][$key] ?? $default)) {
                    return 'invalid_data';
                }
            }
        }

        return null;
    }

    private function hasUnexpectedPrayerFields(array $operation, array $allowed): bool
    {
        if (! in_array($operation['table'], ['prayer_votes', 'today_prayers'], true)) {
            return false;
        }

        return array_diff(array_keys($operation['data']), $allowed) !== [];
    }

    private function applyEncounter(User $user, array $operation): void
    {
        $encounter = Encounter::find($operation['id']);
        if ($encounter !== null) {
            Gate::forUser($user)->authorize('update', $encounter);
        } else {
            $encounter = new Encounter(['id' => $operation['id'], 'user_id' => $user->id]);
        }

        if ($operation['type'] === 'delete') {
            $encounter->forceFill(['archived_at' => now()])->save();

            return;
        }

        $attributes = $operation['type'] === 'put'
            ? [
                'user_id' => $user->id,
                'title' => $operation['data']['title'],
                'body' => $operation['data']['body'] ?? null,
                'occurred_on' => $operation['data']['occurred_on'],
                'is_altar' => $operation['data']['is_altar'],
                'current_revision_id' => $operation['data']['current_revision_id'],
                'archived_at' => $operation['data']['archived_at'] ?? null,
                'memory_type' => $operation['data']['memory_type'] ?? 'encounter',
                'sensitive' => $operation['data']['sensitive'] ?? false,
                'recall_enabled' => $operation['data']['recall_enabled'] ?? true,
                'recall_paused' => $operation['data']['recall_paused'] ?? false,
                'recall_interval_days' => $operation['data']['recall_interval_days'] ?? 7,
            ]
            : Arr::only($operation['data'], [
                'title',
                'body',
                'occurred_on',
                'is_altar',
                'current_revision_id',
                'archived_at',
                'memory_type',
                'sensitive',
                'recall_enabled',
                'recall_paused',
                'recall_interval_days',
            ]);
        $encounter->forceFill($attributes)->save();
    }

    private function applyRevision(User $user, array $operation): void
    {
        $encounter = Encounter::findOrFail($operation['data']['encounter_id']);
        Gate::forUser($user)->authorize('update', $encounter);
        EncounterRevision::create([
            'id' => $operation['id'],
            'encounter_id' => $encounter->id,
            'user_id' => $user->id,
            'title' => $operation['data']['title'],
            'body' => $operation['data']['body'] ?? null,
            'device_id' => $operation['data']['device_id'],
            'created_at' => now(),
            'memory_type' => $operation['data']['memory_type'] ?? 'encounter',
            'sensitive' => $operation['data']['sensitive'] ?? false,
            'recall_enabled' => $operation['data']['recall_enabled'] ?? true,
            'recall_paused' => $operation['data']['recall_paused'] ?? false,
            'recall_interval_days' => $operation['data']['recall_interval_days'] ?? 7,
        ]);
    }

    private function applyReflection(User $user, array $operation): void
    {
        $encounter = Encounter::findOrFail($operation['data']['encounter_id']);
        Gate::forUser($user)->authorize('update', $encounter);
        $audioEncounterId = $operation['data']['audio_encounter_id'] ?? null;
        if ($audioEncounterId !== null) {
            // Immutable reflection metadata remains valid if its owned source
            // was archived after recording, including in this offline batch.
            $audioEncounter = Encounter::findOrFail($audioEncounterId);
            Gate::forUser($user)->authorize('update', $audioEncounter);
        }
        MemoryReflection::create([
            'id' => $operation['id'],
            'encounter_id' => $encounter->id,
            'user_id' => $user->id,
            'body' => $operation['data']['body'] ?? '',
            'audio_encounter_id' => $audioEncounterId,
            'local_date' => $operation['data']['local_date'],
            'created_at' => $operation['data']['created_at'],
            'device_id' => $operation['data']['device_id'],
        ]);
    }

    /**
     * @param  array<int, array<string, mixed>>  $operations
     * @return array{contexts: array<string, array<string, mixed>>, prayer_ids: array<int, string>, personal_prayer_ids: array<int, string>}
     */
    private function preparePrayerMutations(User $user, array $operations): array
    {
        $contexts = [];
        $prayerIds = [];
        $personalPrayerIds = [];
        $states = [
            PrayerRecordAlias::TYPE_VOTE => [],
            PrayerRecordAlias::TYPE_TODAY => [],
        ];
        $aliases = [
            PrayerRecordAlias::TYPE_VOTE => [],
            PrayerRecordAlias::TYPE_TODAY => [],
        ];
        $semantics = [
            PrayerRecordAlias::TYPE_VOTE => [],
            PrayerRecordAlias::TYPE_TODAY => [],
        ];

        $loadCanonical = function (string $recordType, string $canonicalId) use ($user, &$semantics, &$states): ?array {
            if (array_key_exists($canonicalId, $states[$recordType])) {
                return $states[$recordType][$canonicalId];
            }

            $model = $recordType === PrayerRecordAlias::TYPE_VOTE
                ? PrayerVote::class
                : TodayPrayer::class;
            $record = $model::query()
                ->where('user_id', $user->id)
                ->whereKey($canonicalId)
                ->first();
            $states[$recordType][$canonicalId] = $record === null
                ? null
                : [
                    'canonical_id' => $record->id,
                    'prayer_id' => $record->prayer_id,
                    'personal_prayer_id' => $recordType === PrayerRecordAlias::TYPE_TODAY
                        ? $record->personal_prayer_id
                        : null,
                    'semantic_key' => $recordType === PrayerRecordAlias::TYPE_VOTE
                        ? $record->prayer_id
                        : $record->local_date->format('Y-m-d'),
                ];
            $semanticKey = $states[$recordType][$canonicalId]['semantic_key'] ?? null;
            if ($semanticKey !== null && ! array_key_exists($semanticKey, $semantics[$recordType])) {
                $semantics[$recordType][$semanticKey] = $canonicalId;
            }

            return $states[$recordType][$canonicalId];
        };

        foreach ($operations as $operation) {
            $recordType = $operation['table'] === 'prayer_votes'
                ? PrayerRecordAlias::TYPE_VOTE
                : PrayerRecordAlias::TYPE_TODAY;
            $incomingId = $operation['id'];
            $state = $loadCanonical($recordType, $incomingId);

            if ($state === null) {
                if (! array_key_exists($incomingId, $aliases[$recordType])) {
                    $aliases[$recordType][$incomingId] = PrayerRecordAlias::query()
                        ->where('user_id', $user->id)
                        ->where('record_type', $recordType)
                        ->where('alias_id', $incomingId)
                        ->value('canonical_id');
                }

                $aliasCanonicalId = $aliases[$recordType][$incomingId];
                if ($aliasCanonicalId !== null) {
                    $state = $loadCanonical($recordType, $aliasCanonicalId);
                }
            }

            if ($state === null && $operation['type'] === 'put') {
                $semanticKey = $operation['table'] === 'prayer_votes'
                    ? $operation['data']['prayer_id']
                    : $operation['data']['local_date'];
                if (! array_key_exists($semanticKey, $semantics[$recordType])) {
                    $semanticRecord = $operation['table'] === 'prayer_votes'
                        ? PrayerVote::query()
                            ->where('user_id', $user->id)
                            ->where('prayer_id', $semanticKey)
                            ->first()
                        : TodayPrayer::query()
                            ->where('user_id', $user->id)
                            ->whereDate('local_date', $semanticKey)
                            ->first();
                    $semantics[$recordType][$semanticKey] = $semanticRecord?->id;
                    if ($semanticRecord !== null) {
                        $states[$recordType][$semanticRecord->id] = [
                            'canonical_id' => $semanticRecord->id,
                            'prayer_id' => $semanticRecord->prayer_id,
                            'personal_prayer_id' => $semanticRecord->personal_prayer_id,
                            'semantic_key' => $semanticKey,
                        ];
                    }
                }

                $semanticCanonicalId = $semantics[$recordType][$semanticKey];
                if ($semanticCanonicalId !== null) {
                    $state = $loadCanonical($recordType, $semanticCanonicalId);
                }
            }

            $canonicalId = $state['canonical_id'] ?? null;
            $currentPrayerId = $state['prayer_id'] ?? null;
            $requestedPrayerId = $operation['data']['prayer_id'] ?? null;
            foreach ([$currentPrayerId, $requestedPrayerId] as $prayerId) {
                if ($prayerId !== null) {
                    $prayerIds[] = $prayerId;
                }
            }
            $currentPersonalPrayerId = $state['personal_prayer_id'] ?? null;
            $requestedPersonalPrayerId = $operation['data']['personal_prayer_id'] ?? null;
            foreach ([$currentPersonalPrayerId, $requestedPersonalPrayerId] as $personalPrayerId) {
                if ($personalPrayerId !== null) {
                    $personalPrayerIds[] = $personalPrayerId;
                }
            }

            $contexts[$operation['operation_id']] = [
                'record_type' => $recordType,
                'canonical_id' => $canonicalId,
                'current_prayer_id' => $currentPrayerId,
                'current_personal_prayer_id' => $currentPersonalPrayerId,
            ];

            if ($operation['type'] === 'put') {
                $canonicalId ??= $incomingId;
                $oldSemanticKey = $state['semantic_key'] ?? null;
                $newSemanticKey = $operation['table'] === 'prayer_votes'
                    ? ($state['semantic_key'] ?? $operation['data']['prayer_id'])
                    : $operation['data']['local_date'];
                if ($oldSemanticKey !== null
                    && $oldSemanticKey !== $newSemanticKey
                    && ($semantics[$recordType][$oldSemanticKey] ?? null) === $canonicalId) {
                    $semantics[$recordType][$oldSemanticKey] = null;
                }
                $states[$recordType][$canonicalId] = [
                    'canonical_id' => $canonicalId,
                    'prayer_id' => $operation['table'] === 'prayer_votes' && $state !== null
                        ? $state['prayer_id']
                        : ($operation['data']['prayer_id'] ?? null),
                    'personal_prayer_id' => $operation['table'] === 'today_prayers'
                        ? ($operation['data']['personal_prayer_id'] ?? null)
                        : null,
                    'semantic_key' => $newSemanticKey,
                ];
                $semantics[$recordType][$newSemanticKey] = $canonicalId;
                if ($incomingId !== $canonicalId) {
                    $aliases[$recordType][$incomingId] = $canonicalId;
                }
            } elseif ($operation['type'] === 'patch' && $state !== null) {
                if (array_key_exists('prayer_id', $operation['data'])) {
                    $states[$recordType][$canonicalId]['prayer_id'] = $operation['data']['prayer_id'];
                }
                if (array_key_exists('personal_prayer_id', $operation['data'])) {
                    $states[$recordType][$canonicalId]['personal_prayer_id'] = $operation['data']['personal_prayer_id'];
                }
            } elseif ($operation['type'] === 'delete' && $state !== null) {
                $semanticKey = $state['semantic_key'];
                if (($semantics[$recordType][$semanticKey] ?? $canonicalId) === $canonicalId) {
                    $semantics[$recordType][$semanticKey] = null;
                }
                $states[$recordType][$canonicalId] = null;
                foreach ($aliases[$recordType] as $aliasId => $aliasCanonicalId) {
                    if ($aliasCanonicalId === $canonicalId) {
                        $aliases[$recordType][$aliasId] = null;
                    }
                }
            }
        }

        $prayerIds = array_values(array_unique($prayerIds));
        sort($prayerIds, SORT_STRING);
        $personalPrayerIds = array_values(array_unique($personalPrayerIds));
        sort($personalPrayerIds, SORT_STRING);

        return [
            'contexts' => $contexts,
            'prayer_ids' => $prayerIds,
            'personal_prayer_ids' => $personalPrayerIds,
        ];
    }

    /**
     * @param  array<int, string>  $prayerIds
     * @return Collection<string, LibraryPrayer>
     */
    private function lockPrayers(array $prayerIds): Collection
    {
        if ($prayerIds === []) {
            return collect();
        }

        return LibraryPrayer::query()
            ->whereIn('id', $prayerIds)
            ->orderBy('id')
            ->lockForUpdate()
            ->get()
            ->keyBy('id');
    }

    /**
     * @param  array<int, string>  $prayerIds
     * @return Collection<string, PersonalPrayer>
     */
    private function lockPersonalPrayers(array $prayerIds): Collection
    {
        if ($prayerIds === []) {
            return collect();
        }

        return PersonalPrayer::query()
            ->whereIn('id', $prayerIds)
            ->orderBy('id')
            ->lockForUpdate()
            ->get()
            ->keyBy('id');
    }

    /**
     * @param  array<int, array<string, mixed>>  $operations
     * @param  array<string, array<string, mixed>>  $contexts
     * @param  Collection<string, LibraryPrayer>  $lockedPrayers
     * @param  Collection<string, PersonalPrayer>  $lockedPersonalPrayers
     * @param  array<int, string>  $pendingPersonalPrayerIds
     */
    private function validatePreparedPrayerMutations(
        User $user,
        array $operations,
        array $contexts,
        Collection $lockedPrayers,
        Collection $lockedPersonalPrayers,
        array $pendingPersonalPrayerIds,
    ): ?string {
        foreach ($operations as $operation) {
            $context = $contexts[$operation['operation_id']];
            if ($operation['table'] === 'today_prayers'
                && $operation['type'] === 'patch'
                && $context['canonical_id'] === null) {
                return 'inaccessible_record';
            }
            if ($operation['type'] === 'delete') {
                continue;
            }

            $personalPrayerId = array_key_exists('personal_prayer_id', $operation['data'])
                ? $operation['data']['personal_prayer_id']
                : $context['current_personal_prayer_id'];
            if ($operation['table'] === 'today_prayers' && $personalPrayerId !== null) {
                $personalPrayer = $lockedPersonalPrayers->get($personalPrayerId);
                $isPendingOwnedPrayer = in_array(
                    $personalPrayerId,
                    $pendingPersonalPrayerIds,
                    true,
                );
                if (! $isPendingOwnedPrayer && ($personalPrayer === null
                    || $personalPrayer->user_id !== $user->id
                    || $personalPrayer->archived_at !== null)) {
                    return 'invalid_prayer';
                }

                continue;
            }

            $prayerId = array_key_exists('prayer_id', $operation['data'])
                ? $operation['data']['prayer_id']
                : $context['current_prayer_id'];
            $prayer = $lockedPrayers->get($prayerId);
            if ($prayer === null
                || $prayer->published_at === null
                || $prayer->archived_at !== null) {
                return 'invalid_prayer';
            }
        }

        return null;
    }

    /** @param array<string, mixed> $context */
    private function applyPrayerVote(User $user, array $operation, array $context): void
    {
        $vote = $context['canonical_id'] === null
            ? null
            : PrayerVote::query()
                ->where('user_id', $user->id)
                ->whereKey($context['canonical_id'])
                ->lockForUpdate()
                ->first();

        if ($operation['type'] === 'delete') {
            if ($vote !== null) {
                $canonicalId = $vote->id;
                $vote->delete();
                $this->deletePrayerAliases(
                    $user,
                    PrayerRecordAlias::TYPE_VOTE,
                    $canonicalId,
                );
            }

            return;
        }

        if ($vote === null) {
            $vote = PrayerVote::create([
                'id' => $operation['id'],
                'user_id' => $user->id,
                'prayer_id' => $operation['data']['prayer_id'],
                'created_at' => now(),
            ]);
        }

        $this->storePrayerAlias($user, $context['record_type'], $operation['id'], $vote->id);
    }

    /** @param array<string, mixed> $context */
    private function applyTodayPrayer(User $user, array $operation, array $context): void
    {
        $selection = $context['canonical_id'] === null
            ? null
            : TodayPrayer::query()
                ->where('user_id', $user->id)
                ->whereKey($context['canonical_id'])
                ->lockForUpdate()
                ->first();

        if ($operation['type'] === 'delete') {
            if ($selection !== null) {
                $canonicalId = $selection->id;
                $selection->delete();
                $this->deletePrayerAliases(
                    $user,
                    PrayerRecordAlias::TYPE_TODAY,
                    $canonicalId,
                );
            }

            return;
        }

        if ($selection === null) {
            $selection = new TodayPrayer([
                'id' => $operation['id'],
                'user_id' => $user->id,
            ]);
        }

        $attributes = $operation['type'] === 'put'
            ? Arr::only($operation['data'], [
                'local_date',
                'prayer_id',
                'personal_prayer_id',
                'include_action',
                'action_completed',
            ])
            : Arr::only($operation['data'], [
                'prayer_id',
                'personal_prayer_id',
                'include_action',
                'action_completed',
            ]);
        if (array_key_exists('prayer_id', $attributes)
            && $attributes['prayer_id'] !== null) {
            $attributes['personal_prayer_id'] = null;
        }
        if (array_key_exists('personal_prayer_id', $attributes)
            && $attributes['personal_prayer_id'] !== null) {
            $attributes['prayer_id'] = null;
        }
        $selection->forceFill($attributes)->save();
        $this->storePrayerAlias($user, $context['record_type'], $operation['id'], $selection->id);
    }

    private function storePrayerAlias(
        User $user,
        string $recordType,
        string $aliasId,
        string $canonicalId,
    ): void {
        if ($aliasId === $canonicalId) {
            return;
        }

        PrayerRecordAlias::query()->updateOrCreate([
            'user_id' => $user->id,
            'record_type' => $recordType,
            'alias_id' => $aliasId,
        ], [
            'canonical_id' => $canonicalId,
        ]);
    }

    private function deletePrayerAliases(User $user, string $recordType, string $canonicalId): void
    {
        PrayerRecordAlias::query()
            ->where('user_id', $user->id)
            ->where('record_type', $recordType)
            ->where('canonical_id', $canonicalId)
            ->delete();
    }

    private function isConstraintViolation(QueryException $exception): bool
    {
        $sqlState = (string) ($exception->errorInfo[0] ?? $exception->getCode());

        return str_starts_with($sqlState, '23');
    }

    protected function storeSyncOperation(User $user, array $operation): void
    {
        SyncOperation::create([
            'operation_id' => $operation['operation_id'],
            'user_id' => $user->id,
            'table_name' => $operation['table'],
            'record_id' => $operation['id'],
            'operation_type' => $operation['type'],
            'payload_hash' => $this->fingerprint($operation),
            'created_at' => now(),
        ]);
    }

    protected function concurrentReplayResult(
        User $user,
        Collection $pending,
        int $duplicates,
        int $total,
    ): ?array {
        $stored = SyncOperation::query()
            ->whereIn('operation_id', $pending->pluck('operation_id'))
            ->get()
            ->keyBy('operation_id');

        $same = $pending->every(function (array $operation) use ($stored, $user): bool {
            $existing = $stored->get($operation['operation_id']);

            return $existing !== null && $this->isSameOperation($existing, $user, $operation);
        });

        return $same
            ? $this->result($total, 0, $duplicates + $pending->count())
            : null;
    }

    private function result(int $accepted, int $rejected, int $duplicates, ?string $code = null): array
    {
        return array_filter([
            'accepted' => $accepted,
            'rejected' => $rejected,
            'duplicates' => $duplicates,
            'code' => $code,
        ], fn ($value) => $value !== null);
    }

    private function isSameOperation(
        SyncOperation $existing,
        User $user,
        array $operation,
    ): bool {
        if ($existing->operation_type === null || $existing->payload_hash === null) {
            return false;
        }

        return $existing->user_id === $user->id
            && $existing->table_name === $operation['table']
            && $existing->record_id === $operation['id']
            && $existing->operation_type === $operation['type']
            && hash_equals($existing->payload_hash, $this->fingerprint($operation));
    }

    private function fingerprint(array $operation): string
    {
        $canonical = $this->canonicalize([
            'table' => $operation['table'],
            'type' => $operation['type'],
            'id' => $operation['id'],
            'data' => $operation['data'],
        ]);

        return hash('sha256', json_encode($canonical, JSON_THROW_ON_ERROR));
    }

    private function canonicalize(array $value): array
    {
        if (! array_is_list($value)) {
            ksort($value);
        }

        return array_map(
            fn (mixed $item) => is_array($item) ? $this->canonicalize($item) : $item,
            $value,
        );
    }
}

/** A domain rejection must roll back all writes in the offline batch. */
final class SyncMutationRejected extends \RuntimeException
{
    public function __construct(public readonly string $syncCode)
    {
        parent::__construct($syncCode);
    }
}
