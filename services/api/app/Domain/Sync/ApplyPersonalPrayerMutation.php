<?php

namespace App\Domain\Sync;

use App\Models\Encounter;
use App\Models\PersonalPrayer;
use App\Models\PersonalPrayerLink;
use App\Models\PersonalPrayerRevision;
use App\Models\User;
use App\Models\VoiceTablet;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Validator;

final class ApplyPersonalPrayerMutation
{
    private const TABLES = [
        'personal_prayers',
        'personal_prayer_revisions',
        'personal_prayer_links',
    ];

    public static function supports(string $table): bool
    {
        return in_array($table, self::TABLES, true);
    }

    /** @param Collection<int, array<string, mixed>> $operations */
    public function validate(User $user, Collection $operations, ?Collection $voiceTabletOperations = null): ?string
    {
        foreach ($operations as $operation) {
            if ($operation['table'] === 'personal_prayer_revisions'
                && $operation['type'] !== 'put') {
                return 'immutable_revision';
            }
            if ($operation['table'] === 'personal_prayer_links'
                && $operation['type'] === 'patch') {
                return 'unsupported_operation';
            }
            if ($operation['table'] === 'personal_prayers'
                && ! in_array($operation['type'], ['put', 'patch', 'delete'], true)) {
                return 'unsupported_operation';
            }

        }

        $pairError = $this->validatePairs($user, $operations);
        if ($pairError !== null) {
            return $pairError;
        }

        foreach ($operations as $operation) {
            $dataError = $this->validateData($operation);
            if ($dataError !== null) {
                return $dataError;
            }
        }

        foreach ($operations->where('table', 'personal_prayer_revisions')->groupBy('id') as $duplicates) {
            $first = $duplicates->first();
            if ($duplicates->contains(
                fn (array $operation): bool => ! $this->sameRevisionData(
                    $first['data'],
                    $operation['data'],
                ),
            )) {
                return 'immutable_revision';
            }
        }

        foreach ($operations->where('table', 'personal_prayer_revisions') as $operation) {
            $existing = PersonalPrayerRevision::query()->find($operation['id']);
            if ($existing !== null) {
                if ($existing->user_id !== $user->id) {
                    return 'forbidden';
                }
                if (! $this->sameStoredRevision($existing, $operation['data'])) {
                    return 'immutable_revision';
                }
            }
        }

        return $this->validateAudioSources($user, $operations, $voiceTabletOperations ?? collect())
            ?? $this->validateLinks($user, $operations);
    }

