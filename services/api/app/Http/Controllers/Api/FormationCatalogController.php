<?php

namespace App\Http\Controllers\Api;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;

final class FormationCatalogController
{
    public function __invoke(Request $request): JsonResponse|Response
    {
        $version = DB::table('formation_catalog_versions')->where('published', true)->first();
        abort_if($version === null, 404);

        $etag = '"'.$version->checksum.'"';
        if ($request->header('If-None-Match') === $etag) {
            return response('', 304)->header('ETag', $etag);
        }

        $data = [
            'version' => $version->version,
            'sourceSha256' => $version->source_sha256,
            'videos' => DB::table('formation_videos')
                ->where('catalog_version_id', $version->id)
                ->orderBy('stable_id')
                ->get()
                ->map(fn (object $video): array => [
                    'id' => $video->stable_id,
                    'title' => $video->title,
                    'channel' => $video->channel,
                    'youtubeUrl' => $video->youtube_url,
                    'youtubeId' => $video->youtube_id,
                    'runtimeSeconds' => $video->runtime_seconds,
                    'status' => $video->status,
                    'primaryTopic' => $video->primary_topic,
                    'secondaryUse' => $video->secondary_use,
                    'viceTarget' => $video->vice_target,
                    'virtueTarget' => $video->virtue_target,
                    'difficulty' => $video->difficulty,
                    'theologicalLens' => $video->theological_lens,
                    'officialRuntimeSource' => $video->official_runtime_source,
                    'youtubeVerificationSource' => $video->youtube_verification_source,
                    'verifiedOn' => $video->verified_on,
                    'curationNote' => $video->curation_note,
                    'bestPacks' => $video->best_packs,
                    'formationRole' => $video->formation_role,
                    'verificationConfidence' => $video->verification_confidence,
                    'sensitivityNote' => $video->sensitivity_note,
                ])->all(),
            'packs' => DB::table('formation_packs')
                ->where('catalog_version_id', $version->id)
                ->orderBy('editorial_order')
                ->get()
                ->map(fn (object $pack): array => [
                    'id' => $pack->stable_id,
                    'order' => $pack->editorial_order,
                    'startDay' => $pack->start_day,
                    'endDay' => $pack->end_day,
                    'title' => $pack->title,
                    'primaryStruggle' => $pack->primary_struggle,
                    'targetFormation' => $pack->target_formation,
                    'anchor' => $pack->anchor,
                    'scripture' => $pack->scripture,
                    'coverageNote' => $pack->coverage_note,
                ])->all(),
            'days' => DB::table('formation_days')
                ->where('catalog_version_id', $version->id)
                ->orderBy('canonical_day')
                ->get()
                ->map(fn (object $day): array => [
                    'id' => $day->stable_id,
                    'day' => $day->canonical_day,
                    'week' => $day->week,
                    'packId' => $day->pack_stable_id,
                    'focus' => $day->focus,
                    'objective' => $day->objective,
                    'scripture' => $day->scripture,
                    'anchor' => $day->anchor,
                    'presentation' => $day->presentation,
                    'videoIds' => json_decode($day->video_ids, true, flags: JSON_THROW_ON_ERROR),
                    'alternativeConditions' => json_decode($day->alternative_conditions, true, flags: JSON_THROW_ON_ERROR),
                    'coverageStrength' => $day->coverage_strength,
                    'reflection' => $day->reflection,
                    'action' => $day->action,
                    'completionRule' => $day->completion_rule,
                    'onComplete' => $day->on_complete,
                    'onIncomplete' => $day->on_incomplete,
                ])->all(),
            'rules' => DB::table('formation_rules')
                ->where('catalog_version_id', $version->id)
                ->orderBy('priority')
                ->get()
                ->map(fn (object $rule): array => [
                    'id' => $rule->stable_id,
                    'priority' => $rule->priority,
                    'trigger' => $rule->trigger,
                    'eligibility' => $rule->eligibility,
                    'presentation' => $rule->presentation,
                    'optionLabels' => json_decode($rule->option_labels, true, flags: JSON_THROW_ON_ERROR),
                    'progressBehavior' => $rule->progress_behavior,
                    'note' => $rule->note,
                ])->all(),
        ];

        return response()->json(['data' => $data])
            ->header('Cache-Control', 'public, max-age=300, stale-if-error=86400')
            ->header('ETag', $etag);
    }
}
