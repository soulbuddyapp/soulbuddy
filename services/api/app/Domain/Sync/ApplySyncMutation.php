<?php

namespace App\Domain\Sync;

use App\Models\Encounter;
use App\Models\EncounterRevision;
use App\Models\LibraryPrayer;
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
        'prayer_votes',
        'today_prayers',
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
            ->whereIn('table', ['encounters', 'encounter_revisions'])
            ->all();
        $prayerOperations = $pending
            ->whereIn('table', ['prayer_votes', 'today_prayers'])
            ->all();

        $encounterTargetError = $this->validateTargets($user, $encounterOperations);
        if ($encounterTargetError !== null) {
            return $this->result($duplicates, $pending->count(), $duplicates, $encounterTargetError);
        }

        $pairError = $this->validatePairs($encounterOperations);
        if ($pairError !== null) {
            return $this->result($duplicates, $pending->count(), $duplicates, $pairError);
        }

        foreach ([$encounterOperations, $prayerOperations] as $domainOperations) {
            $validationError = $this->validateData($domainOperations);
            if ($validationError !== null) {
                return $this->result($duplicates, $pending->count(), $duplicates, $validationError);
            }
        }

        try {
            $prayerError = DB::transaction(function () use ($user, $pending, $prayerOperations): ?string {
                User::query()->whereKey($user->id)->lockForUpdate()->firstOrFail();
                $prayerContexts = [];
                if ($prayerOperations !== []) {
                    $prepared = $this->preparePrayerMutations($user, $prayerOperations);
                    $prayerContexts = $prepared['contexts'];
                    $lockedPrayers = $this->lockPrayers($prepared['prayer_ids']);
                    $prayerError = $this->validatePreparedPrayerMutations(
                        $prayerOperations,
                        $prayerContexts,
                        $lockedPrayers,
                    );
                    if ($prayerError !== null) {
                        return $prayerError;
                    }
                }

                foreach ($pending->sortBy(fn (array $operation) => $operation['table'] === 'encounters' ? 0 : 1) as $operation) {
                    match ($operation['table']) {
                        'encounters' => $this->applyEncounter($user, $operation),
                        'encounter_revisions' => $this->applyRevision($user, $operation),
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

                    $this->storeSyncOperation($user, $operation);
                }

                return null;
            });
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

        if ($prayerError !== null) {
            return $this->result($duplicates, $pending->count(), $duplicates, $prayerError);
        }

        return $this->result(count($operations), 0, $duplicates);
    }

    private function validateOperationKinds(array $operations): ?string
    {
        foreach ($operations as $operation) {
            if ($operation['table'] === 'encounter_revisions' && $operation['type'] !== 'put') {
                return 'immutable_revision';
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
        foreach ($operations as $operation) {
            if ($operation['type'] === 'delete') {
                if (in_array($operation['table'], ['prayer_votes', 'today_prayers'], true)
                    && $operation['data'] !== []) {
                    return 'invalid_data';
                }

                continue;
            }

            $rules = match ([$operation['table'], $operation['type']]) {
                ['encounters', 'put'] => ['title' => ['required', 'string', 'max:120'], 'body' => ['nullable', 'string', 'max:4000'], 'occurred_on' => ['required', 'date_format:Y-m-d'], 'is_altar' => ['required', 'boolean'], 'current_revision_id' => ['required', 'uuid'], 'archived_at' => ['nullable', 'date']],
                ['encounters', 'patch'] => ['title' => ['sometimes', 'string', 'max:120'], 'body' => ['sometimes', 'nullable', 'string', 'max:4000'], 'occurred_on' => ['sometimes', 'date_format:Y-m-d'], 'is_altar' => ['sometimes', 'boolean'], 'current_revision_id' => ['sometimes', 'uuid'], 'archived_at' => ['sometimes', 'nullable', 'date'], 'updated_at' => ['sometimes', 'date']],
                ['encounter_revisions', 'put'] => ['encounter_id' => ['required', 'uuid'], 'title' => ['required', 'string', 'max:120'], 'body' => ['nullable', 'string', 'max:4000'], 'device_id' => ['required', 'string', 'max:120']],
                ['prayer_votes', 'put'] => ['owner_id' => [], 'prayer_id' => ['required', 'uuid'], 'created_at' => ['sometimes', 'date']],
                ['today_prayers', 'put'] => ['owner_id' => [], 'local_date' => ['required', 'date_format:Y-m-d'], 'prayer_id' => ['required', 'uuid'], 'include_action' => ['required', 'boolean'], 'action_completed' => ['required', 'boolean'], 'created_at' => ['sometimes', 'date'], 'updated_at' => ['sometimes', 'date']],
                ['today_prayers', 'patch'] => ['prayer_id' => ['sometimes', 'uuid'], 'include_action' => ['sometimes', 'boolean'], 'action_completed' => ['sometimes', 'boolean']],
            };

            if ($this->hasUnexpectedPrayerFields($operation, array_keys($rules))) {
                return 'invalid_data';
            }
            if (Validator::make($operation['data'], $rules)->fails()) {
                return 'invalid_data';
            }
            if ($operation['type'] === 'patch' && $operation['data'] === []) {
                return 'invalid_data';
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
            ]
            : Arr::only($operation['data'], [
                'title',
                'body',
                'occurred_on',
                'is_altar',
                'current_revision_id',
                'archived_at',
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
        ]);
    }

    /**
     * @param  array<int, array<string, mixed>>  $operations
     * @return array{contexts: array<string, array<string, mixed>>, prayer_ids: array<int, string>}
     */
    private function preparePrayerMutations(User $user, array $operations): array
    {
        $contexts = [];
        $prayerIds = [];
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

            $contexts[$operation['operation_id']] = [
                'record_type' => $recordType,
                'canonical_id' => $canonicalId,
                'current_prayer_id' => $currentPrayerId,
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
                        : $operation['data']['prayer_id'],
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

        return ['contexts' => $contexts, 'prayer_ids' => $prayerIds];
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
     * @param  array<int, array<string, mixed>>  $operations
     * @param  array<string, array<string, mixed>>  $contexts
     * @param  Collection<string, LibraryPrayer>  $lockedPrayers
     */
    private function validatePreparedPrayerMutations(
        array $operations,
        array $contexts,
        Collection $lockedPrayers,
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

            $prayerId = $operation['data']['prayer_id'] ?? $context['current_prayer_id'];
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
                'include_action',
                'action_completed',
            ])
            : Arr::only($operation['data'], [
                'prayer_id',
                'include_action',
                'action_completed',
            ]);
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
