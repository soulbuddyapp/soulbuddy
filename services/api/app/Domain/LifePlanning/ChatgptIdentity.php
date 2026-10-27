<?php

namespace App\Domain\LifePlanning;

use App\Models\User;
use Firebase\JWT\JWK;
use Firebase\JWT\JWT;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use RuntimeException;
use Throwable;

class ChatgptIdentity
{
    public function configured(): bool
    {
        return $this->issuer() !== '' && $this->audience() !== ''
            && $this->jwksUrl() !== '' && str_starts_with($this->jwksUrl(), 'https://');
    }

    public function issuer(): string
    {
        $issuer = rtrim((string) config('services.chatgpt.issuer'), '/');

        return $issuer === '' ? '' : $issuer.'/';
    }

    public function audience(): string
    {
        return (string) config('services.chatgpt.audience');
    }

    public function resource(): string
    {
        return rtrim((string) config('app.url'), '/').'/mcp';
    }

    public function authenticate(Request $request, string $scope): ?User
    {
        $bearer = $request->bearerToken();
        if (! $this->configured() || ! $bearer || strlen($bearer) > 8192) {
            return null;
        }

        try {
            $header = json_decode(JWT::urlsafeB64Decode(explode('.', $bearer)[0]), true, 8, JSON_THROW_ON_ERROR);
            if (($header['alg'] ?? '') !== 'RS256' || empty($header['kid'])) {
                return null;
            }

            $keys = Cache::remember(
                'soulbuddy:chatgpt:jwks:'.hash('sha256', $this->jwksUrl()),
                now()->addMinutes(15),
                function (): array {
                    $response = Http::timeout(4)->acceptJson()->get($this->jwksUrl())->throw();
                    $payload = $response->json();

                    if (! is_array($payload) || ! is_array($payload['keys'] ?? null)) {
                        throw new RuntimeException('Invalid JWKS');
                    }

                    return $payload;
                },
            );
            $trustedKeys = array_values(array_filter($keys['keys'], fn (array $key): bool => ($key['kty'] ?? null) === 'RSA'
                && in_array($key['alg'] ?? 'RS256', ['RS256'], true)
                && ($key['use'] ?? 'sig') === 'sig'));
            $claims = JWT::decode($bearer, JWK::parseKeySet(['keys' => $trustedKeys], 'RS256'));
            if (($claims->iss ?? null) !== $this->issuer() ||
                ! in_array($this->audience(), (array) ($claims->aud ?? []), true) ||
                empty($claims->sub) || ! is_string($claims->sub)) {
                return null;
            }

            $scopes = preg_split('/\\s+/', (string) ($claims->scope ?? ''), -1, PREG_SPLIT_NO_EMPTY);
            if (! in_array($scope, $scopes, true)) {
                return null;
            }

            // Only verified identity claims from our pinned OAuth issuer may link an existing SoulBuddy account.
            $emailClaim = (string) config('services.chatgpt.email_claim', 'email');
            $verifiedClaim = (string) config('services.chatgpt.email_verified_claim', 'email_verified');
            $email = $claims->{$emailClaim} ?? null;
            if (! is_string($email) || ! filter_var($email, FILTER_VALIDATE_EMAIL) ||
                ($claims->{$verifiedClaim} ?? false) !== true) {
                return null;
            }
            $email = mb_strtolower($email);

            $user = User::query()->where('email', $email)->first();
            if ($user) {
                // Never take over a pending/unverified local installation's identity.
                return $user->email_verified_at ? $user : null;
            }

            try {
                $user = new User;
                $user->forceFill([
                    'email' => $email,
                    'email_verified_at' => now(),
                    'name' => 'SoulBuddy member',
                    'password' => Str::random(64),
                ])->save();
            } catch (UniqueConstraintViolationException) {
                $user = User::query()->where('email', $email)->first();
            }

            return $user?->email_verified_at ? $user : null;
        } catch (Throwable) {
            // Never echo JWTs, claims, email, identity provider errors, or personal data to clients or logs.
            return null;
        }
    }

    private function jwksUrl(): string
    {
        return (string) config('services.chatgpt.jwks_url');
    }
}
