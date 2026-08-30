<?php

namespace App\Domain\GoalGuidance;

final class ReviewedGoalActionCatalogue
{
    /** @return list<string> */
    public function for(array $context): array
    {
        return match ($context['starter_key']) {
            'stop_control' => $this->stopControl($context['stop_behavior_key'] ?? null),
            'closer_to_god' => [
                'Set aside ten quiet minutes before opening another app',
                'Choose one Gospel passage to read slowly today',
                'Put one prayer where you will see it before the day becomes busy',
            ],
            'direction' => [
                'Write the two clearest options on one page',
                'Name one responsibility that is already in front of you',
                'Ask one trusted person for a short, honest conversation',
            ],
            'difficult_time' => [
                'Choose the one task that most needs gentle attention today',
                'Ask one trusted person for practical help',
                'Write down what can wait until tomorrow',
            ],
            default => [
                'Choose one small action you can finish today',
                'Write down what would make tomorrow easier',
                'Ask one trusted person for help naming the next step',
            ],
        };
    }

    /** @return list<string> */
    private function stopControl(?string $behavior): array
    {
        return match ($behavior) {
            'digital_distraction' => [
                'Turn off one distracting notification for the rest of today',
                'Move the most distracting app away from your home screen',
                'Choose one phone-free part of your day',
            ],
            'pornography' => [
                'Move your phone out of the place where you are most vulnerable',
                'Turn on a content restriction you cannot easily ignore',
                'Tell one trusted person where you need accountability',
            ],
            'gambling' => [
                'Remove one easy path to gambling today',
                'Use an available account limit or self-exclusion control',
                'Tell one trusted person what access still needs to close',
            ],
            'nicotine_tobacco' => [
                'Write down when the strongest urge usually appears',
                'Remove one easy source of tobacco or nicotine today',
                'Ask a qualified health professional about a safe quit plan',
            ],
            'alcohol' => [
                'Ask a qualified health professional what a safe next step is',
                'Tell one trusted person what support you need today',
                'Write down the time and place that most often leads to drinking',
            ],
            default => [
                'Remove one easy path back to this today',
                'Choose one replacement action you can do immediately',
                'Tell one trusted person what you are changing',
            ],
        };
    }
}
