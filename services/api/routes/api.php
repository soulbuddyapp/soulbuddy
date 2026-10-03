<?php

use App\Http\Controllers\Api\AccountEmailChallengeController;
use App\Http\Controllers\Api\AccountEmailConfirmationController;
use App\Http\Controllers\Api\CircleController;
use App\Http\Controllers\Api\CircleReportController;
use App\Http\Controllers\Api\DailyScriptureController;
use App\Http\Controllers\Api\FormationCatalogController;
use App\Http\Controllers\Api\GoalActionSuggestionController;
use App\Http\Controllers\Api\InstallationPushController;
use App\Http\Controllers\Api\InstallationSessionController;
use App\Http\Controllers\Api\PowerSyncTokenController;
use App\Http\Controllers\Api\PrayerNarrationController;
use App\Http\Controllers\Api\PrayerNarrationPlaybackController;
use App\Http\Controllers\Api\SyncMutationController;
use Illuminate\Support\Facades\Route;

Route::get('/scriptures/daily', DailyScriptureController::class)
    ->middleware('throttle:120,1');

Route::get('/formation/catalog', FormationCatalogController::class)
    ->middleware('throttle:120,1');

Route::post('/installations/session', InstallationSessionController::class)
    ->middleware('throttle:installation-sessions');

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/account/email/challenges', AccountEmailChallengeController::class)
        ->middleware('throttle:account-email-challenges');
    Route::post('/account/email/confirm', AccountEmailConfirmationController::class)
        ->middleware('throttle:account-email-challenges');
    Route::post('/installations/push', InstallationPushController::class);
    Route::get('/sync/token', PowerSyncTokenController::class);
    Route::post('/sync/mutations', SyncMutationController::class);

    Route::post('/goal-action-suggestions', GoalActionSuggestionController::class)
        ->middleware('throttle:goal-action-suggestions');

    Route::get('/circles', [CircleController::class, 'index']);
    Route::get('/circles/mine', [CircleController::class, 'mine']);
    Route::post('/circles', [CircleController::class, 'store']);
    Route::get('/circles/{circle:public_id}', [CircleController::class, 'show']);
    Route::patch('/circles/{circle:public_id}', [CircleController::class, 'update']);
    Route::post('/circles/{circle:public_id}/reports', CircleReportController::class);

    Route::post('/prayer-narrations', PrayerNarrationController::class)
        ->middleware('throttle:prayer-narrations');
    Route::get('/prayer-narrations/{revision}/{hash}', PrayerNarrationPlaybackController::class)
        ->middleware('signed')
        ->name('prayer-narrations.playback');
});
