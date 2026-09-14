<?php

namespace App\Http\Controllers\Api;

use App\Domain\Scripture\DailyScripture;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class DailyScriptureController extends Controller
{
    public function __invoke(Request $request, DailyScripture $scriptures): JsonResponse
    {
        $validated = $request->validate([
            'date' => ['sometimes', 'required', 'date_format:Y-m-d'],
            'timezone' => ['sometimes', 'required', 'timezone:all'],
        ]);
        $date = $validated['date'] ?? now($validated['timezone'] ?? 'UTC')->toDateString();

        return response()->json(['data' => $scriptures->forDate($date)])
            ->header('Cache-Control', 'no-cache');
    }
}
