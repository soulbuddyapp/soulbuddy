<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Str;
use Laravel\Sanctum\HasApiTokens;

#[Fillable(['name', 'email', 'password'])]
#[Hidden(['password', 'remember_token'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    protected static function booted(): void
    {
        static::creating(function (User $user): void {
            $user->public_id ??= (string) Str::uuid();
        });

        static::updating(function (User $user): void {
            if ($user->isDirty('public_id')) {
                $user->public_id = $user->getOriginal('public_id');
            }
        });
    }

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function installations(): HasMany
    {
        return $this->hasMany(AppInstallation::class);
    }

    public function commitments(): HasMany
    {
        return $this->hasMany(Commitment::class);
    }

    public function commitmentPractices(): HasMany
    {
        return $this->hasMany(CommitmentPractice::class);
    }

    public function commitmentDeclarations(): HasMany
    {
        return $this->hasMany(CommitmentDeclaration::class);
    }

    public function commitmentMeditationPlans(): HasMany
    {
        return $this->hasMany(CommitmentMeditationPlan::class);
    }

    public function commitmentPreparationCycles(): HasMany
    {
        return $this->hasMany(CommitmentPreparationCycle::class);
    }

    public function commitmentMeditationSessions(): HasMany
    {
        return $this->hasMany(CommitmentMeditationSession::class);
    }

    public function prayerReleasePreference(): HasOne
    {
        return $this->hasOne(PrayerReleasePreference::class);
    }

    public function prayerReleaseDownloads(): HasMany
    {
        return $this->hasMany(PrayerReleaseDownload::class);
    }
}
