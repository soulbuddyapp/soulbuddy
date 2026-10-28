<?php

namespace App\Domain\LifePlanning;

use Firebase\JWT\JWK;
use Firebase\JWT\JWT;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use RuntimeException;
use Throwable;

class ChatgptIdentity
{
    public function configured(): bool
    {
        return filter_var($this->issuer(), FILTER_VALIDATE_URL) &&
            parse_url($this->issuer(), PHP_URL_SCHEME) === 'https' &&
            $this->audience() !== ''
            && str_starts_with($this->jwksUrl(), 'https://')
            && str_starts_with((string) config('services.chatgpt.introspection_url'), 'https://')
            && (string) config('services.chatgpt.introspection_client_id') !== ''
            && (string) config('services.chatgpt.introspection_client_secret') !== '';
    }

    public function issuer(): string
    {
        return (string) config('services.chatgpt.issuer');
    }

    public function audience(): string
    {
        return (string) config('services.chatgpt.audience');
    }

    public function resource(): string
    {
        return rtrim((string) config('app.url'), '/').'/mcp';
    }

    public function accountManagementUrl(): ?string
    {
        $url = (string) config('services.chatgpt.account_management_url');
        if (! $this->configured() || ! filter_var($url, FILTER_VALIDATE_URL) ||
            ! filter_var($this->issuer(), FILTER_VALIDATE_URL)) {
            return null;
        }

        $target = parse_url($url);
        $issuer = parse_url($this->issuer());
        if (! is_array($target) || ! is_array($issuer) ||
            strtolower($target['scheme'] ?? '') !== 'https' ||
            strtolower($issuer['scheme'] ?? '') !== 'https' ||
            empty($target['host']) || empty($issuer['host']) ||
            strcasecmp($target['host'], $issuer['host']) !== 0 ||
            ($target['port'] ?? 443) !== ($issuer['port'] ?? 443) ||
            isset($target['user']) || isset($target['pass']) ||
            isset($target['query']) || isset($target['fragment']) ||
            isset($issuer['user']) || isset($issuer['pass']) ||
            isset($issuer['query']) || isset($issuer['fragment'])) {
            return null;
        }

        return $url;
    }

    /** @return array{issuer:string, subject:string, email:?string, email_verified:bool}|null */
    public function verify(Request $request, string $scope): ?array
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
            $issuedAt = $claims->iat ?? null;
            $expiresAt = $claims->exp ?? null;
            // Require bounded lifetime; JWT libraries only check exp when the claim exists.
            if (! is_int($issuedAt) || ! is_int($expiresAt) ||
                $expiresAt <= $issuedAt || $expiresAt - $issuedAt > 3600) {
                return null;
            }

            if (($claims->iss ?? null) !== $this->issuer() ||
                ! in_array($this->audience(), (array) ($claims->aud ?? []), true) ||
                empty($claims->sub) || ! is_string($claims->sub)) {
                return null;
            }

            $scopes = preg_split('/\\s+/', (string) ($claims->scope ?? ''), -1, PREG_SPLIT_NO_EMPTY);
            if (! in_array($scope, $scopes, true)) {
                return null;
            }

            // Check every call; never cache active status or follow redirects carrying credentials.
            $status = Http::asForm()->acceptJson()->connectTimeout(3)->timeout(5)
                ->withoutRedirecting()->withBasicAuth(
                    urlencode((string) config('services.chatgpt.introspection_client_id')),
                    urlencode((string) config('services.chatgpt.introspection_client_secret')),
                )->post((string) config('services.chatgpt.introspection_url'), [
                    'token' => $bearer,
                    'token_type_hint' => 'access_token',
                ]);
            if (! $status->successful() || $status->json('active') !== true ||
                ! is_string($status->json('sub')) || ! hash_equals($claims->sub, $status->json('sub'))) {
                return null;
            }

            // Email is profile metadata, never an account lookup key. Existing bindings
            // continue to work when the provider changes or stops emitting this claim.
            $emailClaim = (string) config('services.chatgpt.email_claim', 'email');
            $verifiedClaim = (string) config('services.chatgpt.email_verified_claim', 'email_verified');
            $email = $claims->{$emailClaim} ?? null;
            $email = is_string($email) && strlen($email) <= 254 &&
                filter_var($email, FILTER_VALIDATE_EMAIL) ? mb_strtolower($email) : null;

            if (strlen($claims->sub) > 255 || strlen($this->issuer()) > 255) {
                return null;
            }

            return [
                'issuer' => $this->issuer(),
                'subject' => $claims->sub,
                'email' => $email,
                'email_verified' => $email !== null && ($claims->{$verifiedClaim} ?? false) === true,
            ];
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
