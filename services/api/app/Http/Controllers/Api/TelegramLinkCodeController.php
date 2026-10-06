<?php

namespace App\Http\Controllers\Api;

use App\Domain\Companions\TelegramLinkService;
use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TelegramLinkCodeController extends Controller
{
    public function __invoke(Request $request, TelegramLinkService $links): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        if (trim((string) config('services.telegram.bot_username')) === '') {
            throw new HttpResponseException(response()->json([
                'message' => 'Telegram is unavailable.',
            ], 503));
        }

        return response()->json($links->issue($user), 202);
    }
}
