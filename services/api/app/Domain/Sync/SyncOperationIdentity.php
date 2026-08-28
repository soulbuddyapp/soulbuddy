<?php

namespace App\Domain\Sync;

use App\Models\SyncOperation;
use App\Models\User;

final class SyncOperationIdentity
{
    public static function matches(SyncOperation $existing, User $user, array $operation): bool
    {
        return $existing->operation_type !== null
            && $existing->payload_hash !== null
            && $existing->user_id === $user->id
            && $existing->table_name === $operation['table']
            && $existing->record_id === $operation['id']
            && $existing->operation_type === $operation['type']
            && hash_equals($existing->payload_hash, self::fingerprint($operation));
    }

    public static function fingerprint(array $operation): string
    {
        $canonical = self::canonicalize([
            'table' => $operation['table'],
            'type' => $operation['type'],
            'id' => $operation['id'],
            'data' => $operation['data'],
        ]);

        return hash('sha256', json_encode($canonical, JSON_THROW_ON_ERROR));
    }

    private static function canonicalize(array $value): array
    {
        if (! array_is_list($value)) {
            ksort($value);
        }

        return array_map(
            fn (mixed $item) => is_array($item) ? self::canonicalize($item) : $item,
            $value,
        );
    }
}
