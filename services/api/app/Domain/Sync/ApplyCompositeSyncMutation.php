<?php

namespace App\Domain\Sync;

use App\Models\SyncOperation;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use RuntimeException;

final class ApplyCompositeSyncMutation
{
    public function __construct(
        private readonly ApplySyncMutation $legacy,
        private readonly ApplyGoalSyncMutation $goals,
    ) {}

    /** @param array<int, array<string, mixed>> $operations */
    public function apply(User $user, array $operations): array
    {
        $goalOperations = collect($operations)
            ->filter(fn (array $operation): bool => ApplyGoalSyncMutation::supports($operation['table']))
            ->values()
            ->all();
        $legacyOperations = collect($operations)
            ->reject(fn (array $operation): bool => ApplyGoalSyncMutation::supports($operation['table']))
            ->values()
            ->all();

        if ($goalOperations === []) {
            return $this->legacy->apply($user, $legacyOperations);
        }
        if ($legacyOperations === []) {
            return $this->goals->apply($user, $goalOperations);
        }

        $preflight = $this->preflight($user, $operations);
        if ($preflight['conflict']) {
            return $this->result(
                $preflight['duplicates'],
                count($operations) - $preflight['duplicates'],
                $preflight['duplicates'],
                'operation_conflict',
            );
        }

        try {
            DB::transaction(function () use ($user, $legacyOperations, $goalOperations): void {
                $this->requireAccepted($this->legacy->apply($user, $legacyOperations));

                // Apply legacy writes first so a Goal in the same offline batch
                // may link to a prayer, encounter or Voice Tablet it just created.
                $this->requireAccepted($this->goals->apply($user, $goalOperations));
            });
        } catch (MixedSyncMutationRejected $rejection) {
            return $this->result(
                $preflight['duplicates'],
                count($operations) - $preflight['duplicates'],
                $preflight['duplicates'],
                $rejection->syncCode,
            );
        }

        return $this->result(count($operations), 0, $preflight['duplicates']);
    }

    /** @param array<string, mixed> $result */
    private function requireAccepted(array $result): void
    {
        if (($result['rejected'] ?? 0) === 0) {
            return;
        }

        throw new MixedSyncMutationRejected(
            is_string($result['code'] ?? null) ? $result['code'] : 'rejected',
        );
    }

    /** @return array{duplicates: int, conflict: bool} */
    private function preflight(User $user, array $operations): array
    {
        $stored = SyncOperation::query()
            ->whereIn('operation_id', collect($operations)->pluck('operation_id'))
            ->get()
            ->keyBy('operation_id');
        $duplicates = 0;
        $conflict = false;

        foreach ($operations as $operation) {
            $existing = $stored->get($operation['operation_id']);
            if ($existing === null) {
                continue;
            }
            if (SyncOperationIdentity::matches($existing, $user, $operation)) {
                $duplicates++;
            } else {
                $conflict = true;
            }
        }

        return ['duplicates' => $duplicates, 'conflict' => $conflict];
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

final class MixedSyncMutationRejected extends RuntimeException
{
    public function __construct(public readonly string $syncCode)
    {
        parent::__construct($syncCode);
    }
}
