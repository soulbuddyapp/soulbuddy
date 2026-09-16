<?php

namespace App\Domain\Formation;

use Illuminate\Support\Facades\DB;
use InvalidArgumentException;
use JsonException;

final class FormationCatalog
{
    private const int VideoCount = 45;

    private const int PackCount = 10;

    private const int DayCount = 70;

    private const int RuleCount = 10;

    private const int MaxRuntimeSeconds = 630;

    /** @return array{version:int, checksum:string, videos:int, packs:int, days:int, rules:int} */
    public function publish(string $path): array
    {
        if (! is_file($path) || ! is_readable($path)) {
            throw new InvalidArgumentException('A readable catalog JSON file is required.');
        }

        $contents = file_get_contents($path);
        if ($contents === false) {
            throw new InvalidArgumentException('The catalog JSON file could not be read.');
        }

        try {
            $catalog = json_decode($contents, true, flags: JSON_THROW_ON_ERROR);
        } catch (JsonException $exception) {
            throw new InvalidArgumentException('The catalog JSON is invalid.', previous: $exception);
        }

        if (! is_array($catalog)) {
            throw new InvalidArgumentException('The catalog must be a JSON object.');
        }

        $this->validate($catalog);
        $checksum = hash('sha256', $contents);

        return DB::transaction(function () use ($catalog, $checksum): array {
            $existing = DB::table('formation_catalog_versions')->where('version', $catalog['version'])->first();
            if ($existing !== null && ! hash_equals($existing->checksum, $checksum)) {
                throw new InvalidArgumentException('Catalog version already exists with different content.');
            }

            if ($existing !== null) {
                DB::table('formation_catalog_versions')->update(['published' => false, 'updated_at' => now()]);
                DB::table('formation_catalog_versions')->where('id', $existing->id)->update([
                    'published' => true,
                    'published_at' => now(),
                    'updated_at' => now(),
                ]);

                return $this->summary($catalog, $checksum);
            }

            $now = now();
            $catalogVersionId = DB::table('formation_catalog_versions')->insertGetId([
                'version' => $catalog['version'],
                'checksum' => $checksum,
                'source_sha256' => $catalog['sourceSha256'],
                'published' => false,
                'published_at' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            DB::table('formation_videos')->insert(array_map(
                fn (array $video): array => $this->videoRow($catalogVersionId, $video, $now),
                $catalog['videos'],
            ));
            DB::table('formation_packs')->insert(array_map(
                fn (array $pack): array => $this->packRow($catalogVersionId, $pack, $now),
                $catalog['packs'],
            ));
            DB::table('formation_days')->insert(array_map(
                fn (array $day): array => $this->dayRow($catalogVersionId, $day, $now),
                $catalog['days'],
            ));
            DB::table('formation_rules')->insert(array_map(
                fn (array $rule): array => $this->ruleRow($catalogVersionId, $rule, $now),
                $catalog['rules'],
            ));

            DB::table('formation_catalog_versions')->update(['published' => false, 'updated_at' => $now]);
            DB::table('formation_catalog_versions')->where('id', $catalogVersionId)->update([
                'published' => true,
                'published_at' => $now,
                'updated_at' => $now,
            ]);

            return $this->summary($catalog, $checksum);
        });
    }

    /** @param array<string, mixed> $catalog */
    private function validate(array $catalog): void
    {
        if (($catalog['version'] ?? null) !== 1 || ! preg_match('/^[a-f0-9]{64}$/', (string) ($catalog['sourceSha256'] ?? ''))) {
            throw new InvalidArgumentException('Catalog version and source checksum are required.');
        }
        if (count($catalog['videos'] ?? []) !== self::VideoCount
            || count($catalog['packs'] ?? []) !== self::PackCount
            || count($catalog['days'] ?? []) !== self::DayCount
            || count($catalog['rules'] ?? []) !== self::RuleCount) {
            throw new InvalidArgumentException('Catalog record counts are invalid.');
        }

        $videoIds = $this->uniqueIds($catalog['videos'], 'video');
        foreach ($catalog['videos'] as $video) {
            $this->requireKeys($video, ['id', 'youtubeId', 'youtubeUrl', 'runtimeSeconds', 'status']);
            if ($video['status'] !== 'PRODUCTION_READY'
                || ! is_int($video['runtimeSeconds'])
                || $video['runtimeSeconds'] < 1
                || $video['runtimeSeconds'] > self::MaxRuntimeSeconds
                || $video['youtubeUrl'] !== 'https://www.youtube.com/watch?v='.$video['youtubeId']) {
                throw new InvalidArgumentException('Catalog video validation failed.');
            }
        }

        $packIds = $this->uniqueIds($catalog['packs'], 'pack');
        $this->uniqueIds($catalog['days'], 'day');
        foreach ($catalog['days'] as $day) {
            $this->requireKeys($day, ['packId', 'videoIds', 'objective', 'scripture', 'reflection', 'action', 'completionRule']);
            if (! in_array($day['packId'], $packIds, true)
                || ! is_array($day['videoIds'])
                || count($day['videoIds']) !== 3
                || count(array_unique($day['videoIds'])) !== 3
                || array_diff($day['videoIds'], $videoIds) !== []) {
                throw new InvalidArgumentException('Catalog day validation failed.');
            }
            foreach (['objective', 'scripture', 'reflection', 'action', 'completionRule'] as $key) {
                if (! is_string($day[$key]) || trim($day[$key]) === '') {
                    throw new InvalidArgumentException('Catalog day copy is incomplete.');
                }
            }
        }

        $this->uniqueIds($catalog['rules'], 'rule');
    }

    /** @param array<int, array<string, mixed>> $records @return array<int, string> */
    private function uniqueIds(array $records, string $recordType): array
    {
        $ids = array_map(fn (array $record): string => (string) ($record['id'] ?? ''), $records);
        if (in_array('', $ids, true) || count($ids) !== count(array_unique($ids))) {
            throw new InvalidArgumentException("Catalog {$recordType} IDs must be unique.");
        }

        return $ids;
    }

    /** @param array<string, mixed> $record @param array<int, string> $keys */
    private function requireKeys(array $record, array $keys): void
    {
        foreach ($keys as $key) {
            if (! array_key_exists($key, $record)) {
                throw new InvalidArgumentException("Catalog record is missing {$key}.");
            }
        }
    }

    /** @param array<string, mixed> $video @return array<string, mixed> */
    private function videoRow(int $catalogVersionId, array $video, mixed $now): array
    {
        return [
            'catalog_version_id' => $catalogVersionId,
            'stable_id' => $video['id'],
            'title' => $video['title'],
            'channel' => $video['channel'],
            'youtube_url' => $video['youtubeUrl'],
            'youtube_id' => $video['youtubeId'],
            'runtime_seconds' => $video['runtimeSeconds'],
            'status' => $video['status'],
            'primary_topic' => $video['primaryTopic'],
            'secondary_use' => $video['secondaryUse'],
            'vice_target' => $video['viceTarget'],
            'virtue_target' => $video['virtueTarget'],
            'difficulty' => $video['difficulty'],
            'theological_lens' => $video['theologicalLens'],
            'official_runtime_source' => $video['officialRuntimeSource'],
            'youtube_verification_source' => $video['youtubeVerificationSource'],
            'verified_on' => $video['verifiedOn'],
            'curation_note' => $video['curationNote'],
            'best_packs' => $video['bestPacks'],
            'formation_role' => $video['formationRole'],
            'verification_confidence' => $video['verificationConfidence'],
            'sensitivity_note' => $video['sensitivityNote'],
            'created_at' => $now,
            'updated_at' => $now,
        ];
    }

    /** @param array<string, mixed> $pack @return array<string, mixed> */
    private function packRow(int $catalogVersionId, array $pack, mixed $now): array
    {
        return [
            'catalog_version_id' => $catalogVersionId,
            'stable_id' => $pack['id'],
            'editorial_order' => $pack['order'],
            'start_day' => $pack['startDay'],
            'end_day' => $pack['endDay'],
            'title' => $pack['title'],
            'primary_struggle' => $pack['primaryStruggle'],
            'target_formation' => $pack['targetFormation'],
            'anchor' => $pack['anchor'],
            'scripture' => $pack['scripture'],
            'coverage_note' => $pack['coverageNote'],
            'created_at' => $now,
            'updated_at' => $now,
        ];
    }

    /** @param array<string, mixed> $day @return array<string, mixed> */
    private function dayRow(int $catalogVersionId, array $day, mixed $now): array
    {
        return [
            'catalog_version_id' => $catalogVersionId,
            'stable_id' => $day['id'],
            'canonical_day' => $day['day'],
            'week' => $day['week'],
            'pack_stable_id' => $day['packId'],
            'focus' => $day['focus'],
            'objective' => $day['objective'],
            'scripture' => $day['scripture'],
            'anchor' => $day['anchor'],
            'presentation' => $day['presentation'],
            'video_ids' => json_encode($day['videoIds'], JSON_THROW_ON_ERROR),
            'alternative_conditions' => json_encode($day['alternativeConditions'], JSON_THROW_ON_ERROR),
            'coverage_strength' => $day['coverageStrength'],
            'reflection' => $day['reflection'],
            'action' => $day['action'],
            'completion_rule' => $day['completionRule'],
            'on_complete' => $day['onComplete'],
            'on_incomplete' => $day['onIncomplete'],
            'created_at' => $now,
            'updated_at' => $now,
        ];
    }

    /** @param array<string, mixed> $rule @return array<string, mixed> */
    private function ruleRow(int $catalogVersionId, array $rule, mixed $now): array
    {
        return [
            'catalog_version_id' => $catalogVersionId,
            'stable_id' => $rule['id'],
            'priority' => $rule['priority'],
            'trigger' => $rule['trigger'],
            'eligibility' => $rule['eligibility'],
            'presentation' => $rule['presentation'],
            'option_labels' => json_encode($rule['optionLabels'], JSON_THROW_ON_ERROR),
            'progress_behavior' => $rule['progressBehavior'],
            'note' => $rule['note'],
            'created_at' => $now,
            'updated_at' => $now,
        ];
    }

    /** @param array<string, mixed> $catalog @return array{version:int, checksum:string, videos:int, packs:int, days:int, rules:int} */
    private function summary(array $catalog, string $checksum): array
    {
        return [
            'version' => $catalog['version'],
            'checksum' => $checksum,
            'videos' => count($catalog['videos']),
            'packs' => count($catalog['packs']),
            'days' => count($catalog['days']),
            'rules' => count($catalog['rules']),
        ];
    }
}
