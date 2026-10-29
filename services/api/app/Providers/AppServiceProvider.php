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
        RateLimiter::for('chatgpt-mcp', function (Request $request): array {
            $bearer = $request->bearerToken();

            if (! is_string($bearer) || $bearer === '') {
                return [Limit::perMinute(50)->by('chatgpt-mcp:anonymous:'.$request->ip())];
            }

            return [
                Limit::perMinute(90)->by('chatgpt-mcp:token:'.hash('sha256', $bearer)),
                Limit::perMinute(1200)->by('chatgpt-mcp:ip:'.$request->ip()),
            ];
        });
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
    }
}
