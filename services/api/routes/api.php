<?php

use App\Http\Controllers\Api\CircleController;
use App\Http\Controllers\Api\CircleReportController;
use App\Http\Controllers\Api\InstallationSessionController;
use App\Http\Controllers\Api\PowerSyncTokenController;
use App\Http\Controllers\Api\PrayerNarrationController;
use App\Http\Controllers\Api\PrayerNarrationPlaybackController;
use App\Http\Controllers\Api\SyncMutationController;
use Illuminate\Support\Facades\Route;

Route::post('/installations/session', InstallationSessionController::class)
    ->middleware('throttle:installation-sessions');

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/sync/token', PowerSyncTokenController::class);
    Route::post('/sync/mutations', SyncMutationController::class);

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
