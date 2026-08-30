<?php

namespace App\Domain\GoalGuidance;

class GoalActionSuggestionService
{
    public function __construct(private GoalActionSuggestionProvider $provider) {}

    /** @return list<string> */
    public function suggest(array $context): array
    {
        $result = [];
        $seen = [];

        foreach ($this->provider->suggest($context) as $candidate) {
            if (! is_string($candidate)) {
                continue;
            }
            $text = preg_replace('/\s+/u', ' ', trim($candidate));
            if (! is_string($text) || $text === '' || mb_strlen($text) > 160 || ! $this->isPractical($text)) {
                continue;
            }
            $identity = mb_strtolower($text);
            if (isset($seen[$identity])) {
                continue;
            }
            $seen[$identity] = true;
            $result[] = $text;
            if (count($result) === 3) {
                break;
            }
        }

        if ($result === []) {
            throw new GoalActionSuggestionUnavailable;
        }

        return $result;
    }

    private function isPractical(string $text): bool
    {
        return preg_match(
            '/\b(god|the lord|jesus)\s+(told|tells|said|says|wants|revealed|promises|will)\b|\b(pray|prayer|scripture|bible verse|prophecy)\b/ui',
            $text,
        ) !== 1;
    }
}
