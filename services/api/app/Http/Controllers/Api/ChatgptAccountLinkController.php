<?php

namespace App\Http\Controllers\Api;

use App\Domain\LifePlanning\ChatgptAccountLinks;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ChatgptAccountLinkController extends Controller
{
    public function status(Request $request): JsonResponse
    {
        // Only the local signed-in owner may discover this association.
        // Never disclose the provider subject or a personal email here.
        return response()->json([
            'linked' => DB::table('chatgpt_oauth_identities')
                ->where('user_id', $request->user()->id)->exists(),
        ])->header('Cache-Control', 'no-store');
    }

    public function issue(Request $request, ChatgptAccountLinks $links): JsonResponse
    {
        $validated = $request->validate(['confirmed' => ['required', 'accepted']]);

        return response()->json($links->issueCode($request->user(), $validated), 201)
            ->header('Cache-Control', 'no-store');
    }

    public function unlink(Request $request, ChatgptAccountLinks $links): JsonResponse
    {
        $validated = $request->validate(['confirmed' => ['required', 'accepted']]);

        return response()->json($links->unlink($request->user(), $validated))
            ->header('Cache-Control', 'no-store');
    }
}
