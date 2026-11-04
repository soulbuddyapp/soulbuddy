<?php

namespace App\Http\Controllers\Api;

use App\Domain\PrayerReleases\PrayerReleasePreferenceService;
use App\Domain\PrayerReleases\PrayerReleasePresenter;
use App\Http\Controllers\Controller;
use App\Http\Requests\StorePrayerReleasePreferenceRequest;
use Illuminate\Http\JsonResponse;

final class PrayerReleasePreferenceController extends Controller
{
    public function __invoke(
        StorePrayerReleasePreferenceRequest $request,
        PrayerReleasePreferenceService $preferences,
    ): JsonResponse {
        $validated = $request->validated();

        $preference = $preferences->store($request->user(), [
            'weekly_enabled' => (bool) $validated['weekly_enabled'],
            'notification_enabled' => (bool) $validated['notification_enabled'],
            'time_zone' => $validated['time_zone'] ?? null,
        ]);

        return response()->json([
            'preference' => PrayerReleasePresenter::preference([
                'weekly_enabled' => $preference->weekly_enabled,
                'notification_enabled' => $preference->notification_enabled,
                'time_zone' => $preference->time_zone,
            ]),
        ]);
    }
}
