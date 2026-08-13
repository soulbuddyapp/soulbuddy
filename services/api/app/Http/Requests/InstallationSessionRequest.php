<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\ValidationException;

class InstallationSessionRequest extends FormRequest
{
    private const KEYS = ['owner_id', 'device_id', 'installation_secret'];

    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'owner_id' => ['required', 'uuid'],
            'device_id' => ['required', 'uuid'],
            'installation_secret' => ['required', 'string', 'size:64'],
        ];
    }

    protected function prepareForValidation(): void
    {
        if (array_diff(array_keys($this->all()), self::KEYS) !== []) {
            throw ValidationException::withMessages(['payload' => ['unknown_keys']]);
        }
    }
}
