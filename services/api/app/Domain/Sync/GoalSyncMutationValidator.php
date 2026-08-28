<?php

namespace App\Domain\Sync;

use App\Models\Encounter;
use App\Models\Goal;
use App\Models\GoalAction;
use App\Models\GoalActionEvent;
use App\Models\GoalLink;
use App\Models\GoalRevision;
use App\Models\LibraryPrayer;
use App\Models\PersonalPrayer;
use App\Models\User;
use App\Models\VoiceTablet;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Validator;

final class GoalSyncMutationValidator
{
    /** @param Collection<int, array<string, mixed>> $operations */
    public function validate(User $user, Collection $operations): ?string
    {
        foreach ($operations as $operation) {
            if (($error = $this->validateKindAndData($operation)) !== null) {
                return $error;
            }
        }
        foreach ($operations as $operation) {
            if (($error = $this->validateExistingRecord($user, $operation)) !== null) {
                return $error;
            }
        }
        if (($error = $this->validateRevisionPairs($user, $operations)) !== null) {
            return $error;
        }
        foreach ($operations as $operation) {
            $error = match ($operation['table']) {
                'goals' => $this->validateGoalShape($operation),
                'goal_links' => $this->validateLinkTarget($user, $operations, $operation),
                'goal_actions' => $this->validateActionTarget($user, $operations, $operation),
                'goal_action_events' => $this->validateEventTarget($user, $operations, $operation),
                default => null,
            };
            if ($error !== null) {
                return $error;
            }
        }

        return null;
    }

    private function validateKindAndData(array $operation): ?string
    {
        if (in_array($operation['table'], ['goal_revisions', 'goal_action_events'], true)
            && $operation['type'] !== 'put') {
            return $operation['table'] === 'goal_revisions'
                ? 'immutable_revision'
                : 'immutable_event';
        }
        if (! in_array($operation['type'], ['put', 'patch', 'delete'], true)) {
            return 'unsupported_operation';
        }
        if ($operation['type'] === 'delete') {
            return $operation['data'] === [] ? null : 'invalid_data';
        }

        $rules = $operation['type'] === 'patch'
            ? $this->patchRules($operation['table'])
            : $this->putRules($operation['table']);
        if ($operation['data'] === []
            || $rules === []
            || array_diff(array_keys($operation['data']), array_keys($rules)) !== []
            || Validator::make($operation['data'], $rules)->fails()) {
            return 'invalid_data';
        }

        return null;
    }

    private function patchRules(string $table): array
    {
        return match ($table) {
            'goals' => [
                'starter_key' => ['sometimes', 'nullable', 'in:closer_to_god,stop_control,direction,difficult_time,other'],
                'mode' => ['sometimes', 'in:actionable,petition,mixed'],
                'status' => ['sometimes', 'in:active,paused,completed,archived'],
                'current_revision_id' => ['sometimes', 'uuid'],
                'position' => ['sometimes', 'integer', 'min:0'],
                'updated_at' => ['sometimes', 'date'],
                'archived_at' => ['sometimes', 'nullable', 'date'],
            ],
            'goal_links' => [
                'role' => ['sometimes', 'in:primary_prayer,supporting_prayer,primary_circle,support,reference'],
                'archived_at' => ['sometimes', 'nullable', 'date'],
            ],
            'goal_actions' => [
                'body' => ['sometimes', 'string', 'min:1', 'max:1000'],
                'action_kind' => ['sometimes', 'in:next_step,guard,accountability,care,other'],
                'schedule_type' => ['sometimes', 'in:today,once,daily,selected_days,none'],
                'local_time' => ['sometimes', 'nullable', 'date_format:H:i'],
                'timezone' => ['sometimes', 'nullable', 'string', 'max:100'],
                'once_at' => ['sometimes', 'nullable', 'date'],
                'weekdays_mask' => ['sometimes', 'nullable', 'integer', 'between:1,127'],
                'enabled' => ['sometimes', 'boolean'],
                'updated_at' => ['sometimes', 'date'],
                'archived_at' => ['sometimes', 'nullable', 'date'],
            ],
            default => [],
        };
    }

