<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TodayPrayer extends Model
{
    use HasUuids;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'local_date' => 'date',
            'include_action' => 'boolean',
            'action_completed' => 'boolean',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function prayer(): BelongsTo
    {
        return $this->belongsTo(LibraryPrayer::class, 'prayer_id');
    }

    public function personalPrayer(): BelongsTo
    {
        return $this->belongsTo(PersonalPrayer::class, 'personal_prayer_id');
    }
}
