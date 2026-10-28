<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;
use Illuminate\Support\Facades\DB;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Schedule::command('morning-notifications:send')->everyMinute()->withoutOverlapping();
Schedule::command('telegram-companion:send')->everyMinute()->withoutOverlapping();

/**
 * One-use linking codes are never useful after expiration.
 * Remove their hashed values without touching OAuth bindings or user data.
 */
Artisan::command('chatgpt:prune-link-codes', function () {
    $count = DB::table('chatgpt_account_link_codes')
        ->where('expires_at', '<=', now())->delete();
    $this->info('Expired ChatGPT link codes pruned: '.$count);
})->purpose('Delete expired SoulBuddy ChatGPT account-link codes');

Schedule::command('chatgpt:prune-link-codes')->dailyAt('03:30')->withoutOverlapping();