    private function putRules(string $table): array
    {
        return match ($table) {
            'goals' => [
                'owner_id' => [],
                'starter_key' => ['present', 'nullable', 'in:closer_to_god,stop_control,direction,difficult_time,other'],
                'mode' => ['required', 'in:actionable,petition,mixed'],
                'status' => ['required', 'in:active,paused,completed,archived'],
                'current_revision_id' => ['required', 'uuid'],
                'position' => ['required', 'integer', 'min:0'],
                'created_at' => ['sometimes', 'date'],
                'updated_at' => ['sometimes', 'date'],
                'archived_at' => ['present', 'nullable', 'date'],
            ],
            'goal_revisions' => [
                'owner_id' => [],
                'goal_id' => ['required', 'uuid'],
                'title' => ['required', 'string', 'min:1', 'max:120'],
                'current_situation' => ['present', 'nullable', 'string', 'max:4000'],
                'why_it_matters' => ['present', 'nullable', 'string', 'max:4000'],
                'created_at' => ['sometimes', 'date'],
                'device_id' => ['required', 'string', 'min:1', 'max:120'],
            ],
            'goal_links' => [
                'owner_id' => [],
                'goal_id' => ['required', 'uuid'],
                'link_type' => ['required', 'in:personal_prayer,library_prayer,encounter,voice_tablet,circle,scripture'],
                'personal_prayer_id' => ['present', 'nullable', 'uuid'],
                'library_prayer_id' => ['present', 'nullable', 'uuid'],
                'encounter_id' => ['present', 'nullable', 'uuid'],
                'voice_tablet_id' => ['present', 'nullable', 'uuid'],
                'circle_id' => ['present', 'nullable', 'uuid'],
                'translation' => ['present', 'nullable', 'string', 'max:20'],
                'book' => ['present', 'nullable', 'string', 'max:80'],
                'chapter' => ['present', 'nullable', 'integer', 'min:1'],
                'first_verse' => ['present', 'nullable', 'integer', 'min:1'],
                'last_verse' => ['present', 'nullable', 'integer', 'min:1'],
                'role' => ['required', 'in:primary_prayer,supporting_prayer,primary_circle,support,reference'],
                'created_at' => ['sometimes', 'date'],
                'archived_at' => ['present', 'nullable', 'date'],
            ],
            'goal_actions' => [
                'owner_id' => [],
                'goal_id' => ['required', 'uuid'],
                'body' => ['required', 'string', 'min:1', 'max:1000'],
                'action_kind' => ['required', 'in:next_step,guard,accountability,care,other'],
                'schedule_type' => ['required', 'in:today,once,daily,selected_days,none'],
                'local_time' => ['present', 'nullable', 'date_format:H:i'],
                'timezone' => ['present', 'nullable', 'string', 'max:100'],
                'once_at' => ['present', 'nullable', 'date'],
                'weekdays_mask' => ['present', 'nullable', 'integer', 'between:1,127'],
                'enabled' => ['required', 'boolean'],
                'created_at' => ['sometimes', 'date'],
                'updated_at' => ['sometimes', 'date'],
                'archived_at' => ['present', 'nullable', 'date'],
            ],
            'goal_action_events' => [
                'owner_id' => [],
                'goal_action_id' => ['required', 'uuid'],
                'goal_id' => ['required', 'uuid'],
                'event_type' => ['required', 'in:completed,skipped,retracted'],
                'occurrence_key' => ['required', 'string', 'max:180'],
                'occurred_at' => ['required', 'date'],
                'local_date' => ['required', 'date_format:Y-m-d'],
                'device_id' => ['required', 'string', 'min:1', 'max:120'],
            ],
            default => [],
        };
    }

