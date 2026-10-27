<?php

use App\Http\Controllers\Web\AccountEmailConfirmationController;
use App\Http\Controllers\Web\TelegramWebhookController;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Chatgpt\McpController;

Route::get('/app/verify', fn () => view('account-email-verify'));
Route::post('/auth/email/confirm', AccountEmailConfirmationController::class)
    ->middleware('throttle:account-email-challenges');
Route::post('/integrations/telegram/webhook', TelegramWebhookController::class)
    ->middleware('throttle:120,1');

Route::get('/', function () {
    return view('welcome');
});

// Public ChatGPT MCP endpoint. Private tool calls require a validated OAuth bearer token.
Route::post('/mcp', [McpController::class, 'handle'])->middleware('throttle:60,1');
Route::get('/mcp', fn () => response()->json(['message' => 'Use MCP Streamable HTTP POST.'], 405));
Route::get('/.well-known/oauth-protected-resource', [McpController::class, 'protectedResource']);
