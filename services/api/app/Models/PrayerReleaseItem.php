<?php

namespace App\Models;

use App\Domain\PrayerReleases\ReleaseContent;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PrayerReleaseItem extends Model
{
    use HasUuids;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'sort_order' => 'integer',
            'practice_steps' => 'array',
        ];
    }

    public function release(): BelongsTo
    {
        return $this->belongsTo(PrayerRelease::class, 'release_id');
    }

    public function libraryPrayer(): BelongsTo
    {
        return $this->belongsTo(LibraryPrayer::class, 'library_prayer_id');
    }

    /**
     * Narration may only be attached when the spoken transcript is this exact
     * content.
     */
    public function narrationMatchesContent(): bool
    {
        return $this->narration_uri !== null
            && $this->narration_content_sha256 !== null
            && $this->narration_content_sha256 === $this->content_sha256;
    }

    public function hasRepetitionPractice(): bool
    {
        return $this->practice_mode === ReleaseContent::PRACTICE_MODE_AFFIRMATION_REPETITION
            && is_array($this->practice_steps)
            && $this->practice_steps !== [];
    }
}