    private function validateExistingRecord(User $user, array $operation): ?string
    {
        $modelClass = $this->modelFor($operation['table']);
        $existing = $modelClass::query()->find($operation['id']);
        if ($existing !== null && $existing->user_id !== $user->id) {
            return 'inaccessible_record';
        }
        if ($operation['type'] !== 'put') {
            return $existing === null ? 'inaccessible_record' : null;
        }
        if ($existing === null) {
            return null;
        }

        return match ($operation['table']) {
            'goal_revisions' => $this->sameRevision($existing, $operation['data'])
                ? null : 'immutable_revision',
            'goal_action_events' => $this->sameEvent($existing, $operation['data'])
                ? null : 'immutable_event',
            'goals' => $this->sameGoal($existing, $operation['data']) ? null : 'conflict',
            'goal_links' => $this->sameLink($existing, $operation['data']) ? null : 'conflict',
            'goal_actions' => $this->sameAction($existing, $operation['data']) ? null : 'conflict',
        };
    }

    /** @param Collection<int, array<string, mixed>> $operations */
    private function validateRevisionPairs(User $user, Collection $operations): ?string
    {
        $goalPuts = $operations->where('table', 'goals')->where('type', 'put');
        $revisions = $operations->where('table', 'goal_revisions');

        foreach ($operations->where('table', 'goals')->filter(
            fn (array $operation): bool => $operation['type'] !== 'delete'
                && array_key_exists('current_revision_id', $operation['data']),
        ) as $goal) {
            $revisionId = $goal['data']['current_revision_id'];
            $paired = $revisions->contains(
                fn (array $revision): bool => $revision['id'] === $revisionId
                    && ($revision['data']['goal_id'] ?? null) === $goal['id'],
            );
            $stored = GoalRevision::query()
                ->whereKey($revisionId)
                ->where('goal_id', $goal['id'])
                ->where('user_id', $user->id)
                ->exists();
            if (! $paired && ! $stored) {
                return 'incomplete_revision_pair';
            }
        }

        foreach ($revisions as $revision) {
            $goalId = $revision['data']['goal_id'];
            $pending = $goalPuts->contains('id', $goalId);
            $stored = Goal::query()
                ->whereKey($goalId)
                ->where('user_id', $user->id)
                ->exists();
            if (! $pending && ! $stored) {
                return 'incomplete_revision_pair';
            }
        }

        return null;
    }

    private function validateGoalShape(array $operation): ?string
    {
        if ($operation['type'] === 'delete') {
            return null;
        }
        $data = $operation['data'];
        if ($operation['type'] === 'patch') {
            $goal = Goal::query()->find($operation['id']);
            if ($goal === null) {
                return 'inaccessible_record';
            }
            $data = array_replace([
                'status' => $goal->status,
                'archived_at' => $goal->archived_at?->toIso8601String(),
            ], $data);
        }
        $archived = ($data['archived_at'] ?? null) !== null;

        return (($data['status'] ?? null) === 'archived') === $archived
            ? null : 'invalid_data';
    }

    private function validateLinkTarget(User $user, Collection $operations, array $operation): ?string
    {
        if ($operation['type'] !== 'put') {
            return null;
        }
        $data = $operation['data'];
        if (! $this->goalIsAvailable($user, $operations, $data['goal_id'])) {
            return 'inaccessible_record';
        }
        if (! $this->validLinkShape($data)) {
            return 'invalid_link';
        }
        if ($data['link_type'] === 'circle') {
            return 'unsupported_link_target';
        }

        $available = match ($data['link_type']) {
            'personal_prayer' => PersonalPrayer::query()
                ->whereKey($data['personal_prayer_id'])
                ->where('user_id', $user->id)
                ->whereNull('archived_at')
                ->exists(),
            'library_prayer' => LibraryPrayer::query()
                ->whereKey($data['library_prayer_id'])
                ->whereNotNull('published_at')
                ->whereNull('archived_at')
                ->exists(),
            'encounter' => Encounter::query()
                ->whereKey($data['encounter_id'])
                ->where('user_id', $user->id)
                ->whereNull('archived_at')
                ->exists(),
            'voice_tablet' => VoiceTablet::query()
                ->whereKey($data['voice_tablet_id'])
                ->where('user_id', $user->id)
                ->whereNull('archived_at')
                ->exists(),
            'scripture' => true,
        };

        return $available ? null : 'inaccessible_record';
    }

