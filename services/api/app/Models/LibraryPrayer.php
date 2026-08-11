<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class LibraryPrayer extends Model
{
    use HasUuids;

    public $timestamps = false;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'helpful_count' => 'integer',
            'published_at' => 'datetime',
            'archived_at' => 'datetime',
        ];
    }

    public function votes(): HasMany
    {
        return $this->hasMany(PrayerVote::class, 'prayer_id');
    }

    public function todaySelections(): HasMany
    {
        return $this->hasMany(TodayPrayer::class, 'prayer_id');
    }
}
