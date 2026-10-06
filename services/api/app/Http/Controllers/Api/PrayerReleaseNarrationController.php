<?php

namespace App\Http\Controllers\Api;

use App\Domain\PrayerReleases\ReleaseContent;
use App\Http\Controllers\Controller;
use App\Models\PrayerReleaseDownload;
use App\Models\PrayerReleaseItem;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Speaks a release item only from the exact text the person can see.
 *
 * An item is eligible once the person has added its collection. Narration is
 * offered only when the item's own recorded asset matches its content hash;
 * otherwise the caller keeps the in-app text.
 */
class PrayerReleaseNarrationController extends Controller
{
    /**
     * The default spoken pace for a release item.
     */
    public const DEFAULT_SPEED = 0.85;

    public const AVAILABLE_SPEEDS = [0.70, 0.85, 1.0, 1.15];

    public function __invoke(Request $request, PrayerReleaseItem $releaseItem): JsonResponse
    {
        $item = PrayerReleaseItem::query()
            ->whereKey($releaseItem->id)
            ->with(['libraryPrayer', 'release'])
            ->firstOrFail();

        $added = PrayerReleaseDownload::query()
            ->where('user_id', $request->user()->id)
            ->where('release_id', $item->release_id)
            ->exists();

        if (! $added || ! $item->release->isVisible()) {
            // An unadded collection is not available for narration.
            return response()->json(['code' => 'release_not_added'], 404);
        }

        $prayer = $item->libraryPrayer;
        if ($prayer === null) {
            return response()->json(['code' => 'narration_unavailable'], 503);
        }

        // The spoken transcript must be this exact content.
        $declaredHash = ReleaseContent::contentHash($prayer->title, $prayer->body);
        if (! hash_equals($item->content_sha256, $declaredHash)) {
            return response()->json(['code' => 'narration_content_mismatch'], 503);
        }

        if (! $item->narrationMatchesContent() || $item->narration_uri === null) {
            return response()->json([
                'status' => 'text_only',
                'default_speed' => self::DEFAULT_SPEED,
                'available_speeds' => self::AVAILABLE_SPEEDS,
                'content_sha256' => $declaredHash,
                'text' => $prayer->body,
            ]);
        }

        return response()->json([
            'status' => 'ready',
            'default_speed' => self::DEFAULT_SPEED,
            'available_speeds' => self::AVAILABLE_SPEEDS,
            'content_sha256' => $declaredHash,
            'narration_uri' => $item->narration_uri,
        ]);
    }
}