    private function validateActionTarget(User $user, Collection $operations, array $operation): ?string
    {
        if ($operation['type'] === 'delete') {
            return null;
        }
        $data = $operation['data'];
        if ($operation['type'] === 'put'
            && ! $this->goalIsAvailable($user, $operations, $data['goal_id'])) {
            return 'inaccessible_record';
        }
        if ($operation['type'] === 'patch') {
            $action = GoalAction::query()->find($operation['id']);
            if ($action === null) {
                return 'inaccessible_record';
            }
            $data = array_replace([
                'schedule_type' => $action->schedule_type,
                'once_at' => $action->once_at?->toIso8601String(),
                'weekdays_mask' => $action->weekdays_mask,
            ], $data);
        }

        return $this->validActionShape($data) ? null : 'invalid_data';
    }

    private function validateEventTarget(User $user, Collection $operations, array $operation): ?string
    {
        if ($operation['type'] !== 'put') {
            return null;
        }
        $data = $operation['data'];
        $pendingAction = $operations
            ->where('table', 'goal_actions')
            ->where('type', 'put')
            ->firstWhere('id', $data['goal_action_id']);
        if ($pendingAction !== null) {
            $goalId = $pendingAction['data']['goal_id'];
        } else {
            $action = GoalAction::query()
                ->whereKey($data['goal_action_id'])
                ->where('user_id', $user->id)
                ->whereNull('archived_at')
                ->first();
            if ($action === null) {
                return 'inaccessible_record';
            }
            $goalId = $action->goal_id;
        }
        if ($goalId !== $data['goal_id']) {
            return 'invalid_event_target';
        }

        return hash_equals(
            $data['goal_action_id'].':'.$data['local_date'],
            $data['occurrence_key'],
        ) ? null : 'invalid_occurrence';
    }

    private function goalIsAvailable(User $user, Collection $operations, string $goalId): bool
    {
        if ($operations->where('table', 'goals')->where('type', 'put')->contains('id', $goalId)) {
            return true;
        }

        return Goal::query()
            ->whereKey($goalId)
            ->where('user_id', $user->id)
            ->whereNull('archived_at')
            ->exists();
    }

    private function validLinkShape(array $data): bool
    {
        $directKeys = [
            'personal_prayer_id', 'library_prayer_id', 'encounter_id',
            'voice_tablet_id', 'circle_id',
        ];
        $setTargets = collect($directKeys)->filter(
            fn (string $key): bool => ($data[$key] ?? null) !== null,
        );
        $scriptureKeys = ['translation', 'book', 'chapter', 'first_verse', 'last_verse'];
        $hasAnyScripture = collect($scriptureKeys)->contains(
            fn (string $key): bool => ($data[$key] ?? null) !== null,
        );
        $shape = match ($data['link_type']) {
            'personal_prayer' => $setTargets->count() === 1
                && $data['personal_prayer_id'] !== null && ! $hasAnyScripture,
            'library_prayer' => $setTargets->count() === 1
                && $data['library_prayer_id'] !== null && ! $hasAnyScripture,
            'encounter' => $setTargets->count() === 1
                && $data['encounter_id'] !== null && ! $hasAnyScripture,
            'voice_tablet' => $setTargets->count() === 1
                && $data['voice_tablet_id'] !== null && ! $hasAnyScripture,
            'circle' => $setTargets->count() === 1
                && $data['circle_id'] !== null && ! $hasAnyScripture,
            'scripture' => $setTargets->isEmpty()
                && collect($scriptureKeys)->every(
                    fn (string $key): bool => ($data[$key] ?? null) !== null,
                )
                && $data['last_verse'] >= $data['first_verse'],
        };
        if (! $shape) {
            return false;
        }
        if (in_array($data['role'], ['primary_prayer', 'supporting_prayer'], true)) {
            return in_array($data['link_type'], ['personal_prayer', 'library_prayer'], true);
        }
        if ($data['role'] === 'primary_circle') {
            return $data['link_type'] === 'circle';
        }

        return true;
    }

