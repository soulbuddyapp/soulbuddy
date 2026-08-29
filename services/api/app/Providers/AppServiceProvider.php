<?php

namespace App\Providers;

use App\Domain\PrayerNarrations\DeepgramPrayerNarrationProvider;
use App\Domain\PrayerNarrations\PrayerNarrationProvider;
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
        $this->app->bind(PrayerNarrationProvider::class, DeepgramPrayerNarrationProvider::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        RateLimiter::for('prayer-narrations', function (Request $request): array {
            $userKey = (string) ($request->user()?->public_id ?? 'guest');

            return [
                Limit::perHour(20)->by('prayer-narration:user-hour:'.$userKey),
                Limit::perHour(60)->by('prayer-narration:ip-hour:'.$request->ip()),
            ];
        });
        RateLimiter::for('installation-sessions', fn (Request $request): array => [
            Limit::perMinute(10)->by('installation-session:'.$request->ip()),
        ]);
    }
}
