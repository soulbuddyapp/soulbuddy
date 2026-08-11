<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PrayerReminder extends Model
{
    use HasUuids;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'once_at' => 'datetime',
            'enabled' => 'boolean',
            'archived_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function prayer(): BelongsTo
    {
        return $this->belongsTo(PersonalPrayer::class, 'personal_prayer_id');
    }

    public function sessions(): HasMany
    {
        return $this->hasMany(PrayerSession::class, 'reminder_id');
    }
}