    /** @param Collection<int, array<string, mixed>> $operations */
    public function apply(User $user, Collection $operations): ?string
    {
        $prayerOperations = $operations->where('table', 'personal_prayers');
        $prayerIds = $operations
            ->flatMap(function (array $operation): array {
                $ids = [];
                if ($operation['table'] === 'personal_prayers') {
                    $ids[] = $operation['id'];
                }
                if (isset($operation['data']['prayer_id'])) {
                    $ids[] = $operation['data']['prayer_id'];
                }

                return $ids;
            })
            ->unique()
            ->sort()
            ->values();
        $existing = PersonalPrayer::query()
            ->whereIn('id', $prayerIds)
            ->orderBy('id')
            ->lockForUpdate()
            ->get()
            ->keyBy('id');
        foreach ($existing as $prayer) {
            if ($prayer->user_id !== $user->id) {
                return 'forbidden';
            }
        }

        $revisionOperations = $operations->where('table', 'personal_prayer_revisions');
        $existingRevisions = PersonalPrayerRevision::query()
            ->whereIn('id', $revisionOperations->pluck('id')->unique())
            ->orderBy('id')
            ->lockForUpdate()
            ->get()
            ->keyBy('id');
        foreach ($revisionOperations as $operation) {
            $revision = $existingRevisions->get($operation['id']);
            if ($revision === null) {
                continue;
            }
            if ($revision->user_id !== $user->id) {
                return 'forbidden';
            }
            if (! $this->sameStoredRevision($revision, $operation['data'])) {
                return 'immutable_revision';
            }
        }

        foreach ($prayerOperations as $operation) {
            $prayer = $existing->get($operation['id']);
            if ($operation['type'] === 'delete') {
                if ($prayer !== null) {
                    $prayer->forceFill(['archived_at' => now()])->save();
                }

                continue;
            }
            if ($operation['type'] === 'patch') {
                if ($prayer === null) {
                    return 'inaccessible_record';
                }
                $prayer->forceFill(Arr::only($operation['data'], [
                    'title',
                    'style',
                    'reach',
                    'grounding',
                    'purpose',
                    'archived_at',
                ]))->save();

                continue;
            }
            if ($prayer === null) {
                $prayer = PersonalPrayer::create([
                    'id' => $operation['id'],
                    'user_id' => $user->id,
                    'title' => $operation['data']['title'],
                    'style' => $operation['data']['style'],
                    'reach' => $operation['data']['reach'],
                    'grounding' => $operation['data']['grounding'],
                    'purpose' => $operation['data']['purpose'],
                    'current_revision_id' => null,
                    'archived_at' => $operation['data']['archived_at'] ?? null,
                ]);
                $existing->put($prayer->id, $prayer);
            }
        }

        foreach ($revisionOperations as $operation) {
            if ($existingRevisions->has($operation['id'])) {
                continue;
            }
            $revision = PersonalPrayerRevision::create([
                'id' => $operation['id'],
                'prayer_id' => $operation['data']['prayer_id'],
                'user_id' => $user->id,
                'body' => $operation['data']['body'] ?? '',
                'content_format' => $operation['data']['content_format'] ?? 'text',
                'action' => $operation['data']['action'] ?? null,
                'device_id' => $operation['data']['device_id'],
                'created_at' => now(),
            ]);
            $existingRevisions->put($revision->id, $revision);
        }

        foreach ($operations->where('table', 'personal_prayer_links') as $operation) {
            if ($operation['type'] === 'delete') {
                PersonalPrayerLink::query()
                    ->whereKey($operation['id'])
                    ->where('user_id', $user->id)
                    ->delete();

                continue;
            }
            PersonalPrayerLink::create([
                'id' => $operation['id'],
                'prayer_id' => $operation['data']['prayer_id'],
                'user_id' => $user->id,
                'link_type' => $operation['data']['link_type'],
                'encounter_id' => $operation['data']['encounter_id'] ?? null,
                'translation' => $operation['data']['translation'] ?? null,
                'book' => $operation['data']['book'] ?? null,
                'chapter' => $operation['data']['chapter'] ?? null,
                'first_verse' => $operation['data']['first_verse'] ?? null,
                'last_verse' => $operation['data']['last_verse'] ?? null,
                'created_at' => now(),
            ]);
        }

        foreach ($prayerOperations->filter(
            fn (array $operation): bool => $operation['type'] !== 'delete'
                && array_key_exists('current_revision_id', $operation['data']),
        ) as $operation) {
            $existing->get($operation['id'])->forceFill([
                'current_revision_id' => $operation['data']['current_revision_id'],
            ])->save();
        }

        return null;
    }

