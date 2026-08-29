<?php

namespace App\Domain\Circles;

final class CircleProviderUrl
{
    /** @var array<string, list<string>> */
    private const HOSTS = [
        'telegram' => ['t.me', 'telegram.me'],
        'whatsapp_link' => ['chat.whatsapp.com', 'wa.me'],
    ];

    public static function isAllowed(string $provider, string $value): bool
    {
        $url = trim($value);
        $parts = parse_url($url);
        if (! is_array($parts)
            || strtolower((string) ($parts['scheme'] ?? '')) !== 'https'
            || isset($parts['user'])
            || isset($parts['pass'])) {
            return false;
        }

        $host = strtolower(rtrim((string) ($parts['host'] ?? ''), '.'));
        if (! in_array($host, self::HOSTS[$provider] ?? [], true)) {
            return false;
        }

        $port = $parts['port'] ?? null;
        if ($port !== null && $port !== 443) {
            return false;
        }

        return isset($parts['path']) && trim((string) $parts['path'], '/') !== '';
    }
}
