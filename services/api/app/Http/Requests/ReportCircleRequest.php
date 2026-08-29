<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class ReportCircleRequest extends FormRequest
{
    private const KEYS = ['reason'];

    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'reason' => ['required', Rule::in(['spam', 'unsafe', 'misleading', 'other'])],
        ];
    }

    protected function prepareForValidation(): void
    {
        if (array_diff(array_keys($this->all()), self::KEYS) !== []) {
            throw ValidationException::withMessages(['payload' => ['unknown_keys']]);
        }
    }
}
