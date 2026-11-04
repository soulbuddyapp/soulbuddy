<?php

namespace App\Models;

use App\Domain\PrayerReleases\AffirmationPrayerSessionShape;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AffirmationPrayerSession extends Model
{
    use HasUuids;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'local_date' => 'date:Y-m-d',
            'started_at' => 'datetime',
            'ended_at' => 'datetime',
            'step_one_count' => 'integer',
            'step_two_count' => 'integer',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function releaseItem(): BelongsTo
    {
        return $this->belongsTo(PrayerReleaseItem::class, 'release_item_id');
    }

    /** The stored pace is kept as written so a replay compares exactly. */
    public function getNarrationSpeedAttribute(): ?string
    {
        $value = $this->attributes['narration_speed'] ?? null;

        return $value === null ? null : (string) $value;
    }

    /**
     * A terminal record is immutable and must satisfy its own bounds.
     */
    public static function shape(): AffirmationPrayerSessionShape
    {
        return new AffirmationPrayerSessionShape;
    }

    /**
     * Whether an incoming payload is the same terminal record already stored.
     *
     * @param  array<string, mixed>  $data
     */
    public function matchesPayload(array $data): bool
    {
        return $this->release_item_id === ($data['release_item_id'] ?? null)
            && $this->local_date?->format('Y-m-d') === ($data['local_date'] ?? null)
            && $this->outcome === ($data['outcome'] ?? null)
            && $this->step_one_count === ($data['step_one_count'] ?? null)
            && $this->step_two_count === ($data['step_two_count'] ?? null)
            && $this->sound_key === ($data['sound_key'] ?? null)
            && (string) $this->narration_speed === (string) ($data['narration_speed'] ?? '');
    }
}