    private function validActionShape(array $data): bool
    {
        $onceAt = $data['once_at'] ?? null;
        $weekdays = $data['weekdays_mask'] ?? null;

        return match ($data['schedule_type']) {
            'today', 'once' => $onceAt !== null && $weekdays === null,
            'selected_days' => $onceAt === null
                && is_int($weekdays)
                && $weekdays >= 1
                && $weekdays <= 127,
            'daily', 'none' => $onceAt === null && $weekdays === null,
        };
    }

    private function sameGoal(Goal $goal, array $data): bool
    {
        return $goal->starter_key === $data['starter_key']
            && $goal->mode === $data['mode']
            && $goal->status === $data['status']
            && $goal->current_revision_id === $data['current_revision_id']
            && $goal->position === (int) $data['position']
            && $this->sameDate($goal->archived_at, $data['archived_at']);
    }

    private function sameRevision(GoalRevision $revision, array $data): bool
    {
        return $revision->goal_id === $data['goal_id']
            && $revision->title === trim($data['title'])
            && $revision->current_situation === $data['current_situation']
            && $revision->why_it_matters === $data['why_it_matters']
            && $revision->device_id === $data['device_id'];
    }

    private function sameLink(GoalLink $link, array $data): bool
    {
        foreach ([
            'goal_id', 'link_type', 'personal_prayer_id', 'library_prayer_id',
            'encounter_id', 'voice_tablet_id', 'circle_id', 'translation', 'book',
            'chapter', 'first_verse', 'last_verse', 'role',
        ] as $key) {
            if ($link->{$key} != $data[$key]) {
                return false;
            }
        }

        return $this->sameDate($link->archived_at, $data['archived_at']);
    }

    private function sameAction(GoalAction $action, array $data): bool
    {
        foreach ([
            'goal_id', 'body', 'action_kind', 'schedule_type', 'local_time',
            'timezone', 'weekdays_mask',
        ] as $key) {
            if ($action->{$key} != $data[$key]) {
                return false;
            }
        }

        return $action->enabled === (bool) $data['enabled']
            && $this->sameDate($action->once_at, $data['once_at'])
            && $this->sameDate($action->archived_at, $data['archived_at']);
    }

    private function sameEvent(GoalActionEvent $event, array $data): bool
    {
        return $event->goal_action_id === $data['goal_action_id']
            && $event->goal_id === $data['goal_id']
            && $event->event_type === $data['event_type']
            && $event->occurrence_key === $data['occurrence_key']
            && $event->local_date->format('Y-m-d') === $data['local_date']
            && $event->device_id === $data['device_id']
            && $this->sameDate($event->occurred_at, $data['occurred_at']);
    }

    private function sameDate(mixed $stored, mixed $incoming): bool
    {
        if ($stored === null || $incoming === null) {
            return $stored === null && $incoming === null;
        }
        $storedTimestamp = $stored instanceof \DateTimeInterface
            ? $stored->getTimestamp()
            : strtotime((string) $stored);
        $incomingTimestamp = $incoming instanceof \DateTimeInterface
            ? $incoming->getTimestamp()
            : strtotime((string) $incoming);

        return $storedTimestamp !== false
            && $incomingTimestamp !== false
            && $storedTimestamp === $incomingTimestamp;
    }

    /** @return class-string */
    private function modelFor(string $table): string
    {
        return match ($table) {
            'goals' => Goal::class,
            'goal_revisions' => GoalRevision::class,
            'goal_links' => GoalLink::class,
            'goal_actions' => GoalAction::class,
            'goal_action_events' => GoalActionEvent::class,
        };
    }
}
