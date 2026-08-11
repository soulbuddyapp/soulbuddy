<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Str;

#[Fillable(['name', 'email', 'password'])]
#[Hidden(['password', 'remember_token'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasFactory, Notifiable;

    /** @var array<int, string> */
    private array $prayerIdsPendingVoteDeletion = [];

    public function delete()
    {
        return $this->getConnection()->transaction(fn () => parent::delete());
    }

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

        static::deleting(function (User $user): void {
            User::query()
                ->whereKey($user->getKey())
                ->lockForUpdate()
                ->first();

            $user->prayerIdsPendingVoteDeletion = PrayerVote::query()
                ->where('user_id', $user->id)
                ->pluck('prayer_id')
                ->unique()
                ->values()
                ->all();

            LibraryPrayer::query()
                ->whereIn('id', $user->prayerIdsPendingVoteDeletion)
                ->orderBy('id')
                ->lockForUpdate()
                ->get(['id']);
        });

        static::deleted(function (User $user): void {
            foreach ($user->prayerIdsPendingVoteDeletion as $prayerId) {
                LibraryPrayer::query()->whereKey($prayerId)->update([
                    'helpful_count' => PrayerVote::where('prayer_id', $prayerId)->count(),
                ]);
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
}
