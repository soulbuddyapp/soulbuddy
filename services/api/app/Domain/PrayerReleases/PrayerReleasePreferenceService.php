<?php

namespace App\Domain\PrayerReleases;

use App\Models\PrayerReleasePreference;
use App\Models\User;

/**
 * Weekly delivery preference. Opt-in is the only way a weekly notice happens,
 * and a release subscription never adds a prayer collection by itself.
 */
class PrayerReleasePreferenceService
{
    /** @return array{weekly_enabled: bool, notification_enabled: bool, time_zone: ?string} */
    public function defaults(): array
    {
        return [
            'weekly_enabled' => false,
            'notification_enabled' => true,
            'time_zone' => null,
        ];
    }

    /**
     * @param  array{weekly_enabled: bool, notification_enabled: bool, time_zone: ?string}  $attributes
     */
    public function store(User $user, array $attributes): PrayerReleasePreference
    {
        $weeklyEnabled = (bool) $attributes['weekly_enabled'];
        $preference = PrayerReleasePreference::query()->firstOrNew([
            'user_id' => $user->id,
        ]);

        // Turning weekly delivery off also stops its notice, and re-enabling weekly
        // delivery restores the default notice rather than a stale opt-out.
        $preference->forceFill([
            'weekly_enabled' => $weeklyEnabled,
            'notification_enabled' => $weeklyEnabled
                ? (bool) $attributes['notification_enabled']
                : false,
            'time_zone' => $attributes['time_zone'],
        ])->save();

        return $preference->fresh();
    }

    /**
     * @return array{weekly_enabled: bool, notification_enabled: bool, time_zone: ?string}
     */
    public function current(User $user): array
    {
        $preference = $user->prayerReleasePreference;

        if ($preference === null) {
            return $this->defaults();
        }

        return [
            'weekly_enabled' => (bool) $preference->weekly_enabled,
            'notification_enabled' => (bool) $preference->notification_enabled,
            'time_zone' => $preference->time_zone,
        ];
    }
}
