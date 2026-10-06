<?php

namespace App\Http\Controllers\Api;

use App\Domain\PrayerReleases\PrayerReleasePreferenceService;
use App\Domain\PrayerReleases\PrayerReleasePresenter;
use App\Models\PrayerRelease;
use App\Models\PrayerReleaseDownload;
use Illuminate\Http\JsonResponse;
use App\Http\Controllers\Controller;
use Illuminate\Database\QueryException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Discovery and the deliberate, idempotent add.
 *
 * A release is listed once it is published and unarchived. Adding it is the only
 * way its prayers enter a library, and adding twice is the same as adding once.
 */
final class PrayerReleaseController extends Controller
{
    public function index(Request $request, PrayerReleasePreferenceService $preferences): JsonResponse
    {
        $releases = PrayerRelease::query()
            ->whereNotNull('published_at')
            ->where('published_at', '<=', now())
            ->whereNull('archived_at')
            ->with('items.libraryPrayer')
            ->orderByDesc('published_at')
            ->orderBy('id')
            ->get();

        $downloads = PrayerReleaseDownload::query()
            ->where('user_id', $request->user()->id)
            ->get()
            ->keyBy('release_id');

        $preference = $preferences->current($request->user());

        return response()->json([
            'releases' => $releases->map(
                static fn (PrayerRelease $release): array => PrayerReleasePresenter::discovery(
                    $release,
                    $downloads->get($release->id),
                    $preference,
                ),
            )->all(),
            'preference' => PrayerReleasePresenter::preference($preference),
        ]);
    }

    public function store(Request $request, PrayerRelease $prayerRelease, PrayerReleasePreferenceService $preferences): JsonResponse
    {
        abort_unless(
            $prayerRelease->isVisible(),
            404,
        );

        // A repeated add is the same outcome as the first, so the stored download
        // date never moves.
        $created = DB::transaction(function () use ($request, $prayerRelease): bool {
            $existing = PrayerReleaseDownload::query()
                ->where('user_id', $request->user()->id)
                ->where('release_id', $prayerRelease->id)
                ->lockForUpdate()
                ->first();

            if ($existing !== null) {
                return false;
            }

            try {
                PrayerReleaseDownload::query()->create([
                    'id' => (string) Str::uuid(),
                    'user_id' => $request->user()->id,
                    'release_id' => $prayerRelease->id,
                    'downloaded_at' => now(),
                ]);

                return true;
            } catch (QueryException $exception) {
                if (! str_starts_with((string) ($exception->errorInfo[0] ?? $exception->getCode()), '23')) {
                    throw $exception;
                }

                // A concurrent add already wrote the record; that is a success too.
                return false;
            }
        }, attempts: 3);

        $download = PrayerReleaseDownload::query()
            ->where('user_id', $request->user()->id)
            ->where('release_id', $prayerRelease->id)
            ->firstOrFail();

        return response()->json(
            PrayerReleasePresenter::added(
                $prayerRelease->load('items.libraryPrayer'),
                $download,
                $preferences->current($request->user()),
            ),
            $created ? 201 : 200,
        );
    }
}
