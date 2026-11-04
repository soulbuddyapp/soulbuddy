<?php

namespace App\Providers;

use App\Domain\GoalGuidance\GoalActionSuggestionProvider;
use App\Domain\GoalGuidance\OpenAiCompatibleGoalActionSuggestionProvider;
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
        $this->app->bind(
            GoalActionSuggestionProvider::class,
            OpenAiCompatibleGoalActionSuggestionProvider::class,
        );
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
        RateLimiter::for('account-email-challenges', function (Request $request): array {
            $userKey = (string) ($request->user()?->public_id ?? 'guest');

            return [
                Limit::perHour(5)->by('account-email-challenge:user-hour:'.$userKey),
                Limit::perHour(10)->by('account-email-challenge:ip-hour:'.$request->ip()),
            ];
        });
        RateLimiter::for('goal-action-suggestions', function (Request $request): array {
            $userKey = (string) ($request->user()?->public_id ?? 'guest');

            return [
                Limit::perHour(30)->by('goal-action-suggestion:user-hour:'.$userKey),
                Limit::perHour(90)->by('goal-action-suggestion:ip-hour:'.$request->ip()),
            ];
        });
        // Adding is deliberately explicit and rare; an add is idempotent anyway.
        RateLimiter::for('prayer-release-adds', function (Request $request): array {
            $userKey = (string) ($request->user()?->public_id ?? 'guest');

            return [
                Limit::perHour(20)->by('prayer-release-add:user-hour:'.$userKey),
                Limit::perHour(60)->by('prayer-release-add:ip-hour:'.$request->ip()),
            ];
        });
        RateLimiter::for('prayer-release-preferences', function (Request $request): array {
            $userKey = (string) ($request->user()?->public_id ?? 'guest');

            return [
                Limit::perHour(30)->by('prayer-release-preference:user-hour:'.$userKey),
                Limit::perHour(90)->by('prayer-release-preference:ip-hour:'.$request->ip()),
            ];
        });
    }
}
