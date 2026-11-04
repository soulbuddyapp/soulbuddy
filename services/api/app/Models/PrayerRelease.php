<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PrayerRelease extends Model
{
    use HasUuids;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'published_at' => 'datetime',
            'archived_at' => 'datetime',
        ];
    }

    public function items(): HasMany
    {
        return $this->hasMany(PrayerReleaseItem::class, 'release_id')->orderBy('sort_order');
    }

    public function downloads(): HasMany
    {
        return $this->hasMany(PrayerReleaseDownload::class, 'release_id');
    }

    public function isVisible(?\DateTimeInterface $now = null): bool
    {
        $now ??= now();

        return $this->published_at !== null
            && $this->published_at->lessThanOrEqualTo($now)
            && $this->archived_at === null;
    }
}
