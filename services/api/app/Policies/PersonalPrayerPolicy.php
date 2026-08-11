<?php

namespace App\Policies;

use App\Models\PersonalPrayer;
use App\Models\User;

class PersonalPrayerPolicy
{
    public function view(User $user, PersonalPrayer $prayer): bool
    {
        return $prayer->user_id === $user->id;
    }

    public function update(User $user, PersonalPrayer $prayer): bool
    {
        return $prayer->user_id === $user->id;
    }
}
