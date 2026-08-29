<?php

namespace App\Domain\Circles;

final class CircleProviderUrl
{
    /** @var array<string, list<string>> */
    private const HOSTS = [
        'telegram' => ['t.me', 'telegram.me'],
        'whatsapp_link' => ['chat.whatsapp.com'],
    ];

    /** @var list<string> */
    private const TELEGRAM_SERVICE_PATHS = [
        'a',
        'addemoji',
        'addlist',
        'addstickers',
        'addstyle',
        'addtheme',
        'auction',
        'auth',
        'boost',
        'c',
        'call',
        'confirmphone',
        'contact',
        'giftcode',
        'invoice',
        'iv',
        'k',
        'login',
        'm',
        'msg',
        'nft',
        'oauth',
        'proxy',
        'setlanguage',
        'share',
        'socks',
        'web',
        'z',
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

        $segments = array_values(array_filter(
            explode('/', trim((string) ($parts['path'] ?? ''), '/')),
            static fn (string $segment): bool => trim($segment) !== '',
        ));

        return match ($provider) {
            'telegram' => self::isTelegramGroupLink($segments, $parts),
            'whatsapp_link' => count($segments) === 1,
            default => false,
        };
    }

    /**
     * @param  list<string>  $segments
     * @param  array<string, mixed>  $parts
     */
    private static function isTelegramGroupLink(array $segments, array $parts): bool
    {
        if (isset($parts['query']) || isset($parts['fragment'])) {
            return false;
        }

        if (count($segments) === 2 && strtolower($segments[0]) === 'joinchat') {
            return trim($segments[1]) !== '';
        }
        if (count($segments) !== 1) {
            return false;
        }

        $target = trim($segments[0]);
        if (str_starts_with($target, '+')) {
            return strlen($target) > 1;
        }

        return $target !== ''
            && ! in_array(strtolower($target), self::TELEGRAM_SERVICE_PATHS, true)
            && strtolower($target) !== 'joinchat';
    }
}
