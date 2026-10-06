<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PrayerReleasePreference extends Model
{
    protected $primaryKey = 'user_id';

    public $incrementing = false;

    protected $keyType = 'int';

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'weekly_enabled' => 'boolean',
            'notification_enabled' => 'boolean',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * A weekly opt-out stops every future notice without touching content a
     * person already added.
     */
    public function receivesDelivery(): bool
    {
        return $this->weekly_enabled && $this->notification_enabled && $this->time_zone !== null;
    }
}
