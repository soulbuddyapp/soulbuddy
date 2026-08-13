<?php

namespace App\Domain\PrayerNarrations;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;

final readonly class DeepgramPrayerNarrationProvider implements PrayerNarrationProvider
{
    public function synthesize(string $text): PrayerNarrationAudio
    {
        try {
            $response = Http::baseUrl((string) config('services.deepgram.base_url'))
                ->withHeaders(['Authorization' => 'Token '.config('services.deepgram.key')])
                ->accept('audio/mpeg')
                ->asJson()
                ->timeout(30)
                ->post('/v1/speak?'.http_build_query([
                    'model' => config('services.deepgram.model'),
                    'encoding' => config('services.deepgram.encoding'),
                    'bit_rate' => config('services.deepgram.bit_rate'),
                    'mip_opt_out' => 'true',
                ]), ['text' => $text]);
        } catch (ConnectionException) {
            throw new PrayerNarrationUnavailable;
        }

        if (! $response->successful()) {
            throw new PrayerNarrationUnavailable;
        }

        return new PrayerNarrationAudio(
            $response->body(),
            strtolower(trim(explode(';', $response->header('Content-Type'))[0])),
        );
    }
}
