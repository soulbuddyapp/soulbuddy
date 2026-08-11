<?php

namespace App\Http\Controllers\Api;

use App\Domain\PrayerDrafts\GeneratePrayerDraft;
use App\Domain\PrayerDrafts\PrayerDraftInvalidResponse;
use App\Domain\PrayerDrafts\PrayerDraftRateLimited;
use App\Domain\PrayerDrafts\PrayerDraftResult;
use App\Domain\PrayerDrafts\PrayerDraftUnavailable;
use App\Http\Controllers\Controller;
use App\Http\Requests\GeneratePrayerDraftRequest;
use App\Models\User;
use Illuminate\Contracts\Cache\LockTimeoutException;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Crypt;
use JsonException;
use Throwable;

class PrayerDraftController extends Controller
{
    public function __invoke(
        GeneratePrayerDraftRequest $request,
        GeneratePrayerDraft $generator,
    ): JsonResponse {
        $user = $request->user();
        abort_unless($user instanceof User, 401);
        $input = $request->toDomain($user);
        $cacheKey = $this->cacheKey($user, $input->attemptId);

        try {
            $draft = Cache::lock($cacheKey.':lock', 10)->block(
                5,
                function () use ($cacheKey, $generator, $input): PrayerDraftResult {
                    $cached = Cache::get($cacheKey);
                    if (is_string($cached)) {
                        try {
                            $decoded = json_decode(
                                Crypt::decryptString($cached),
                                true,
                                8,
                                JSON_THROW_ON_ERROR,
                            );
                            if (is_array($decoded)) {
                                return PrayerDraftResult::fromArray($decoded);
                            }
                        } catch (Throwable) {
                            Cache::forget($cacheKey);
                        }
                    }

                    $generated = $generator->handle($input);
                    Cache::put(
                        $cacheKey,
                        Crypt::encryptString(json_encode($generated->toArray(), JSON_THROW_ON_ERROR)),
                        now()->addMinutes(10),
                    );

                    return $generated;
                },
            );
        } catch (PrayerDraftRateLimited $exception) {
            $headers = $exception->retryAfter === null
                ? []
                : ['Retry-After' => (string) $exception->retryAfter];

            return response()->json(['code' => 'rate_limited'], 429, $headers);
        } catch (PrayerDraftUnavailable|LockTimeoutException) {
            return response()->json(['code' => 'temporarily_unavailable'], 503);
        } catch (PrayerDraftInvalidResponse|JsonException) {
            return response()->json(['code' => 'draft_needs_attention'], 502);
        }

        return response()->json([
            'attempt_id' => $input->attemptId,
            'prompt_version' => (string) config('services.deepseek.prompt_version'),
            'disclosure_version' => (string) config('services.deepseek.disclosure_version'),
            'draft' => $draft->toArray(),
        ]);
    }

    private function cacheKey(User $user, string $attemptId): string
    {
        return "prayer-draft:{$user->public_id}:{$attemptId}";
    }
}
