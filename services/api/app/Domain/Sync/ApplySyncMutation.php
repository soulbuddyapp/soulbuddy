<?php

namespace App\Domain\Sync;

use App\Models\Encounter;
use App\Models\EncounterRevision;
use App\Models\LibraryPrayer;
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

        $validationError = $this->validateData($pending->all());
        if ($validationError !== null) {
            return $this->result($duplicates, $pending->count(), $duplicates, $validationError);
        }

        $targetError = $this->validateTargets($user, $pending->all());
        if ($targetError !== null) {
            return $this->result($duplicates, $pending->count(), $duplicates, $targetError);
        }

        $pairError = $this->validatePairs($pending->all());
        if ($pairError !== null) {
            return $this->result($duplicates, $pending->count(), $duplicates, $pairError);
        }

        try {
            DB::transaction(function () use ($user, $pending) {
                foreach ($pending->sortBy(fn (array $operation) => $operation['table'] === 'encounters' ? 0 : 1) as $operation) {
                    match ($operation['table']) {
                        'encounters' => $this->applyEncounter($user, $operation),
                        'encounter_revisions' => $this->applyRevision($user, $operation),
                        'prayer_votes' => $this->applyPrayerVote($user, $operation),
                        'today_prayers' => $this->applyTodayPrayer($user, $operation),
                    };

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
            if ($operation['table'] === 'prayer_votes') {
                $error = $this->validatePrayerVoteTarget($user, $operation);
                if ($error !== null) {
                    return $error;
                }
            }
            if ($operation['table'] === 'today_prayers') {
                $error = $this->validateTodayPrayerTarget($user, $operation);
                if ($error !== null) {
                    return $error;
                }
            }
        }

        return null;
    }

    private function validatePrayerVoteTarget(User $user, array $operation): ?string
    {
        $vote = PrayerVote::find($operation['id']);
        if ($vote !== null && $vote->user_id !== $user->id) {
            return 'inaccessible_record';
        }
        if ($operation['type'] === 'delete') {
            return null;
        }

        $prayerId = $operation['data']['prayer_id'];

        return $this->isPublishedPrayer($prayerId) ? null : 'invalid_prayer';
    }

    private function validateTodayPrayerTarget(User $user, array $operation): ?string
    {
        $selection = TodayPrayer::find($operation['id']);
        if ($selection !== null && $selection->user_id !== $user->id) {
            return 'inaccessible_record';
        }
        if ($operation['type'] === 'delete') {
            return null;
        }
        if ($operation['type'] === 'patch' && $selection === null) {
            return 'inaccessible_record';
        }

        $prayerId = $operation['data']['prayer_id'] ?? $selection->prayer_id;

        return $this->isPublishedPrayer($prayerId) ? null : 'invalid_prayer';
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
                ['prayer_votes', 'put'] => ['owner_id' => ['sometimes', 'uuid'], 'prayer_id' => ['required', 'uuid'], 'created_at' => ['sometimes', 'date']],
                ['today_prayers', 'put'] => ['owner_id' => ['sometimes', 'uuid'], 'local_date' => ['required', 'date_format:Y-m-d'], 'prayer_id' => ['required', 'uuid'], 'include_action' => ['required', 'boolean'], 'action_completed' => ['required', 'boolean'], 'created_at' => ['sometimes', 'date'], 'updated_at' => ['sometimes', 'date']],
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

    private function applyPrayerVote(User $user, array $operation): void
    {
        $vote = PrayerVote::find($operation['id']);
        $prayerId = $vote?->prayer_id ?? $operation['data']['prayer_id'] ?? null;
        $prayer = $prayerId === null
            ? null
            : LibraryPrayer::query()->lockForUpdate()->findOrFail($prayerId);

        if ($operation['type'] === 'put' && $vote === null) {
            $vote = PrayerVote::query()
                ->where('user_id', $user->id)
                ->where('prayer_id', $operation['data']['prayer_id'])
                ->lockForUpdate()
                ->first();
        }

        if ($operation['type'] === 'delete') {
            $vote?->delete();
        } elseif ($vote === null) {
            PrayerVote::create([
                'id' => $operation['id'],
                'user_id' => $user->id,
                'prayer_id' => $operation['data']['prayer_id'],
                'created_at' => now(),
            ]);
        }

        if ($prayer !== null) {
            $prayer->forceFill([
                'helpful_count' => PrayerVote::where('prayer_id', $prayer->id)->count(),
            ])->save();
        }
    }

    private function applyTodayPrayer(User $user, array $operation): void
    {
        if ($operation['type'] === 'put') {
            User::query()->whereKey($user->id)->lockForUpdate()->firstOrFail();
            $selection = TodayPrayer::query()
                ->where('user_id', $user->id)
                ->where(fn ($query) => $query
                    ->where('id', $operation['id'])
                    ->orWhereDate('local_date', $operation['data']['local_date']))
                ->lockForUpdate()
                ->first();
        } else {
            $selection = TodayPrayer::find($operation['id']);
        }

        if ($operation['type'] === 'delete') {
            $selection?->delete();

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
    }

    private function isPublishedPrayer(string $prayerId): bool
    {
        return LibraryPrayer::query()
            ->whereKey($prayerId)
            ->whereNotNull('published_at')
            ->whereNull('archived_at')
            ->exists();
    }

    private function isConstraintViolation(QueryException $exception): bool
    {
        $sqlState = (string) ($exception->errorInfo[0] ?? $exception->getCode());

        return str_starts_with($sqlState, '23');
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
