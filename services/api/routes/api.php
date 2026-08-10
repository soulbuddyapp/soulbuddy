<?php

use App\Http\Controllers\Api\PowerSyncTokenController;
use App\Http\Controllers\Api\SyncMutationController;
use Illuminate\Support\Facades\Route;

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/sync/token', PowerSyncTokenController::class);
    Route::post('/sync/mutations', SyncMutationController::class);
});
