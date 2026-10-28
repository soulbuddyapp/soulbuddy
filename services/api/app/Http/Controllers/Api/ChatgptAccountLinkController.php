<?php

namespace App\Http\Controllers\Api;

use App\Domain\LifePlanning\ChatgptAccountLinks;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class ChatgptAccountLinkController extends Controller
{
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
