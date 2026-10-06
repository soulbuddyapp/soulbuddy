<?php

namespace App\Domain\PrayerReleases;

use App\Models\PrayerRelease;
use App\Models\PrayerReleaseDownload;
use App\Models\PrayerReleaseItem;

/**
 * Shapes release responses.
 *
 * Discovery carries metadata only: the exact bodies stay out of it until the
 * person has deliberately added the collection. The add response carries the
 * complete content so the app can keep it available offline.
 */
final class PrayerReleasePresenter
{
    /** @return array<string, mixed> */
    public static function discovery(PrayerRelease $release, ?PrayerReleaseDownload $download, array $preference): array
    {
        return [
            'id' => $release->id,
            'slug' => $release->slug,
            'title' => $release->title,
            'discovery_label' => $release->discovery_label,
            'discovery_detail' => $release->discovery_detail,
            'published_at' => $release->published_at?->toIso8601String(),
            'added_at' => $download?->downloaded_at?->toIso8601String(),
            'preference' => self::preference($preference),
            'items' => $release->items->map(
                static fn (PrayerReleaseItem $item): array => self::itemMetadata($item),
            )->all(),
        ];
    }

    /** @return array<string, mixed> */
    public static function added(PrayerRelease $release, PrayerReleaseDownload $download, array $preference): array
    {
        // The add response carries the complete content; `+` would keep the
        // metadata-only `items` already present in the discovery shape.
        return [
            ...self::discovery($release, $download, $preference),
            'preparation_text' => $release->getAttribute('preparation_text'),
            'items' => $release->items->map(
                static fn (PrayerReleaseItem $item): array => self::itemContent($item),
            )->all(),
        ];
    }

    /**
     * Metadata before an add: order, kind, and eligibility only. No wording.
     *
     * @return array<string, mixed>
     */
    public static function itemMetadata(PrayerReleaseItem $item): array
    {
        return [
            'id' => $item->id,
            'sort_order' => (int) $item->getAttribute('sort_order'),
            'kind' => $item->kind,
            'library_prayer_id' => $item->library_prayer_id,
            'title' => $item->libraryPrayer?->title,
            'has_attention_practice' => $item->hasRepetitionPractice(),
            'narration_available' => $item->narrationMatchesContent(),
        ];
    }

    /**
     * Full content after an add, so the collection works offline.
     *
     * @return array<string, mixed>
     */
    public static function itemContent(PrayerReleaseItem $item): array
    {
        $prayer = $item->libraryPrayer;

        return self::itemMetadata($item) + [
            'body' => $prayer?->body,
            'grounding' => $prayer?->grounding,
            'language_style' => $prayer?->language_style,
            'purpose' => $prayer?->purpose,
            'action' => $prayer?->action,
            'content_sha256' => $item->content_sha256,
            'practice' => $item->practice_mode === null
                ? null
                : [
                    'mode' => $item->practice_mode,
                    'steps' => array_map(
                        static fn (array $step): array => [
                            'phrase' => $step['phrase'],
                            'target_count' => (int) $step['target_count'],
                            'source_line' => $step['source_line'],
                        ],
                        $item->practice_steps ?? [],
                    ),
                ],
        ];
    }

    /**
     * @param  array<string, mixed>  $preference
     * @return array<string, mixed>
     */
    public static function preference(array $preference): array
    {
        return [
            'weekly_enabled' => (bool) $preference['weekly_enabled'],
            'notification_enabled' => (bool) $preference['notification_enabled'],
            'time_zone' => $preference['time_zone'] ?? null,
        ];
    }
}
