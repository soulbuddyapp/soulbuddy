<?php

namespace App\Domain\PrayerReleases;

use App\Models\LibraryPrayer;
use App\Models\PrayerRelease;
use App\Models\PrayerReleaseItem;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;

/**
 * Publishes one validated release: its canonical library prayers, the ordered
 * release items that link them, and the release record itself.
 *
 * Every write uses a deterministic identifier, so re-running the seeder repairs
 * a partial deployment instead of duplicating content. Nothing a person has done
 * is rewritten: helpful counts, an earlier publish date, an archive, and every
 * existing selection or download survive.
 */
class PrayerReleasePublisher
{
    public function publish(ReleaseContent $release, ?string $publishedAt = null): PrayerRelease
    {
        $publishMoment = $this->resolvePublishedAt($publishedAt);

        return DB::transaction(function () use ($release, $publishMoment): PrayerRelease {
            $record = PrayerRelease::query()
                ->where('slug', $release->slug)
                ->lockForUpdate()
                ->first();

            $attributes = [
                'slug' => $release->slug,
                'title' => $release->title,
                'discovery_label' => $release->discoveryLabel,
                'discovery_detail' => $release->discoveryDetail,
                'preparation_text' => $release->preparationText,
                'published_at' => $record?->published_at === null
                    ? $publishMoment
                    : $this->earliest($record->published_at, $publishMoment),
            ];

            if ($record === null) {
                $record = new PrayerRelease;
                $record->forceFill(['id' => $release->releaseId()] + $attributes + ['archived_at' => null]);
                $record->save();
            } else {
                $record->forceFill($attributes)->save();
            }

            foreach ($release->items as $item) {
                $this->publishItem($release, $record, $item, $record->published_at ?? $publishMoment);
            }

            return $record->fresh('items');
        }, attempts: 3);
    }

    /**
     * A narration asset is only ever kept when it speaks this exact content.
     */
    public function attachNarration(
        ReleaseContent $release,
        int $sortOrder,
        string $uri,
        string $transcriptSha256,
    ): PrayerReleaseItem {
        $item = $release->items[$sortOrder] ?? null;
        if ($item === null || $item->sortOrder !== $sortOrder) {
            throw new InvalidArgumentException("Unknown prayer release position {$sortOrder}.");
        }
        if (! hash_equals($item->contentHash(), $transcriptSha256)) {
            throw new InvalidArgumentException(
                "Narration for release position {$sortOrder} does not match the approved content."
            );
        }

        $releaseItem = PrayerReleaseItem::query()
            ->whereKey($release->itemId($sortOrder))
            ->lockForUpdate()
            ->firstOrFail();
        $releaseItem->forceFill([
            'narration_uri' => $uri,
            'narration_content_sha256' => $transcriptSha256,
        ])->save();

        return $releaseItem;
    }

    private function publishItem(
        ReleaseContent $release,
        PrayerRelease $record,
        ReleaseItem $item,
        Carbon $publishMoment,
    ): void {
        $prayerId = $release->libraryPrayerId($item->sortOrder);
        $prayer = LibraryPrayer::query()->whereKey($prayerId)->lockForUpdate()->first();

        $prayerAttributes = [
            'title' => $item->title,
            'body' => $item->body,
            'grounding' => $item->grounding,
            'language_style' => $item->languageStyle,
            'purpose' => $item->purpose,
            'action' => $item->action,
            'published_at' => $prayer?->published_at === null
                ? $publishMoment
                : $this->earliest($prayer->published_at, $publishMoment),
        ];

        if ($prayer === null) {
            $prayer = new LibraryPrayer;
            $prayer->forceFill(['id' => $prayerId, 'helpful_count' => 0] + $prayerAttributes + ['archived_at' => null]);
        } else {
            $prayer->forceFill($prayerAttributes);
        }

        if (! hash_equals($item->contentHash(), ReleaseContent::contentHash($prayer->title, $prayer->body))) {
            throw new InvalidReleaseContent(
                "Prayer release item {$item->sortOrder} no longer matches its approved content hash."
            );
        }

        $prayer->save();

        $releaseItem = PrayerReleaseItem::query()
            ->whereKey($release->itemId($item->sortOrder))
            ->lockForUpdate()
            ->first();

        $releaseItemAttributes = [
            'release_id' => $record->id,
            'library_prayer_id' => $prayer->id,
            'kind' => $item->kind,
            'sort_order' => $item->sortOrder,
            'content_sha256' => $item->contentHash(),
            'practice_mode' => $item->practice?->mode,
            'practice_steps' => $item->practice === null
                ? null
                : array_map(
                    static fn (RepetitionStep $step): array => [
                        'phrase' => $step->phrase,
                        'target_count' => $step->targetCount,
                        'source_line' => $step->sourceLine,
                    ],
                    $item->practice->steps,
                ),
        ];

        if ($releaseItem === null) {
            $releaseItem = new PrayerReleaseItem;
            $releaseItem->forceFill(['id' => $release->itemId($item->sortOrder)] + $releaseItemAttributes);
        } else {
            $releaseItem->forceFill($releaseItemAttributes);
            if (! $releaseItem->narrationMatchesContent()) {
                // A stale asset is dropped rather than spoken over different words.
                $releaseItem->forceFill([
                    'narration_uri' => null,
                    'narration_content_sha256' => null,
                ]);
            }
        }

        $releaseItem->save();
    }

    private function resolvePublishedAt(?string $publishedAt): Carbon
    {
        $value = trim((string) ($publishedAt ?? config('prayer_releases.published_at')));
        if ($value === '') {
            throw new InvalidArgumentException('A prayer release needs an explicit published_at date.');
        }

        try {
            return Carbon::parse($value)->utc();
        } catch (\Throwable) {
            throw new InvalidArgumentException('A prayer release published_at must be a parseable UTC date.');
        }
    }

    private function earliest(Carbon $current, Carbon $candidate): Carbon
    {
        return $current->lessThanOrEqualTo($candidate) ? $current : $candidate;
    }
}
