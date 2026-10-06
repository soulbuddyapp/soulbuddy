<?php

use App\Domain\PrayerReleases\PrayerReleasePublisher;
use App\Domain\PrayerReleases\ReleaseContent;
use App\Models\AppInstallation;
use App\Models\PrayerRelease;
use App\Models\PrayerReleaseDelivery;
use App\Models\User;
use Database\Seeders\PrayerReleaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

beforeEach(function () {
    config()->set('services.firebase.project_id', 'test-project');
    Cache::put('firebase_messaging_access_token', 'test-access-token');
});

function noticeRelease(string $publishedAt = '2026-10-05 00:00:00'): PrayerRelease
{
    config()->set('prayer_releases.published_at', $publishedAt);
    app(PrayerReleasePublisher::class)->publish(
        ReleaseContent::fromJsonFile(resource_path('prayer-releases/'.PrayerReleaseSeeder::SLUG.'.json')),
        $publishedAt,
    );

    return PrayerRelease::query()->where('slug', PrayerReleaseSeeder::SLUG)->firstOrFail();
}

function noticeInstallation(User $user, string $timeZone, string $tokenPrefix = 'token'): string
{
    $deviceId = (string) Str::uuid();
    DB::table('app_installations')->insert([
        'id' => $deviceId,
        'user_id' => $user->id,
        'secret_hash' => hash('sha256', Str::random(64)),
        'push_token' => "{$tokenPrefix}-{$deviceId}",
        'time_zone' => $timeZone,
        'created_at' => now(),
        'updated_at' => now(),
    ]);

    return $deviceId;
}

function optedIn(User $user, ?string $timeZone = 'UTC', bool $weekly = true, bool $notify = true): void
{
    DB::table('prayer_release_preferences')->insert([
        'user_id' => $user->id,
        'weekly_enabled' => $weekly,
        'notification_enabled' => $notify,
        'time_zone' => $timeZone,
        'created_at' => now(),
        'updated_at' => now(),
    ]);
}

/**
 * Records every FCM notice so a test can prove what was and was not sent, and
 * accepts or rejects each one. The collector is an object because a returned
 * array would be copied before any request arrived.
 */
function recordPushes(?Closure $accept = null): ArrayObject
{
    $sent = new ArrayObject;
    // One fake for the whole test: a later `Http::fake` would not replace the
    // earlier stub, so a retry could never be given a different answer.
    Http::fake(function (Request $request) use ($sent, $accept) {
        if (! str_contains($request->url(), 'fcm.googleapis.com')) {
            return Http::response([], 200);
        }
        $sent->append($request);

        return $accept === null
            ? Http::response(['name' => 'sent-message'])
            : $accept($request);
    });

    return $sent;
}

/**
 * @param  ArrayObject<int, Request>  $calls
 * @return array<int, Request>
 */
function callsTo(ArrayObject $calls, string $needle): array
{
    return array_values(array_filter(
        $calls->getArrayCopy(),
        static fn (Request $request): bool => str_contains($request->url(), $needle),
    ));
}

function telegramCompanion(User $user, bool $enabled = true): string
{
    $chatId = (string) random_int(100000, 999999);
    config()->set('services.telegram.bot_token', 'bot-token');
    DB::table('telegram_connections')->insert([
        'id' => (string) Str::uuid(),
        'user_id' => $user->id,
        'chat_id' => $chatId,
        'username' => 'beloved',
        'daily_enabled' => $enabled,
        'created_at' => now(),
        'updated_at' => now(),
    ]);

    return $chatId;
}

