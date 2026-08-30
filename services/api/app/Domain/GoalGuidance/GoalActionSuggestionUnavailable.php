<?php

namespace App\Domain\GoalGuidance;

use RuntimeException;

class GoalActionSuggestionUnavailable extends RuntimeException
{
    public function __construct()
    {
        parent::__construct('Goal action suggestions are unavailable.');
    }
}
