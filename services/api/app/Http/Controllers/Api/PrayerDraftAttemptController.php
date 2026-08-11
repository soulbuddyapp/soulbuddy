<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Str;

class PrayerDraftAttemptController extends Controller
{
    public function __invoke(Request $request, string $attemptId): Response
    {
        $user = $request->user();
        abort_unless($user instanceof User, 401);
        if (Str::isUuid($attemptId)) {
            Cache::forget("prayer-draft:{$user->public_id}:{$attemptId}");
        }

        return response()->noContent();
    }
}