it('delivers at Monday 07:00 in each opted-in person own time zone', function () {
    $sent = recordPushes();
    noticeRelease();

    // Lagos is UTC+1 and New York is UTC-4 on this date, so their Monday 07:00
    // falls six hours apart.
    $lagos = User::factory()->create();
    $newYork = User::factory()->create();
    $lagosDevice = noticeInstallation($lagos, 'Africa/Lagos');
    $newYorkDevice = noticeInstallation($newYork, 'America/New_York');
    optedIn($lagos, 'Africa/Lagos');
    optedIn($newYork, 'America/New_York');

    // 06:59 local Lagos (UTC+1) is 05:59 UTC: nobody is due yet.
    $this->travelTo(now()->setDate(2026, 10, 5)->setTime(5, 59)->utc());
    expect(Artisan::call('prayer-releases:notify'))->toBe(0);
    expect(PrayerReleaseDelivery::query()->count())->toBe(0);

    // 07:00 local Lagos is 06:00 UTC, still six hours before New York's 07:00.
    $this->travelTo(now()->setDate(2026, 10, 5)->setTime(6, 0)->utc());
    expect(Artisan::call('prayer-releases:notify'))->toBe(0);
    expect(PrayerReleaseDelivery::query()->pluck('user_id')->all())->toBe([$lagos->id])
        ->and(PrayerReleaseDelivery::query()
            ->where('user_id', $lagos->id)
            ->value('app_installation_id'))->toBe($lagosDevice);

    $this->travelTo(now()->setDate(2026, 10, 5)->setTime(11, 0)->utc());
    expect(Artisan::call('prayer-releases:notify'))->toBe(0);
    expect(PrayerReleaseDelivery::query()->pluck('user_id')->sort()->values()->all())
        ->toBe([$lagos->id, $newYork->id]);

    expect($sent->count())->toBe(2)
        ->and(AppInstallation::query()->whereKey($newYorkDevice)->value('push_token'))->not->toBeNull();
});

it('never reaches a person who has not opted in', function () {
    $sent = recordPushes();
    noticeRelease();

    $optedOut = User::factory()->create();
    noticeInstallation($optedOut, 'UTC');
    optedIn($optedOut, 'UTC', weekly: false);

    $noticesOff = User::factory()->create();
    noticeInstallation($noticesOff, 'UTC');
    optedIn($noticesOff, 'UTC', notify: false);

    $noPreference = User::factory()->create();
    noticeInstallation($noPreference, 'UTC');

    $noTimeZone = User::factory()->create();
    noticeInstallation($noTimeZone, 'UTC');
    optedIn($noTimeZone, null);

    $unknownZone = User::factory()->create();
    noticeInstallation($unknownZone, 'Mars/Olympus');
    optedIn($unknownZone, 'Mars/Olympus');

    $noInstallation = User::factory()->create();
    optedIn($noInstallation, 'UTC');

    $this->travelTo(now()->setDate(2026, 10, 5)->setTime(8, 0)->utc());
    expect(Artisan::call('prayer-releases:notify'))->toBe(0);

    expect(PrayerReleaseDelivery::query()->count())->toBe(0)
        ->and($sent->count())->toBe(0);
});

it('delivers once per person and channel across repeated scheduler runs', function () {
    $sent = recordPushes();
    noticeRelease();

    $user = User::factory()->create();
    $firstDevice = noticeInstallation($user, 'UTC', 'first');
    $secondDevice = noticeInstallation($user, 'UTC', 'second');
    optedIn($user, 'UTC');

    $this->travelTo(now()->setDate(2026, 10, 5)->setTime(8, 0)->utc());

    expect(Artisan::call('prayer-releases:notify'))->toBe(0);
    expect(PrayerReleaseDelivery::query()->where('channel', 'fcm')->count())->toBe(1)
        ->and(PrayerReleaseDelivery::query()
            ->where('user_id', $user->id)
            ->value('app_installation_id'))
        ->toBeIn([$firstDevice, $secondDevice]);

    expect(Artisan::call('prayer-releases:notify'))->toBe(0);
    $this->travelTo(now()->addDay());
    expect(Artisan::call('prayer-releases:notify'))->toBe(0);

    // Both devices keep working tokens: one notice per person, not per device.
    expect(PrayerReleaseDelivery::query()->where('channel', 'fcm')->count())->toBe(1)
        ->and($sent->count())->toBe(1)
        ->and(AppInstallation::query()->whereKey($firstDevice)->value('push_token'))->not->toBeNull()
        ->and(AppInstallation::query()->whereKey($secondDevice)->value('push_token'))->not->toBeNull();
});

it('retries after a rejected push and records only after acceptance', function () {
    noticeRelease();

    $user = User::factory()->create();
    $device = noticeInstallation($user, 'UTC');
    optedIn($user, 'UTC');

    $this->travelTo(now()->setDate(2026, 10, 5)->setTime(8, 0)->utc());

    // Unavailable first, accepted afterwards, in a single fake.
    $accept = null;
    $sent = recordPushes(static function (Request $request) use (&$accept) {
        return $accept === null
            ? Http::response(['error' => ['status' => 'UNAVAILABLE']], 503)
            : Http::response(['name' => 'sent-message']);
    });

    expect(Artisan::call('prayer-releases:notify'))->toBe(1);
    expect(PrayerReleaseDelivery::query()->count())->toBe(0)
        ->and(AppInstallation::query()->whereKey($device)->value('push_token'))->not->toBeNull();

    $accept = static fn () => null;
    expect(Artisan::call('prayer-releases:notify'))->toBe(0);
    expect(PrayerReleaseDelivery::query()->count())->toBe(1);

    expect(Artisan::call('prayer-releases:notify'))->toBe(0);
    expect(PrayerReleaseDelivery::query()->count())->toBe(1)
        // Two attempts were made: the rejection was retried, and the accepted
        // notice was never repeated.
        ->and($sent->count())->toBe(2);
});

