<?php

use App\Http\Controllers\Web\AccountEmailConfirmationController;
use Illuminate\Support\Facades\Route;

Route::get('/app/verify', fn () => view('account-email-verify'));
Route::post('/auth/email/confirm', AccountEmailConfirmationController::class)
    ->middleware('throttle:account-email-challenges');

Route::get('/', function () {
    return view('welcome');
});
