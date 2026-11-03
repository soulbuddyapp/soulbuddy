<?php

namespace App\Http\Controllers\Api;

use App\Domain\PrayerNarrations\PrayerNarrationProvider;
use App\Domain\PrayerNarrations\PrayerNarrationUnavailable;
use App\Http\Controllers\Controller;
use App\Http\Requests\GeneratePrayerNarrationRequest;
use App\Models\PersonalPrayerRevision;
use App\Models\User;
use Illuminate\Contracts\Cache\LockTimeoutException;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\URL;

class PrayerNarrationController extends Controller
{
    public function __invoke(
        GeneratePrayerNarrationRequest $request,
        PrayerNarrationProvider $provider,
    ): JsonResponse {
        $user = $request->user();
        abort_unless($user instanceof User, 401);
        $validated = $request->validated();
        $revision = PersonalPrayerRevision::query()
            ->whereKey($validated['prayer_revision_id'])
            ->where('prayer_id', $validated['personal_prayer_id'])
            ->where('user_id', $user->id)
            ->firstOrFail();
        if ($revision->content_format === 'audio') {
            return response()->json(['code' => 'recorded_prayer_has_audio'], 422);
        }
        if (mb_strlen($revision->body) > 2000) {
            return response()->json(['code' => 'narration_too_long'], 422);
        }

        $hash = hash('sha256', implode('|', [
            'prayer-narration-v1',
            $revision->id,
            $revision->body,
            config('services.deepgram.model'),
            config('services.deepgram.encoding'),
            config('services.deepgram.bit_rate'),
        ]));
        $path = "prayer-narrations/{$user->public_id}/{$hash}.enc";

        try {
            Cache::lock("prayer-narration:{$hash}:lock", 60)->block(
                10,
                function () use ($path, $provider, $revision): void {
                    if (Storage::disk('local')->exists($path)) {
                        return;
                    }
                    $audio = $provider->synthesize($revision->body);
                    if ($audio->contentType !== 'audio/mpeg'
                        || $audio->bytes === ''
                        || strlen($audio->bytes) > 2_000_000) {
                        throw new PrayerNarrationUnavailable;
                    }
                    $encrypted = Crypt::encryptString(base64_encode($audio->bytes));
                    if (! Storage::disk('local')->put($path, $encrypted)) {
                        throw new PrayerNarrationUnavailable;
                    }
                },
            );
        } catch (PrayerNarrationUnavailable|LockTimeoutException) {
            return response()->json(['code' => 'narration_unavailable'], 503);
        }

        return response()->json([
            'status' => 'ready',
            'revision_id' => $revision->id,
            'content_type' => 'audio/mpeg',
            'disclosure_version' => (string) config('services.deepgram.disclosure_version'),
            'playback_url' => URL::temporarySignedRoute(
                'prayer-narrations.playback',
                now()->addMinutes(5),
                ['revision' => $revision->id, 'hash' => $hash],
            ),
        ]);
    }
}