it('clears a rejected token without recording a delivery', function () {
    noticeRelease();

    $user = User::factory()->create();
    $device = noticeInstallation($user, 'UTC');
    optedIn($user, 'UTC');

    $this->travelTo(now()->setDate(2026, 10, 5)->setTime(8, 0)->utc());

    recordPushes(static fn (): mixed => Http::response([
        'error' => [
            'status' => 'NOT_FOUND',
            'details' => [[
                '@type' => 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
                'errorCode' => 'UNREGISTERED',
            ]],
        ],
    ], 404));

    expect(Artisan::call('prayer-releases:notify'))->toBe(1);
    expect(AppInstallation::query()->whereKey($device)->value('push_token'))->toBeNull()
        ->and(PrayerReleaseDelivery::query()->count())->toBe(0);

    // Nothing is left to retry, so a second run does no work.
    $sent = recordPushes();
    expect(Artisan::call('prayer-releases:notify'))->toBe(0);
    expect(PrayerReleaseDelivery::query()->count())->toBe(0)
        ->and($sent->count())->toBe(0);
});

it('sends one safe weekly notice that never names the subject matter', function () {
    $sent = recordPushes();
    $release = noticeRelease();

    $user = User::factory()->create();
    noticeInstallation($user, 'UTC');
    optedIn($user, 'UTC');

    $this->travelTo(now()->setDate(2026, 10, 5)->setTime(8, 0)->utc());
    expect(Artisan::call('prayer-releases:notify'))->toBe(0);

    expect($sent->count())->toBe(1);

    $message = $sent[0]['message'];
    expect($message['notification']['title'])->toBe('A new prayer collection is ready')
        ->and($message['notification']['body'])->toBe('Renewed mind & guarded heart')
        ->and($message['android']['priority'])->toBe('high')
        ->and($message['android']['notification']['channel_id'])->toBe('soulbuddy_weekly_prayers_v1')
        ->and($message['android']['notification']['tag'])->toBe('soulbuddy-weekly-prayers-'.$release->slug)
        ->and($message['data'])->toBe([
            'route' => '/prayers/releases/'.$release->slug,
            'kind' => 'weekly_prayer',
        ]);

    // The detail stays behind the deliberate open.
    $copy = strtolower(json_encode($message));
    foreach (['purity', 'temptation', 'temptations', 'sin', 'memorare', 'new adam', 'repetition', 'occasions'] as $subject) {
        expect($copy)->not->toContain($subject);
    }
});

it('does not backfill a release whose week has already passed', function () {
    $sent = recordPushes();
    noticeRelease();

    $user = User::factory()->create();
    noticeInstallation($user, 'UTC');
    optedIn($user, 'UTC');

    // Two weeks after publication, and again on the next Monday.
    $this->travelTo(now()->setDate(2026, 10, 19)->setTime(8, 0)->utc());
    expect(Artisan::call('prayer-releases:notify'))->toBe(0);
    expect(PrayerReleaseDelivery::query()->count())->toBe(1)
        ->and($sent->count())->toBe(1);

    $this->travelTo(now()->setDate(2026, 10, 26)->setTime(8, 0)->utc());
    expect(Artisan::call('prayer-releases:notify'))->toBe(0);
    expect(PrayerReleaseDelivery::query()->count())->toBe(1)
        ->and($sent->count())->toBe(1);
});

it('waits for the release own publication before any notice', function () {
    $sent = recordPushes();
    // Published late on a Monday: the first delivery is that moment, not before.
    noticeRelease('2026-10-05 23:30:00');

    $lagos = User::factory()->create();
    noticeInstallation($lagos, 'Africa/Lagos');
    optedIn($lagos, 'Africa/Lagos');

    $this->travelTo(now()->setDate(2026, 10, 5)->setTime(22, 0)->utc());
    expect(Artisan::call('prayer-releases:notify'))->toBe(0);
    expect($sent->count())->toBe(0);

    $this->travelTo(now()->setDate(2026, 10, 5)->setTime(23, 45)->utc());
    expect(Artisan::call('prayer-releases:notify'))->toBe(0);
    expect($sent->count())->toBe(1);
});

