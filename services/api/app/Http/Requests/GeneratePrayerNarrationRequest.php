<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class GeneratePrayerNarrationRequest extends FormRequest
{
    private const KEYS = [
        'personal_prayer_id', 'prayer_revision_id', 'disclosure_version', 'consent',
    ];

    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'personal_prayer_id' => ['required', 'uuid'],
            'prayer_revision_id' => ['required', 'uuid'],
            'disclosure_version' => [
                'required',
                'string',
                Rule::in([(string) config('services.deepgram.disclosure_version')]),
            ],
            'consent' => ['required', 'accepted'],
        ];
    }

    protected function prepareForValidation(): void
    {
        if (array_diff(array_keys($this->all()), self::KEYS) !== []) {
            throw ValidationException::withMessages(['payload' => ['unknown_keys']]);
        }
    }
}
