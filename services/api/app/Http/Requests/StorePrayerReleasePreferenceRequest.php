<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class StorePrayerReleasePreferenceRequest extends FormRequest
{
    private const KEYS = ['weekly_enabled', 'notification_enabled', 'time_zone'];

    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'weekly_enabled' => ['required', 'boolean'],
            'notification_enabled' => ['required', 'boolean'],
            'time_zone' => [
                'nullable',
                'string',
                'max:64',
                Rule::in(timezone_identifiers_list()),
            ],
        ];
    }

    protected function prepareForValidation(): void
    {
        if (array_diff(array_keys($this->all()), self::KEYS) !== []) {
            throw ValidationException::withMessages(['payload' => ['unknown_keys']]);
        }
    }
}
