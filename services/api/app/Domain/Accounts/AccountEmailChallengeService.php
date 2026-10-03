<?php

namespace App\Domain\Accounts;

use App\Mail\AccountEmailVerification;
use App\Models\User;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AccountEmailChallengeService
{
    /**
     * @return array{id: string, expires_at: string}
     */
    public function issue(User $user, string $email): array
    {
        $id = (string) Str::uuid();
        $token = bin2hex(random_bytes(32));
        $expiresAt = now()->addMinutes(10);

        DB::transaction(function () use ($user, $email, $id, $token, $expiresAt): void {
            DB::table('account_challenges')
                ->where('user_id', $user->id)
                ->where('purpose', 'attach_email')
                ->whereNull('consumed_at')
                ->update(['consumed_at' => now()]);

            DB::table('account_challenges')->insert([
                'id' => $id,
                'user_id' => $user->id,
                'purpose' => 'attach_email',
                'email' => $email,
                'token_hash' => hash('sha256', $token),
                'expires_at' => $expiresAt,
                'created_at' => now(),
            ]);
        });

        $url = rtrim((string) config('app.url'), '/')
            .'/app/verify#challenge='.rawurlencode($id)
            .'&token='.rawurlencode($token);

        Mail::to($email)->send(new AccountEmailVerification($url));

        return [
            'id' => $id,
            'expires_at' => $expiresAt->toIso8601String(),
        ];
    }

    public function confirm(User $user, string $id, string $token): void
    {
        DB::transaction(function () use ($user, $id, $token): void {
            $challenge = DB::table('account_challenges')
                ->where('id', $id)
                ->lockForUpdate()
                ->first();

            if ($challenge === null || $challenge->user_id !== $user->id) {
                $this->invalidLink();
            }

            $this->consume($user, $challenge, $token);
        }, attempts: 3);
    }

    public function confirmLink(string $id, string $token): User
    {
        return DB::transaction(function () use ($id, $token): User {
            $challenge = DB::table('account_challenges')
                ->where('id', $id)
                ->lockForUpdate()
                ->first();
            if ($challenge === null) {
                $this->invalidLink();
            }

            $user = User::query()->whereKey($challenge->user_id)->lockForUpdate()->first();
            if ($user === null) {
                $this->invalidLink();
            }

            $this->consume($user, $challenge, $token);

            return $user;
        }, attempts: 3);
    }

    private function consume(User $user, object $challenge, string $token): void
    {
        if ($challenge->purpose !== 'attach_email' ||
            $challenge->consumed_at !== null ||
            now()->greaterThan($challenge->expires_at) ||
            ! hash_equals($challenge->token_hash, hash('sha256', $token))) {
            $this->invalidLink();
        }

        $taken = User::query()
            ->where('email', $challenge->email)
            ->whereKeyNot($user->id)
            ->exists();
        if ($taken) {
            throw ValidationException::withMessages(['email' => ['unavailable']]);
        }

        $user->forceFill([
            'email' => $challenge->email,
            'email_verified_at' => now(),
        ])->save();

        DB::table('account_challenges')
            ->where('id', $challenge->id)
            ->update(['consumed_at' => now()]);
    }

    private function invalidLink(): never
    {
        throw new HttpResponseException(new JsonResponse([
            'message' => 'Verification link is no longer valid.',
        ], 410));
    }
}
