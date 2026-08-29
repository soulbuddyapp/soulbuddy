<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

class CircleContentPlan extends Model
{
    protected $guarded = [];

    protected static function booted(): void
    {
        static::creating(function (CircleContentPlan $plan): void {
            $plan->public_id ??= (string) Str::uuid7();
        });
    }

    protected function casts(): array
    {
        return ['editorial_item_ids' => 'array'];
    }
}
