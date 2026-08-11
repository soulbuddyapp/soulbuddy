<?php

namespace App\Domain\PrayerDrafts;

final readonly class PrayerDraftResult
{
    public function __construct(
        public string $title,
        public string $body,
        public ?string $action,
    ) {}

    /** @param array<string, mixed> $value */
    public static function fromArray(array $value): self
    {
        $keys = array_keys($value);
        sort($keys);
        if ($keys !== ['action', 'body', 'title']
            || ! is_string($value['title'] ?? null)
            || ! is_string($value['body'] ?? null)
            || (! is_null($value['action'] ?? null) && ! is_string($value['action'] ?? null))) {
            throw new PrayerDraftInvalidResponse;
        }

        return new self($value['title'], $value['body'], $value['action']);
    }

    /** @return array{title: string, body: string, action: ?string} */
    public function toArray(): array
    {
        return [
            'title' => $this->title,
            'body' => $this->body,
            'action' => $this->action,
        ];
    }
}
