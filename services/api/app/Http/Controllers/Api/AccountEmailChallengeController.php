<?php

namespace App\Http\Controllers\Api;

use App\Domain\Accounts\AccountEmailChallengeService;
use App\Http\Controllers\Controller;
use App\Http\Requests\AccountEmailChallengeRequest;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\ValidationException;

class AccountEmailChallengeController extends Controller
{
    public function __invoke(
        AccountEmailChallengeRequest $request,
        AccountEmailChallengeService $challenges,
    ): JsonResponse {
        /** @var User $user */
        $user = $request->user();
        $email = $request->validated('email');

        $taken = User::query()
            ->where('email', $email)
            ->whereKeyNot($user->id)
            ->exists();
        if ($taken) {
            throw ValidationException::withMessages(['email' => ['unavailable']]);
        }

        $challenge = $challenges->issue($user, $email);

        return response()->json([
            'challenge_id' => $challenge['id'],
            'expires_at' => $challenge['expires_at'],
        ], 202);
    }
}
