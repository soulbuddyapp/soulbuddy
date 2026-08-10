<?php

use App\Http\Controllers\Api\SyncMutationController;
use Illuminate\Support\Facades\Route;

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/sync/mutations', SyncMutationController::class);
});
