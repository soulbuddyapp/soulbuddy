<?php

namespace App\Domain\PrayerDrafts;

use App\Models\User;

final readonly class PrayerDraftInput
{
    /**
     * @param  array<string, ?string>  $choices
     * @param  list<array<string, mixed>>  $contexts
     */
    public function __construct(
        public string $userPublicId,
        public string $attemptId,
        public string $style,
        public string $reach,
        public string $grounding,
        public string $languagePreference,
        public string $purpose,
        public string $requestText,
        public array $choices,
        public array $contexts,
    ) {}

    /** @param array<string, mixed> $validated */
    public static function fromValidated(array $validated, User $user): self
    {
        return new self(
            userPublicId: $user->public_id,
            attemptId: $validated['attempt_id'],
            style: $validated['style'],
            reach: $validated['reach'],
            grounding: $validated['grounding'],
            languagePreference: $validated['language_preference']
                ?? ($validated['grounding'] === 'catholic' ? 'catholic' : 'christian'),
            purpose: $validated['purpose'],
            requestText: trim($validated['request_text']),
            choices: $validated['choices'] ?? [],
            contexts: $validated['contexts'] ?? [],
        );
    }

    /** @return array<string, mixed> */
    public function promptData(): array
    {
        return [
            'style' => $this->style,
            'reach' => $this->reach,
            'grounding' => $this->grounding,
            'language_preference' => $this->languagePreference,
            'purpose' => $this->purpose,
            'request' => $this->requestText,
            'choices' => $this->choices,
            'selected_context' => $this->contexts,
        ];
    }

    public function hasScriptureContext(): bool
    {
        return collect($this->contexts)->contains(
            fn (array $context): bool => $context['type'] === 'scripture',
        );
    }
}
