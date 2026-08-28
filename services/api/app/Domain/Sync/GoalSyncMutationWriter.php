<?php

namespace App\Domain\Sync;

use App\Models\Goal;
use App\Models\GoalAction;
use App\Models\GoalActionEvent;
use App\Models\GoalLink;
use App\Models\GoalRevision;
use App\Models\User;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;

final class GoalSyncMutationWriter
{
    /** @param Collection<int, array<string, mixed>> $operations */
    public function apply(User $user, Collection $operations): void
    {
        $this->goals($user, $operations);
        $this->revisions($user, $operations);
        $this->currentRevisions($user, $operations);
        $this->links($user, $operations);
        $this->actions($user, $operations);
        $this->events($user, $operations);
    }

    private function goals(User $user, Collection $operations): void
    {
        foreach ($operations->where('table', 'goals') as $operation) {
            $goal = Goal::query()
                ->whereKey($operation['id'])
                ->where('user_id', $user->id)
                ->first();
            if ($operation['type'] === 'delete') {
                $goal?->forceFill([
                    'status' => 'archived',
                    'archived_at' => now(),
                ])->save();

                continue;
            }
            if ($operation['type'] === 'patch') {
                $goal->forceFill(Arr::only($operation['data'], [
                    'starter_key', 'mode', 'status', 'position', 'archived_at',
                ]))->save();

                continue;
            }
            if ($goal === null) {
                Goal::create([
                    'id' => $operation['id'],
                    'user_id' => $user->id,
                    'starter_key' => $operation['data']['starter_key'],
                    'mode' => $operation['data']['mode'],
                    'status' => $operation['data']['status'],
                    'current_revision_id' => null,
                    'position' => $operation['data']['position'],
                    'archived_at' => $operation['data']['archived_at'],
                ]);
            }
        }
    }

    private function revisions(User $user, Collection $operations): void
    {
        foreach ($operations->where('table', 'goal_revisions') as $operation) {
            if (GoalRevision::query()->whereKey($operation['id'])->exists()) {
                continue;
            }
            GoalRevision::create([
                'id' => $operation['id'],
                'goal_id' => $operation['data']['goal_id'],
                'user_id' => $user->id,
                'title' => trim($operation['data']['title']),
                'current_situation' => $operation['data']['current_situation'],
                'why_it_matters' => $operation['data']['why_it_matters'],
                'created_at' => $operation['data']['created_at'] ?? now(),
                'device_id' => $operation['data']['device_id'],
            ]);
        }
    }

    private function currentRevisions(User $user, Collection $operations): void
    {
        foreach ($operations->where('table', 'goals')->filter(
            fn (array $operation): bool => $operation['type'] !== 'delete'
                && array_key_exists('current_revision_id', $operation['data']),
        ) as $operation) {
            Goal::query()
                ->whereKey($operation['id'])
                ->where('user_id', $user->id)
                ->firstOrFail()
                ->forceFill([
                    'current_revision_id' => $operation['data']['current_revision_id'],
                ])->save();
        }
    }

    private function links(User $user, Collection $operations): void
    {
        foreach ($operations->where('table', 'goal_links') as $operation) {
            $link = GoalLink::query()
                ->whereKey($operation['id'])
                ->where('user_id', $user->id)
                ->first();
            if ($operation['type'] === 'delete') {
                $link?->forceFill(['archived_at' => now()])->save();

                continue;
            }
            if ($operation['type'] === 'patch') {
                $link->forceFill(
                    Arr::only($operation['data'], ['role', 'archived_at']),
                )->save();

                continue;
            }
            if ($link === null) {
                GoalLink::create([
                    'id' => $operation['id'],
                    'goal_id' => $operation['data']['goal_id'],
                    'user_id' => $user->id,
                    'link_type' => $operation['data']['link_type'],
                    'personal_prayer_id' => $operation['data']['personal_prayer_id'],
                    'library_prayer_id' => $operation['data']['library_prayer_id'],
                    'encounter_id' => $operation['data']['encounter_id'],
                    'voice_tablet_id' => $operation['data']['voice_tablet_id'],
                    'circle_id' => $operation['data']['circle_id'],
                    'translation' => $operation['data']['translation'],
                    'book' => $operation['data']['book'],
                    'chapter' => $operation['data']['chapter'],
                    'first_verse' => $operation['data']['first_verse'],
                    'last_verse' => $operation['data']['last_verse'],
                    'role' => $operation['data']['role'],
                    'created_at' => $operation['data']['created_at'] ?? now(),
                    'archived_at' => $operation['data']['archived_at'],
                ]);
            }
        }
    }

    private function actions(User $user, Collection $operations): void
    {
        foreach ($operations->where('table', 'goal_actions') as $operation) {
            $action = GoalAction::query()
                ->whereKey($operation['id'])
                ->where('user_id', $user->id)
                ->first();
            if ($operation['type'] === 'delete') {
                $action?->forceFill([
                    'enabled' => false,
                    'archived_at' => now(),
                ])->save();

                continue;
            }
            if ($operation['type'] === 'patch') {
                $action->forceFill(Arr::only($operation['data'], [
                    'body', 'action_kind', 'schedule_type', 'local_time',
                    'timezone', 'once_at', 'weekdays_mask', 'enabled', 'archived_at',
                ]))->save();

                continue;
            }
            if ($action === null) {
                GoalAction::create([
                    'id' => $operation['id'],
                    'goal_id' => $operation['data']['goal_id'],
                    'user_id' => $user->id,
                    'body' => trim($operation['data']['body']),
                    'action_kind' => $operation['data']['action_kind'],
                    'schedule_type' => $operation['data']['schedule_type'],
                    'local_time' => $operation['data']['local_time'],
                    'timezone' => $operation['data']['timezone'],
                    'once_at' => $operation['data']['once_at'],
                    'weekdays_mask' => $operation['data']['weekdays_mask'],
                    'enabled' => $operation['data']['enabled'],
                    'archived_at' => $operation['data']['archived_at'],
                ]);
            }
        }
    }

    private function events(User $user, Collection $operations): void
    {
        foreach ($operations->where('table', 'goal_action_events') as $operation) {
            if (GoalActionEvent::query()->whereKey($operation['id'])->exists()) {
                continue;
            }
            GoalActionEvent::create([
                'id' => $operation['id'],
                'goal_action_id' => $operation['data']['goal_action_id'],
                'goal_id' => $operation['data']['goal_id'],
                'user_id' => $user->id,
                'event_type' => $operation['data']['event_type'],
                'occurrence_key' => $operation['data']['occurrence_key'],
                'occurred_at' => $operation['data']['occurred_at'],
                'local_date' => $operation['data']['local_date'],
                'device_id' => $operation['data']['device_id'],
            ]);
        }
    }
}
