<?php

namespace App\Http\Controllers\Api;

use App\Domain\GoalGuidance\GoalActionSuggestionService;
use App\Domain\GoalGuidance\GoalActionSuggestionUnavailable;
use App\Http\Controllers\Controller;
use App\Http\Requests\SuggestGoalActionsRequest;
use Illuminate\Http\JsonResponse;

class GoalActionSuggestionController extends Controller
{
    public function __invoke(
        SuggestGoalActionsRequest $request,
        GoalActionSuggestionService $service,
    ): JsonResponse {
        try {
            return response()->json([
                'suggestions' => $service->suggest($request->context()),
            ]);
        } catch (GoalActionSuggestionUnavailable) {
            return response()->json(['code' => 'suggestions_unavailable'], 503);
        }
    }
}
