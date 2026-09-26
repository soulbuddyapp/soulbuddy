<?php

namespace App\Domain\Sync;

use App\Models\SyncOperation;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

final class ApplyGoalSyncMutation
{
    private const TABLES = [
        'goals',
        'goal_revisions',
        'goal_links',
        'goal_actions',
        'goal_action_events',
        'goal_guard_selections',
        'commitments',
        'commitment_practices',
        'commitment_declarations',
        'commitment_meditation_plans',
        'commitment_preparation_cycles',
        'commitment_meditation_sessions',
    ];

    public function __construct(
        private readonly GoalSyncMutationValidator $validator,
        private readonly GoalSyncMutationWriter $writer,
        private readonly GoalGuardSelectionSyncMutation $guards,
        private readonly CommitmentSyncMutationValidator $commitments,
        private readonly CommitmentSyncMutationWriter $commitmentWriter,
    ) {}

    public static function supports(string $table): bool
    {
        return in_array($table, self::TABLES, true);
    }

    /** @param array<int, array<string, mixed>> $operations */
    public function apply(User $user, array $operations): array
    {
        $stored = SyncOperation::query()
            ->whereIn('operation_id', collect($operations)->pluck('operation_id'))
            ->get()
            ->keyBy('operation_id');
        $duplicates = 0;
        $pending = collect();
        $hasConflict = false;

        foreach ($operations as $operation) {
            $existing = $stored->get($operation['operation_id']);
            if ($existing === null) {
                $pending->push($operation);
            } elseif (SyncOperationIdentity::matches($existing, $user, $operation)) {
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
        if ($pending->contains(
            fn (array $operation): bool => ! self::supports($operation['table']),
        )) {
            return $this->result(
                $duplicates,
                $pending->count(),
                $duplicates,
                'unsupported_table',
            );
        }

        try {
            $error = DB::transaction(function () use ($user, $pending): ?string {
                User::query()->whereKey($user->id)->lockForUpdate()->firstOrFail();

                $guardOperations = $pending
                    ->where('table', 'goal_guard_selections')
                    ->values();
                $coreOperations = $pending
                    ->reject(
                        fn (array $operation): bool => $operation['table'] === 'goal_guard_selections'
                            || CommitmentSyncMutationValidator::supports($operation['table']),
                    )
                    ->map($this->normalizeNullablePutFields(...))
                    ->values();

                $commitmentOperations = $pending->filter(fn (array $operation): bool => CommitmentSyncMutationValidator::supports($operation['table']))->map($this->normalizeNullablePutFields(...))->values();

                if ($coreOperations->isNotEmpty()
                    && ($error = $this->validator->validate($user, $coreOperations)) !== null) {
                    return $error;
                }
                if ($guardOperations->isNotEmpty()
                    && ($error = $this->guards->validate($user, $pending, $guardOperations)) !== null) {
                    return $error;
                }
                if (($error = $this->commitments->validate($user, $pending, $commitmentOperations)) !== null) {
                    return $error;
                }

                if ($coreOperations->isNotEmpty()) {
                    $this->writer->apply($user, $coreOperations);
                }
                if ($guardOperations->isNotEmpty()) {
                    $this->guards->apply($user, $guardOperations);
                }
                $this->commitmentWriter->apply($user, $commitmentOperations);
                foreach ($pending as $operation) {
                    SyncOperation::create([
                        'operation_id' => $operation['operation_id'],
                        'user_id' => $user->id,
                        'table_name' => $operation['table'],
                        'record_id' => $operation['id'],
                        'operation_type' => $operation['type'],
                        'payload_hash' => SyncOperationIdentity::fingerprint($operation),
                        'created_at' => now(),
                    ]);
                }

                return null;
            });
        } catch (QueryException $exception) {
            if (! $this->isConstraintViolation($exception)) {
                throw $exception;
            }

            $replay = $this->concurrentReplayResult(
                $user,
                $pending,
                $duplicates,
                count($operations),
            );

            return $replay ?? $this->result(
                $duplicates,
                $pending->count(),
                $duplicates,
                'conflict',
            );
        }

        return $error === null
            ? $this->result(count($operations), 0, $duplicates)
            : $this->result(
                $duplicates,
                $pending->count(),
                $duplicates,
                $error,
            );
    }

    private function concurrentReplayResult(
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

            return $existing !== null
                && SyncOperationIdentity::matches($existing, $user, $operation);
        });

        return $same
            ? $this->result($total, 0, $duplicates + $pending->count())
            : null;
    }

    /** PowerSync PUTs omit SQL NULLs; preserve the original payload for replay hashes. */
    private function normalizeNullablePutFields(array $operation): array
    {
        if ($operation['type'] !== 'put') {
            return $operation;
        }
        $nullable = match ($operation['table']) {
            'goals' => ['starter_key', 'archived_at'],
            'goal_revisions' => ['current_situation', 'why_it_matters'],
            'goal_links' => ['personal_prayer_id', 'library_prayer_id', 'encounter_id', 'voice_tablet_id', 'circle_id', 'translation', 'book', 'chapter', 'first_verse', 'last_verse', 'archived_at'],
            'goal_actions' => ['local_time', 'timezone', 'once_at', 'weekdays_mask', 'archived_at'],
            'commitment_practices' => ['suggestion_id'],
            'commitment_meditation_plans' => ['weekdays_mask'],
            default => [],
        };
        $operation['data'] += array_fill_keys($nullable, null);

        return $operation;
    }

    private function isConstraintViolation(QueryException $exception): bool
    {
        $sqlState = (string) ($exception->errorInfo[0] ?? $exception->getCode());

        return str_starts_with($sqlState, '23');
    }

    private function result(int $accepted, int $rejected, int $duplicates, ?string $code = null): array
    {
        return array_filter([
            'accepted' => $accepted,
            'rejected' => $rejected,
            'duplicates' => $duplicates,
            'code' => $code,
        ], fn (mixed $value): bool => $value !== null);
    }
}
