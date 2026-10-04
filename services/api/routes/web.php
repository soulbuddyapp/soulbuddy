<?php

use App\Http\Controllers\Web\AccountEmailConfirmationController;
use App\Http\Controllers\Web\TelegramWebhookController;
use Illuminate\Support\Facades\Route;

Route::get('/app/verify', fn () => view('account-email-verify'));
Route::post('/auth/email/confirm', AccountEmailConfirmationController::class)
    ->middleware('throttle:account-email-challenges');
Route::post('/integrations/telegram/webhook', TelegramWebhookController::class)
    ->middleware('throttle:120,1');

Route::get('/', function () {
    return view('welcome');
});
