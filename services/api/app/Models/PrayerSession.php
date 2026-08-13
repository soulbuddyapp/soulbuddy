<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PrayerSession extends Model
{
    use HasUuids;

    public $timestamps = false;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'occurred_at' => 'datetime',
            'local_date' => 'date:Y-m-d',
            'retracted_at' => 'datetime',
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

    public function libraryPrayer(): BelongsTo
    {
        return $this->belongsTo(LibraryPrayer::class, 'library_prayer_id');
    }

    public function revision(): BelongsTo
    {
        return $this->belongsTo(PersonalPrayerRevision::class, 'prayer_revision_id');
    }

    public function reminder(): BelongsTo
    {
        return $this->belongsTo(PrayerReminder::class, 'reminder_id');
    }
}
