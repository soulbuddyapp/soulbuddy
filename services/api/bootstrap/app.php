<?php

use App\Domain\Sync\CommitmentSyncMutationValidator;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->validateCsrfTokens(except: ['integrations/telegram/webhook']);
        // Reviewed Commitment text and operation fingerprints retain exact bytes.
        $middleware->trimStrings(except: [fn ($request) => $request->is('api/sync/mutations')
            && collect($request->input('operations', []))->contains(fn ($operation) => is_array($operation) && is_string($operation['table'] ?? null)
                && CommitmentSyncMutationValidator::supports($operation['table'] ?? ''))]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        //
    })->create();
