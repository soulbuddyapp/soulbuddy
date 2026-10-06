<?php

namespace App\Http\Controllers\Web;

use App\Domain\Accounts\AccountEmailChallengeService;
use App\Http\Controllers\Controller;
use App\Http\Requests\AccountEmailConfirmationRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;

class AccountEmailConfirmationController extends Controller
{
    public function __invoke(
        AccountEmailConfirmationRequest $request,
        AccountEmailChallengeService $challenges,
    ): JsonResponse {
        $validated = $request->validated();
        $user = $challenges->confirmLink($validated['challenge_id'], $validated['token']);

        Auth::login($user);
        $request->session()->regenerate();

        return response()->json(['status' => 'verified']);
    }
}
