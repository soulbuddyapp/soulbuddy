<?php

namespace App\Domain\GoalGuidance;

interface GoalActionSuggestionProvider
{
    /** @return list<string> */
    public function suggest(array $context): array;
}
