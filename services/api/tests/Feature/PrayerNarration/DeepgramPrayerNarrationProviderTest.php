<?php

use App\Domain\PrayerNarrations\DeepgramPrayerNarrationProvider;
use App\Domain\PrayerNarrations\PrayerNarrationUnavailable;
use Illuminate\Support\Facades\Http;

beforeEach(function () {
    config()->set('services.deepgram.key', 'provider-secret');
    config()->set('services.deepgram.base_url', 'https://api.deepgram.test');
    config()->set('services.deepgram.model', 'aura-2-thalia-en');
    config()->set('services.deepgram.encoding', 'mp3');
    config()->set('services.deepgram.bit_rate', 32000);
});

it('sends only the server loaded prayer text with the configured Aura voice', function () {
    Http::fake([
        'api.deepgram.test/*' => Http::response('mp3-audio', 200, ['Content-Type' => 'audio/mpeg']),
    ]);

    $audio = app(DeepgramPrayerNarrationProvider::class)->synthesize('Father, lead me. Amen.');

    expect($audio->bytes)->toBe('mp3-audio')->and($audio->contentType)->toBe('audio/mpeg');
    Http::assertSent(function ($request): bool {
        parse_str($request->toPsrRequest()->getUri()->getQuery(), $query);

        return $request->url() === 'https://api.deepgram.test/v1/speak?model=aura-2-thalia-en&encoding=mp3&bit_rate=32000&mip_opt_out=true'
            && $request->header('Authorization') === ['Token provider-secret']
            && $request['text'] === 'Father, lead me. Amen.'
            && $query['model'] === 'aura-2-thalia-en'
            && $query['mip_opt_out'] === 'true';
    });
});

it('maps provider errors to a content free exception', function () {
    Http::fake(['*' => Http::response('private provider detail', 500)]);

    expect(fn () => app(DeepgramPrayerNarrationProvider::class)->synthesize('Private prayer'))
        ->toThrow(PrayerNarrationUnavailable::class, 'Prayer narration unavailable.');
});
