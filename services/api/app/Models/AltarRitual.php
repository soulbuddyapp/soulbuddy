<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class AltarRitual extends Model
{
    use HasUuids;

    protected $guarded = [];

    protected function casts(): array
    {
        return ['enabled' => 'boolean', 'archived_at' => 'datetime'];
    }
}
