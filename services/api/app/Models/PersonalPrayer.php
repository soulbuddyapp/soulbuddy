<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PersonalPrayer extends Model
{
    use HasUuids;

    protected $guarded = [];

    protected function casts(): array
    {
        return ['archived_at' => 'datetime'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function revisions(): HasMany
    {
        return $this->hasMany(PersonalPrayerRevision::class, 'prayer_id');
    }

    public function links(): HasMany
    {
        return $this->hasMany(PersonalPrayerLink::class, 'prayer_id');
    }

    public function reminders(): HasMany
    {
        return $this->hasMany(PrayerReminder::class, 'personal_prayer_id');
    }

    public function sessions(): HasMany
    {
        return $this->hasMany(PrayerSession::class, 'personal_prayer_id');
    }

    public function currentRevision(): BelongsTo
    {
        return $this->belongsTo(PersonalPrayerRevision::class, 'current_revision_id');
    }
}
