<?php

namespace App\Domain\GoalGuidance;

use Illuminate\Support\Facades\Http;

class OpenAiCompatibleGoalActionSuggestionProvider implements GoalActionSuggestionProvider
{
    public function suggest(array $context): array
    {
        $key = (string) config('services.goal_guidance.key');
        if ($key === '') {
            throw new GoalActionSuggestionUnavailable;
        }

        try {
            $response = Http::baseUrl((string) config('services.goal_guidance.base_url'))
                ->withToken($key)
                ->acceptJson()
                ->asJson()
                ->timeout(10)
                ->post('/chat/completions', [
                    'model' => config('services.goal_guidance.model'),
                    'temperature' => 0.2,
                    'max_tokens' => 240,
                    'response_format' => ['type' => 'json_object'],
                    'messages' => [
                        [
                            'role' => 'system',
                            'content' => 'Return JSON {"suggestions":["...","...","..."]}. Rank the allowed_suggestions for the person. Return only exact strings from allowed_suggestions, without edits or additions. Never create new advice.',
                        ],
                        [
                            'role' => 'user',
                            'content' => json_encode($context, JSON_THROW_ON_ERROR),
                        ],
                    ],
                ]);

            if (! $response->successful()) {
                throw new GoalActionSuggestionUnavailable;
            }
            $content = $response->json('choices.0.message.content');
            if (! is_string($content)) {
                throw new GoalActionSuggestionUnavailable;
            }
            $decoded = json_decode($content, true, flags: JSON_THROW_ON_ERROR);
            $suggestions = $decoded['suggestions'] ?? null;
            if (! is_array($suggestions)) {
                throw new GoalActionSuggestionUnavailable;
            }

            return array_values($suggestions);
        } catch (GoalActionSuggestionUnavailable $exception) {
            throw $exception;
        } catch (\Throwable) {
            throw new GoalActionSuggestionUnavailable;
        }
    }
}
