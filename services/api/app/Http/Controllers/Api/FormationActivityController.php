<?php

namespace App\Http\Controllers\Api;

use App\Domain\Companions\TelegramCompanionService;
use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class FormationActivityController extends Controller
{
    public function __invoke(Request $request, TelegramCompanionService $companion): JsonResponse
    {
        $validated = $request->validate([
            'formation_video_id' => ['required', 'string', 'max:120', 'regex:/^[A-Za-z0-9_-]+$/'],
            'activity_type' => ['required', 'in:opened,completed'],
        ]);
        /** @var User $user */
        $user = $request->user();
        $companion->recordFormationActivity(
            $user->id,
            $validated['formation_video_id'],
            'app',
            $validated['activity_type'],
        );

        return response()->json(['recorded' => true], 201);
    }
}
