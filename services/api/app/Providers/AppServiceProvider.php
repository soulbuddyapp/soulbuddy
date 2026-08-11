<?php

namespace App\Providers;

use App\Domain\PrayerDrafts\DeepSeekPrayerDraftProvider;
use App\Domain\PrayerDrafts\PrayerDraftProvider;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->bind(PrayerDraftProvider::class, DeepSeekPrayerDraftProvider::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        RateLimiter::for('prayer-drafts', function (Request $request): array {
            $userKey = (string) ($request->user()?->public_id ?? 'guest');

            return [
                Limit::perHour(10)->by('prayer-draft:user-hour:'.$userKey),
                Limit::perDay(30)->by('prayer-draft:user-day:'.$userKey),
                Limit::perHour(30)->by('prayer-draft:ip-hour:'.$request->ip()),
            ];
        });
    }
}
