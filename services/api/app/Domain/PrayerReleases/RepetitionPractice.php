<?php

namespace App\Domain\PrayerReleases;

final readonly class RepetitionPractice
{
    /** @param list<RepetitionStep> $steps */
    public function __construct(
        public string $mode,
        public array $steps,
    ) {
    }

    /**
     * The exact source body these paced steps must rebuild in order.
     */
    public function sourceBody(): string
    {
        return implode("\n", array_map(
            static fn (RepetitionStep $step): string => $step->sourceLine,
            $this->steps,
        ));
    }
}
