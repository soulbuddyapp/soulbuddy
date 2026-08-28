<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Goal extends Model
{
    use HasUuids;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'position' => 'integer',
            'archived_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function currentRevision(): BelongsTo
    {
        return $this->belongsTo(GoalRevision::class, 'current_revision_id');
    }

    public function revisions(): HasMany
    {
        return $this->hasMany(GoalRevision::class);
    }

    public function links(): HasMany
    {
        return $this->hasMany(GoalLink::class);
    }

    public function actions(): HasMany
    {
        return $this->hasMany(GoalAction::class);
    }

    public function actionEvents(): HasMany
    {
        return $this->hasMany(GoalActionEvent::class);
    }
}