it('withholds notices from an archived release', function () {
    $sent = recordPushes();
    $release = noticeRelease();

    $user = User::factory()->create();
    noticeInstallation($user, 'UTC');
    optedIn($user, 'UTC');

    $release->forceFill(['archived_at' => now()])->save();

    $this->travelTo(now()->setDate(2026, 10, 5)->setTime(8, 0)->utc());
    expect(Artisan::call('prayer-releases:notify'))->toBe(0);
    expect(PrayerReleaseDelivery::query()->count())->toBe(0)
        ->and($sent->count())->toBe(0);
});

it('keeps a linked telegram companion on the same notice and ledger', function () {
    // One fake for both channels: the companion is not a separate path.
    $calls = new ArrayObject;
    Http::fake(function (Request $request) use ($calls) {
        $calls->append($request);

        return Http::response(['ok' => true, 'name' => 'sent-message']);
    });
    noticeRelease();

    $linked = User::factory()->create();
    noticeInstallation($linked, 'UTC');
    optedIn($linked, 'UTC');
    $chatId = telegramCompanion($linked);

    $this->travelTo(now()->setDate(2026, 10, 5)->setTime(8, 0)->utc());
    expect(Artisan::call('prayer-releases:notify'))->toBe(0);

    expect(PrayerReleaseDelivery::query()->where('channel', 'telegram')->count())->toBe(1)
        ->and(PrayerReleaseDelivery::query()->where('channel', 'fcm')->count())->toBe(1);

    $telegram = callsTo($calls, 'api.telegram.org');
    expect($telegram)->toHaveCount(1);

    $payload = $telegram[0]->data();
    expect($payload['chat_id'])->toBe($chatId)
        ->and($payload['text'])->toContain('A new prayer collection is ready')
        ->and($payload['text'])->toContain('Renewed mind & guarded heart')
        ->and($payload['text'])->toContain('Open SoulBuddy and choose Prayers to add it.');
    // No URL is offered: this app publishes no web route for a release and
    // registers no App Links domain, so a link would resolve to nothing.
    expect($payload)->not->toHaveKey('reply_markup');

    expect(Artisan::call('prayer-releases:notify'))->toBe(0);
    expect(PrayerReleaseDelivery::query()->where('channel', 'telegram')->count())->toBe(1)
        ->and(callsTo($calls, 'api.telegram.org'))->toHaveCount(1);
});

it('does not treat an opted-out telegram companion as an eligible account', function () {
    Http::fake(['api.telegram.org/*' => Http::response(['ok' => true])]);
    recordPushes();
    noticeRelease();

    $user = User::factory()->create();
    noticeInstallation($user, 'UTC');
    optedIn($user, 'UTC');
    telegramCompanion($user, enabled: false);

    $this->travelTo(now()->setDate(2026, 10, 5)->setTime(8, 0)->utc());
    expect(Artisan::call('prayer-releases:notify'))->toBe(0);

    expect(PrayerReleaseDelivery::query()->where('channel', 'telegram')->count())->toBe(0);
});

it('never writes a notice body or a device token into the logs', function () {
    Log::spy();
    noticeRelease();

    $user = User::factory()->create();
    $device = noticeInstallation($user, 'UTC');
    optedIn($user, 'UTC');

    $this->travelTo(now()->setDate(2026, 10, 5)->setTime(8, 0)->utc());
    $token = (string) AppInstallation::query()->whereKey($device)->value('push_token');
    recordPushes(static fn (): mixed => Http::response(
        ['error' => ['status' => 'UNAVAILABLE', 'message' => 'private token must not be logged']],
        503,
    ));
    Artisan::call('prayer-releases:notify');

    // The rejected push is diagnosed without the token or the provider's message.
    Log::shouldHaveReceived('warning')->withArgs(function (string $message, array $context) use ($token): bool {
        $encoded = json_encode($context);

        return $message === 'Firebase notification rejected.'
            && ($context['http_status'] ?? null) === 503
            && ($context['error_code'] ?? null) === 'UNAVAILABLE'
            && ! str_contains($encoded, $token)
            && ! str_contains($encoded, 'private token');
    })->atLeast()->once();

    Log::shouldHaveReceived('info')->withArgs(function (string $message, array $context) use ($token): bool {
        return ! str_contains(json_encode($context), $token)
            && ! str_contains(json_encode($context), 'Renewed mind');
    })->atLeast()->once();
});