    private function validateData(array $operation): ?string
    {
        if ($operation['type'] === 'delete') {
            return $operation['data'] === [] ? null : 'invalid_data';
        }

        $rules = match ([$operation['table'], $operation['type']]) {
            ['personal_prayers', 'put'] => [
                'owner_id' => [],
                'title' => ['required', 'string', 'max:120'],
                'style' => ['required', 'in:daily,situational'],
                'reach' => ['required', 'in:personal,encompassing'],
                'grounding' => ['required', 'in:general_christian,catholic'],
                'purpose' => ['required', 'in:daily,gratitude,guidance,family,healing,work,forgiveness,difficult_time'],
                'current_revision_id' => ['required', 'uuid'],
                'created_at' => ['sometimes', 'date'],
                'updated_at' => ['sometimes', 'date'],
                'archived_at' => ['nullable', 'date'],
            ],
            ['personal_prayers', 'patch'] => [
                'title' => ['sometimes', 'string', 'max:120'],
                'style' => ['sometimes', 'in:daily,situational'],
                'reach' => ['sometimes', 'in:personal,encompassing'],
                'grounding' => ['sometimes', 'in:general_christian,catholic'],
                'purpose' => ['sometimes', 'in:daily,gratitude,guidance,family,healing,work,forgiveness,difficult_time'],
                'current_revision_id' => ['sometimes', 'uuid'],
                'archived_at' => ['sometimes', 'nullable', 'date'],
                'updated_at' => ['sometimes', 'date'],
            ],
            ['personal_prayer_revisions', 'put'] => [
                'owner_id' => [],
                'prayer_id' => ['required', 'uuid'],
                'body' => ($operation['data']['content_format'] ?? 'text') === 'audio'
                    ? ['present', 'nullable', 'string', 'max:0']
                    : ['required', 'string', 'max:4000'],
                'content_format' => ['sometimes', 'nullable', 'in:text,audio'],
                'action' => ['nullable', 'string', 'max:1000'],
                'device_id' => ['required', 'string', 'max:120'],
                'created_at' => ['sometimes', 'date'],
            ],
            ['personal_prayer_links', 'put'] => [
                'owner_id' => [],
                'prayer_id' => ['required', 'uuid'],
                'link_type' => ['required', 'in:encounter,scripture'],
                'encounter_id' => ['nullable', 'uuid'],
                'translation' => ['nullable', 'string', 'max:20'],
                'book' => ['nullable', 'string', 'max:80'],
                'chapter' => ['nullable', 'integer', 'min:1'],
                'first_verse' => ['nullable', 'integer', 'min:1'],
                'last_verse' => ['nullable', 'integer', 'min:1'],
                'created_at' => ['sometimes', 'date'],
            ],
        };

        if (array_diff(array_keys($operation['data']), array_keys($rules)) !== []
            || Validator::make($operation['data'], $rules)->fails()
            || ($operation['type'] === 'patch' && $operation['data'] === [])) {
            return 'invalid_data';
        }

        return null;
    }

    /** @param array<string, mixed> $left @param array<string, mixed> $right */
    private function sameRevisionData(array $left, array $right): bool
    {
        return ($left['prayer_id'] ?? null) === ($right['prayer_id'] ?? null)
            && ($left['body'] ?? '') === ($right['body'] ?? '')
            && ($left['content_format'] ?? 'text') === ($right['content_format'] ?? 'text')
            && ($left['action'] ?? null) === ($right['action'] ?? null)
            && ($left['device_id'] ?? null) === ($right['device_id'] ?? null);
    }

    /** @param array<string, mixed> $data */
    private function sameStoredRevision(PersonalPrayerRevision $revision, array $data): bool
    {
        return $revision->prayer_id === ($data['prayer_id'] ?? null)
            && $revision->body === ($data['body'] ?? '')
            && ($revision->content_format ?? 'text') === ($data['content_format'] ?? 'text')
            && $revision->action === ($data['action'] ?? null)
            && $revision->device_id === ($data['device_id'] ?? null);
    }

