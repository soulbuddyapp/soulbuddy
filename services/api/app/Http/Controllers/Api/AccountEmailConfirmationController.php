<?php

namespace App\Http\Controllers\Api;

use App\Domain\Accounts\AccountEmailChallengeService;
use App\Http\Controllers\Controller;
use App\Http\Requests\AccountEmailConfirmationRequest;
use App\Models\User;
use Illuminate\Http\JsonResponse;

class AccountEmailConfirmationController extends Controller
{
    public function __invoke(
        AccountEmailConfirmationRequest $request,
        AccountEmailChallengeService $challenges,
    ): JsonResponse {
        /** @var User $user */
        $user = $request->user();
        $validated = $request->validated();
        $challenges->confirm($user, $validated['challenge_id'], $validated['token']);

        return response()->json([
            'status' => 'verified',
            'display_name' => $user->fresh()->name,
        ]);
    }
}
