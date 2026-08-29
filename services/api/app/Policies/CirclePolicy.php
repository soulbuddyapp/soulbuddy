<?php

namespace App\Policies;

use App\Models\Circle;
use App\Models\User;

class CirclePolicy
{
    public function viewAny(User $user): bool
    {
        return true;
    }

    public function view(User $user, Circle $circle): bool
    {
        if ($circle->owner_user_id === $user->id) {
            return true;
        }

        return $circle->status === 'active' && $circle->visibility !== 'private';
    }

    public function create(User $user): bool
    {
        return true;
    }

    public function update(User $user, Circle $circle): bool
    {
        return $circle->owner_user_id === $user->id
            && ! in_array($circle->status, ['suspended', 'archived'], true);
    }

    public function report(User $user, Circle $circle): bool
    {
        return $circle->owner_user_id !== $user->id
            && $circle->status === 'active'
            && $circle->visibility !== 'private';
    }
}
