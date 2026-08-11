<?php

use App\Http\Controllers\Api\PowerSyncTokenController;
use App\Http\Controllers\Api\PrayerDraftAttemptController;
use App\Http\Controllers\Api\PrayerDraftController;
use App\Http\Controllers\Api\SyncMutationController;
use Illuminate\Support\Facades\Route;

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/sync/token', PowerSyncTokenController::class);
    Route::post('/sync/mutations', SyncMutationController::class);
    Route::post('/prayer-drafts', PrayerDraftController::class)
        ->middleware('throttle:prayer-drafts');
    Route::delete('/prayer-drafts/{attemptId}', PrayerDraftAttemptController::class);
});
