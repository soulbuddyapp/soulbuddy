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
    ];

    public function __construct(
        private readonly GoalSyncMutationValidator $validator,
        private readonly GoalSyncMutationWriter $writer,
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

                if (($error = $this->validator->validate($user, $pending)) !== null) {
                    return $error;
                }

                $this->writer->apply($user, $pending);
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
