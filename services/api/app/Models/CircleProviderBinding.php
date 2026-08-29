<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CircleProviderBinding extends Model
{
    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'capabilities' => 'array',
            'bound_at' => 'datetime',
            'last_verified_at' => 'datetime',
        ];
    }

    public function circle(): BelongsTo
    {
        return $this->belongsTo(Circle::class);
    }
}
