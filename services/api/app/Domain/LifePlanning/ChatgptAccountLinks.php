<?php

namespace App\Domain\LifePlanning;

use App\Models\User;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class ChatgptAccountLinks
{
    public function resolve(array $principal): ?User
    {
        $link = DB::table('chatgpt_oauth_identities')
            ->where('identity_hash', $this->identityHash($principal))
            ->first();

        return $link ? User::query()->find($link->user_id) : null;
    }

    /**
     * Provision a new account only after the person consents.
     * Never merge with an existing SoulBuddy account by matching email.
     */
    public function create(array $principal, array $input): User
    {
        Validator::make($input, ['confirmed' => ['required', 'accepted']])->validate();
        $email = $this->verifiedEmail($principal);

        try {
            return DB::transaction(function () use ($principal, $email): User {
                $existing = $this->resolve($principal);
                if ($existing) {
                    return $existing; // Idempotent repeat with the same stable identity.
                }
                if (User::query()->where('email', $email)->exists()) {
                    $this->fail('A SoulBuddy account already uses this email. Link it from the signed-in SoulBuddy app instead.');
                }

                $user = new User;
                $user->forceFill([
                    'email' => $email,
                    'email_verified_at' => now(),
                    'name' => 'SoulBuddy member',
                    'password' => Str::random(64),
                ])->save();

                $this->insertBinding($user, $principal);

                return $user;
            }, attempts: 3);
        } catch (UniqueConstraintViolationException) {
            // Competing registrations may race on the same issuer/sub or email.
            // Never infer ownership from the email after that conflict.
            return $this->resolve($principal) ?? $this->fail('Account registration conflicted. Retry or link an existing account.');
        }
    }

    /**
     * Issue a high-entropy, one-use code only from an authenticated SoulBuddy session.
     * The caller must show the code on the trusted app side, not publish it.
     */
    public function issueCode(User $user, array $input): array
    {
        Validator::make($input, ['confirmed' => ['required', 'accepted']])->validate();
        if (! $user->email_verified_at || str_ends_with($user->email, '.invalid')) {
            $this->fail('Verify your SoulBuddy account email before linking to ChatGPT.');
        }

        return DB::transaction(function () use ($user): array {
            User::query()->whereKey($user->id)->lockForUpdate()->firstOrFail();
            DB::table('chatgpt_account_link_codes')->where('user_id', $user->id)
                ->whereNull('consumed_at')->update(['consumed_at' => now()]);

            $code = bin2hex(random_bytes(16)); // 128-bit, not a guessable six-digit PIN.
            $expires = now()->addMinutes(10);
            DB::table('chatgpt_account_link_codes')->insert([
                'id' => (string) Str::uuid(),
                'user_id' => $user->id,
                'code_hash' => hash('sha256', $code),
                'expires_at' => $expires,
                'created_at' => now(),
            ]);

            return [
                'code' => $code,
                'expires_at' => $expires->toIso8601String(),
                'message' => 'Use this one-time code in the authenticated ChatGPT linking tool. It expires in ten minutes.',
            ];
        }, attempts: 3);
    }

    /**
     * Both the already-authenticated SoulBuddy session (code issuer) and
     * the separately-authenticated OAuth subject must prove control.
     */
    public function link(array $principal, array $input): User
    {
        $data = Validator::make($input, [
            'confirmed' => ['required', 'accepted'],
            'code' => ['required', 'string', 'regex:/^[a-f0-9]{32}$/i'],
        ])->validate();
        $email = $this->verifiedEmail($principal);
        $codeHash = hash('sha256', strtolower($data['code']));

        try {
            return DB::transaction(function () use ($principal, $email, $codeHash): User {
                // Match the account-then-challenge lock order used during code issuance.
                $candidate = DB::table('chatgpt_account_link_codes')
                    ->where('code_hash', $codeHash)->first();
                if (! $candidate) {
                    $this->fail('This link code is invalid, expired, or already used.');
                }
                $user = User::query()->whereKey($candidate->user_id)->lockForUpdate()->first();
                $challenge = DB::table('chatgpt_account_link_codes')
                    ->where('id', $candidate->id)
                    ->where('code_hash', $codeHash)->lockForUpdate()->first();
                if (! $challenge || $challenge->consumed_at !== null ||
                    now()->greaterThanOrEqualTo($challenge->expires_at)) {
                    $this->fail('This link code is invalid, expired, or already used.');
                }
                if (! $user || ! $user->email_verified_at ||
                    ! hash_equals(mb_strtolower($user->email), $email)) {
                    $this->fail('The verified email on both accounts must match before linking.');
                }

                $existing = $this->resolve($principal);
                if ($existing && $existing->id !== $user->id) {
                    $this->fail('This ChatGPT identity is already attached to a different SoulBuddy account.');
                }

                $other = DB::table('chatgpt_oauth_identities')
                    ->where('user_id', $user->id)
                    ->where('issuer_hash', hash('sha256', $principal['issuer']))->first();
                if ($other && $other->identity_hash !== $this->identityHash($principal)) {
                    $this->fail('This SoulBuddy account is already linked to a different identity at that provider.');
                }

                if (! $existing) {
                    $this->insertBinding($user, $principal);
                }

                DB::table('chatgpt_account_link_codes')->where('id', $challenge->id)
                    ->update(['consumed_at' => now()]);

                return $user;
            }, attempts: 3);
        } catch (UniqueConstraintViolationException) {
            $this->fail('The identity was linked concurrently. Check your account and request another code if necessary.');
        }
    }

    /** Stop OAuth access to this account even when the provider token remains active. */
    public function unlink(User $user, array $input): array
    {
        Validator::make($input, ['confirmed' => ['required', 'accepted']])->validate();
        $removed = DB::transaction(function () use ($user): int {
            User::query()->whereKey($user->id)->lockForUpdate()->firstOrFail();
            DB::table('chatgpt_account_link_codes')->where('user_id', $user->id)
                ->whereNull('consumed_at')->update(['consumed_at' => now()]);

            return DB::table('chatgpt_oauth_identities')->where('user_id', $user->id)->delete();
        }, attempts: 3);

        return [
            'unlinked' => $removed > 0,
            'message' => 'ChatGPT identity disconnected from this SoulBuddy account. End the provider session separately to revoke existing tokens.',
        ];
    }

    private function insertBinding(User $user, array $principal): void
    {
        DB::table('chatgpt_oauth_identities')->insert([
            'id' => (string) Str::uuid(),
            'user_id' => $user->id,
            'issuer' => $principal['issuer'],
            'subject' => $principal['subject'],
            'identity_hash' => $this->identityHash($principal),
            'issuer_hash' => hash('sha256', $principal['issuer']),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function identityHash(array $principal): string
    {
        return hash('sha256', $principal['issuer']."\0".$principal['subject']);
    }

    private function verifiedEmail(array $principal): string
    {
        if (($principal['email_verified'] ?? false) !== true || ! is_string($principal['email'] ?? null)) {
            $this->fail('A verified email claim from the connected identity provider is required to create or link an account.');
        }

        return $principal['email'];
    }

    private function fail(string $message): never
    {
        throw ValidationException::withMessages(['account' => [$message]]);
    }
}
