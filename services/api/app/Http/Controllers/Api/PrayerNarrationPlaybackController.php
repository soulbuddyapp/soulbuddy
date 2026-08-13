<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PersonalPrayerRevision;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\Response;
use Throwable;

class PrayerNarrationPlaybackController extends Controller
{
    public function __invoke(Request $request, string $revision, string $hash): Response
    {
        abort_unless($request->hasValidSignature(), 403);
        $user = $request->user();
        abort_unless($user instanceof User, 401);
        PersonalPrayerRevision::query()
            ->whereKey($revision)
            ->where('user_id', $user->id)
            ->firstOrFail();
        abort_unless(preg_match('/^[a-f0-9]{64}$/', $hash) === 1, 404);
        $path = "prayer-narrations/{$user->public_id}/{$hash}.enc";
        abort_unless(Storage::disk('local')->exists($path), 404);

        try {
            $bytes = base64_decode(
                Crypt::decryptString(Storage::disk('local')->get($path)),
                true,
            );
        } catch (Throwable) {
            abort(404);
        }
        abort_unless(is_string($bytes), 404);

        return response($bytes, 200, [
            'Content-Type' => 'audio/mpeg',
            'Content-Length' => (string) strlen($bytes),
            'Cache-Control' => 'private, no-store',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }
}
