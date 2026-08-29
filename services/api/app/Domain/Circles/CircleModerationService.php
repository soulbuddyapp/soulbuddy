<?php

namespace App\Domain\Circles;

use App\Models\Circle;
use App\Models\CircleModerationEvent;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class CircleModerationService
{
    public function suspend(Circle $circle, ?User $actor, string $reasonCode): void
    {
        DB::transaction(function () use ($circle, $actor, $reasonCode): void {
            $circle->forceFill(['status' => 'suspended'])->save();
            $this->event($circle, $actor, 'suspended', $reasonCode);
        });
    }

    public function delist(Circle $circle, ?User $actor, string $reasonCode): void
    {
        DB::transaction(function () use ($circle, $actor, $reasonCode): void {
            $circle->forceFill(['visibility' => 'unlisted'])->save();
            $this->event($circle, $actor, 'delisted', $reasonCode);
        });
    }

    private function event(
        Circle $circle,
        ?User $actor,
        string $eventType,
        string $reasonCode,
    ): void {
        CircleModerationEvent::create([
            'circle_id' => $circle->id,
            'actor_user_id' => $actor?->id,
            'event_type' => $eventType,
            'reason_code' => $reasonCode,
            'created_at' => now(),
        ]);
    }
}
