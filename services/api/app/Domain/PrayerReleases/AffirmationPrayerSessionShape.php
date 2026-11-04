<?php

namespace App\Domain\PrayerReleases;

/**
 * The only shape a counted prayer session may take.
 *
 * A completed session requires exactly 50 and 10. An early exit records the
 * counts actually reached and never exceeds either target, so a forged completed
 * record with incomplete counts can never be written.
 */
final class AffirmationPrayerSessionShape
{
    public const STEP_ONE_TARGET = 50;

    public const STEP_TWO_TARGET = 10;

    public const OUTCOME_COMPLETED = 'completed';

    public const OUTCOME_ENDED_EARLY = 'ended_early';

    public const SPEED_PATTERN = '/^(0\.7|0\.85|1|1\.15)$/';

    /** @return array<int, string> */
    public static function speeds(): array
    {
        return ['0.7', '0.85', '1', '1.15'];
    }

    /**
     * @return array{outcome: string, step_one_count: int, step_two_count: int}|null
     */
    public function normalize(
        string $outcome,
        int $stepOneCount,
        int $stepTwoCount,
    ): ?array {
        if (! in_array($outcome, [self::OUTCOME_COMPLETED, self::OUTCOME_ENDED_EARLY], true)) {
            return null;
        }
        if ($stepOneCount < 0 || $stepOneCount > self::STEP_ONE_TARGET) {
            return null;
        }
        if ($stepTwoCount < 0 || $stepTwoCount > self::STEP_TWO_TARGET) {
            return null;
        }
        if ($outcome === self::OUTCOME_COMPLETED
            && ($stepOneCount !== self::STEP_ONE_TARGET || $stepTwoCount !== self::STEP_TWO_TARGET)) {
            return null;
        }
        if ($outcome === self::OUTCOME_ENDED_EARLY
            && $stepOneCount === self::STEP_ONE_TARGET
            && $stepTwoCount === self::STEP_TWO_TARGET) {
            return null;
        }

        return [
            'outcome' => $outcome,
            'step_one_count' => $stepOneCount,
            'step_two_count' => $stepTwoCount,
        ];
    }

    public function isSpeed(string $speed): bool
    {
        return preg_match(self::SPEED_PATTERN, $speed) === 1;
    }
}
