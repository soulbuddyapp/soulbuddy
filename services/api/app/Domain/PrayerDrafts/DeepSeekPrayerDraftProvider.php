<?php

namespace App\Domain\PrayerDrafts;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use JsonException;

final readonly class DeepSeekPrayerDraftProvider implements PrayerDraftProvider
{
    public function __construct(private PrayerDraftPrompt $prompt) {}

    public function generate(PrayerDraftInput $input, ?array $repairCodes): PrayerDraftResult
    {
        try {
            $response = Http::baseUrl((string) config('services.deepseek.base_url'))
                ->withToken((string) config('services.deepseek.key'))
                ->acceptJson()
                ->asJson()
                ->timeout(20)
                ->post('/chat/completions', [
                    'model' => config('services.deepseek.model'),
                    'thinking' => ['type' => 'disabled'],
                    'messages' => $this->prompt->messages($input, $repairCodes),
                    'response_format' => ['type' => 'json_object'],
                    'max_tokens' => 350,
                    'temperature' => 0.3,
                    'user_id' => hash('sha256', 'soulbuddy:'.$input->userPublicId),
                ]);
        } catch (ConnectionException) {
            throw new PrayerDraftUnavailable;
        }

        if ($response->status() === 429) {
            $header = $response->header('Retry-After');
            $retryAfter = is_numeric($header) ? max(0, (int) $header) : null;
            throw new PrayerDraftRateLimited($retryAfter);
        }
        if (! $response->successful()) {
            throw new PrayerDraftUnavailable;
        }

        $choice = $response->json('choices.0');
        if (! is_array($choice)
            || ($choice['finish_reason'] ?? null) !== 'stop'
            || ! is_string(data_get($choice, 'message.content'))) {
            throw new PrayerDraftInvalidResponse;
        }

        try {
            $decoded = json_decode(
                data_get($choice, 'message.content'),
                true,
                16,
                JSON_THROW_ON_ERROR,
            );
        } catch (JsonException) {
            throw new PrayerDraftInvalidResponse;
        }
        if (! is_array($decoded)) {
            throw new PrayerDraftInvalidResponse;
        }

        return PrayerDraftResult::fromArray($decoded);
    }
}
