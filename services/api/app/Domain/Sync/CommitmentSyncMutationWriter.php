<?php

namespace App\Domain\Sync;

use App\Models\User;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use Illuminate\Support\Str;

final class CommitmentSyncMutationWriter
{
    public function apply(User $user, Collection $operations): void
    {
        foreach (CommitmentSyncMutationValidator::TABLES as $table) {
            $model = 'App\\Models\\'.Str::studly(Str::singular($table));
            foreach ($operations->where('table', $table) as $operation) {
                $record = $model::query()->where('user_id', $user->id)->find($operation['id']);
                if ($record !== null && $operation['type'] === 'put') {
                    continue;
                }
                $record ??= new $model(['id' => $operation['id'], 'user_id' => $user->id]);
                $record->forceFill(Arr::except($operation['data'], ['owner_id']) + ['owner_id' => $user->public_id])->save();
            }
        }
    }
}
