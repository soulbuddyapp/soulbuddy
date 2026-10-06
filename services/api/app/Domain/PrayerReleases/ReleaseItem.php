<?php

namespace App\Domain\PrayerReleases;

final readonly class ReleaseItem
{
    public function __construct(
        public int $sortOrder,
        public string $kind,
        public string $purpose,
        public string $grounding,
        public string $languageStyle,
        public ?string $action,
        public string $title,
        public string $body,
        public ?RepetitionPractice $practice,
    ) {
    }

    public function contentHash(): string
    {
        return ReleaseContent::contentHash($this->title, $this->body);
    }
}
