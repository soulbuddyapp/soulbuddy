<?php

namespace App\Domain\Circles;

final class CircleLifecycle
{
    public static function ownerCanTransition(string $from, string $to): bool
    {
        if ($from === $to) {
            return in_array($from, ['draft', 'active', 'paused'], true);
        }

        return match ($from) {
            'draft' => in_array($to, ['active', 'archived'], true),
            'active' => in_array($to, ['paused', 'archived'], true),
            'paused' => in_array($to, ['active', 'archived'], true),
            default => false,
        };
    }
}