    /** @param Collection<int, array<string, mixed>> $operations */
    private function validatePairs(User $user, Collection $operations): ?string
    {
        $prayers = $operations->where('table', 'personal_prayers');
        $revisions = $operations->where('table', 'personal_prayer_revisions');
        foreach ($prayers->filter(
            fn (array $prayer): bool => $prayer['type'] !== 'delete'
                && array_key_exists('current_revision_id', $prayer['data']),
        ) as $prayer) {
            $revisionId = $prayer['data']['current_revision_id'] ?? null;
            $paired = $revisions->contains(
                fn (array $revision): bool => $revision['id'] === $revisionId
                    && ($revision['data']['prayer_id'] ?? null) === $prayer['id'],
            );
            $existingPair = $revisionId !== null
                && PersonalPrayerRevision::query()
                    ->whereKey($revisionId)
                    ->where('prayer_id', $prayer['id'])
                    ->where('user_id', $user->id)
                    ->exists();
            if (! $paired && ! $existingPair) {
                return 'incomplete_revision_pair';
            }
        }
        foreach ($revisions as $revision) {
            $prayerId = $revision['data']['prayer_id'] ?? null;
            $paired = $prayers->contains('id', $prayerId);
            $owned = PersonalPrayer::query()
                ->whereKey($prayerId)
                ->where('user_id', $user->id)
                ->exists();
            if (! $paired && ! $owned) {
                return 'incomplete_revision_pair';
            }
        }

        return null;
    }

    /** Audio bytes are device-local; synchronized metadata must still identify
     * the owner's actual recording rather than an empty text placeholder.
     */
    private function validateAudioSources(User $user, Collection $operations, Collection $tablets): ?string
    {
        foreach ($operations->where('table', 'personal_prayer_revisions') as $revision) {
            if (($revision['data']['content_format'] ?? 'text') !== 'audio') {
                continue;
            }
            $sourceExists = VoiceTablet::query()
                ->where('user_id', $user->id)
                ->where('source_type', 'personal_prayer')
                ->where('personal_prayer_id', $revision['data']['prayer_id'])
                ->where('prayer_revision_id', $revision['id'])
                ->exists();
            $sourceInBatch = $tablets->contains(fn (array $tablet): bool =>
                $tablet['table'] === 'voice_tablets'
                && $tablet['type'] === 'put'
                && ($tablet['data']['source_type'] ?? null) === 'personal_prayer'
                && ($tablet['data']['personal_prayer_id'] ?? null) === $revision['data']['prayer_id']
                && ($tablet['data']['prayer_revision_id'] ?? null) === $revision['id']
                && ($tablet['data']['archived_at'] ?? null) === null
            );
            if (! $sourceExists && ! $sourceInBatch) {
                return 'incomplete_audio_prayer';
            }
        }

        return null;
    }

    /** @param Collection<int, array<string, mixed>> $operations */
    private function validateLinks(User $user, Collection $operations): ?string
    {
        $batchPrayerIds = $operations
            ->where('table', 'personal_prayers')
            ->pluck('id');
        foreach ($operations->where('table', 'personal_prayer_links') as $operation) {
            if ($operation['type'] === 'delete') {
                continue;
            }
            $data = $operation['data'];
            $ownedPrayer = $batchPrayerIds->contains($data['prayer_id'])
                || PersonalPrayer::query()
                    ->whereKey($data['prayer_id'])
                    ->where('user_id', $user->id)
                    ->exists();
            if (! $ownedPrayer) {
                return 'forbidden';
            }
            if ($data['link_type'] === 'encounter') {
                $shapeIsValid = ($data['encounter_id'] ?? null) !== null
                    && collect(['translation', 'book', 'chapter', 'first_verse', 'last_verse'])
                        ->every(fn (string $key): bool => ($data[$key] ?? null) === null);
                $ownedEncounter = Encounter::query()
                    ->whereKey($data['encounter_id'] ?? '')
                    ->where('user_id', $user->id)
                    ->exists();
                if (! $shapeIsValid || ! $ownedEncounter) {
                    return 'invalid_link';
                }
            } else {
                $shapeIsValid = ($data['encounter_id'] ?? null) === null
                    && collect(['translation', 'book', 'chapter', 'first_verse', 'last_verse'])
                        ->every(fn (string $key): bool => ($data[$key] ?? null) !== null)
                    && $data['last_verse'] >= $data['first_verse'];
                if (! $shapeIsValid) {
                    return 'invalid_link';
                }
            }
        }

        return null;
    }
}

