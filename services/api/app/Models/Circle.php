<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Support\Str;

class Circle extends Model
{
    protected $guarded = [];

    protected static function booted(): void
    {
        static::creating(function (Circle $circle): void {
            $circle->public_id ??= (string) Str::uuid7();
        });

        static::updating(function (Circle $circle): void {
            foreach (['public_id', 'owner_user_id', 'creation_key', 'creation_fingerprint'] as $field) {
                if ($circle->isDirty($field)) {
                    $circle->{$field} = $circle->getOriginal($field);
                }
            }
        });
    }

    protected function casts(): array
    {
        return [
            'directory_listed' => 'boolean',
        ];
    }

    public function getRouteKeyName(): string
    {
        return 'public_id';
    }

    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'owner_user_id');
    }

    public function providerBinding(): HasOne
    {
        return $this->hasOne(CircleProviderBinding::class);
    }

    public function schedules(): HasMany
    {
        return $this->hasMany(CircleSchedule::class);
    }

    public function reports(): HasMany
    {
        return $this->hasMany(CircleDirectoryReport::class);
    }

    public function moderationEvents(): HasMany
    {
        return $this->hasMany(CircleModerationEvent::class);
    }
}
