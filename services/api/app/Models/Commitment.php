<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Commitment extends Model
{
    use HasUuids;

    protected $guarded = [];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function goal(): BelongsTo
    {
        return $this->belongsTo(Goal::class);
    }

    public function practices(): HasMany
    {
        return $this->hasMany(CommitmentPractice::class);
    }

    public function declaration(): HasOne
    {
        return $this->hasOne(CommitmentDeclaration::class);
    }

    public function meditationPlan(): HasOne
    {
        return $this->hasOne(CommitmentMeditationPlan::class);
    }

    public function preparationCycle(): HasOne
    {
        return $this->hasOne(CommitmentPreparationCycle::class);
    }

    public function meditationSessions(): HasMany
    {
        return $this->hasMany(CommitmentMeditationSession::class);
    }
}
