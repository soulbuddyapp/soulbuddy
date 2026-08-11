<?php

namespace App\Domain\PrayerDrafts;

final readonly class GeneratePrayerDraft
{
    public function __construct(
        private PrayerDraftProvider $provider,
        private PrayerDraftValidator $validator,
    ) {}

    public function handle(PrayerDraftInput $input): PrayerDraftResult
    {
        try {
            $first = $this->provider->generate($input, null);
            $codes = $this->validator->codes($first, $input);
        } catch (PrayerDraftInvalidResponse) {
            $codes = ['invalid_json_envelope'];
        }

        if ($codes === []) {
            return $first;
        }

        $repaired = $this->provider->generate($input, $codes);
        if ($this->validator->codes($repaired, $input) !== []) {
            throw new PrayerDraftInvalidResponse;
        }

        return $repaired;
    }
}
