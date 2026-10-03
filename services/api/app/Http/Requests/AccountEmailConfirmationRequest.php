<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\ValidationException;

class AccountEmailConfirmationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'challenge_id' => ['required', 'uuid'],
            'token' => ['required', 'string', 'regex:/^[a-f0-9]{64}$/'],
        ];
    }

    protected function prepareForValidation(): void
    {
        if (array_diff(array_keys($this->all()), ['challenge_id', 'token']) !== []) {
            throw ValidationException::withMessages(['payload' => ['unknown_keys']]);
        }
    }
}
