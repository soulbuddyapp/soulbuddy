<?php

namespace App\Domain\GoalGuidance;

class GoalActionSuggestionService
{
    public function __construct(
        private GoalActionSuggestionProvider $provider,
        private ReviewedGoalActionCatalogue $catalogue,
    ) {}

    /** @return list<string> */
    public function suggest(array $context): array
    {
        $reviewed = $this->catalogue->for($context);
        $result = [];
        $seen = [];

        foreach ($this->provider->suggest([
            ...$context,
            'allowed_suggestions' => $reviewed,
        ]) as $candidate) {
            if (! is_string($candidate)) {
                continue;
            }
            $text = preg_replace('/\s+/u', ' ', trim($candidate));
            if (! is_string($text)
                || $text === ''
                || mb_strlen($text) > 160
                || ! in_array($text, $reviewed, true)) {
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
}
