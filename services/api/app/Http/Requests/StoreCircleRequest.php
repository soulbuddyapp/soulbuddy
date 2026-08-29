<?php

namespace App\Http\Requests;

use App\Domain\Circles\CircleProviderUrl;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Illuminate\Validation\Validator;

class StoreCircleRequest extends FormRequest
{
    private const KEYS = [
        'creation_key', 'name', 'category', 'description', 'visibility', 'status', 'provider', 'open_url',
    ];

    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'creation_key' => ['required', 'uuid'],
            'name' => ['required', 'string', 'max:80'],
            'category' => ['required', Rule::in(['accountability', 'daily_exhortation', 'bible_study'])],
            'description' => ['required', 'string', 'max:280'],
            'visibility' => ['required', Rule::in(['public', 'unlisted', 'private'])],
            'status' => ['sometimes', 'required', Rule::in(['draft', 'active'])],
            'provider' => ['required', Rule::in(['telegram', 'whatsapp_link'])],
            'open_url' => ['required', 'string', 'max:2048'],
        ];
    }

    public function after(): array
    {
        return [function (Validator $validator): void {
            if ($validator->errors()->isNotEmpty()) {
                return;
            }
            if (! CircleProviderUrl::isAllowed(
                (string) $this->input('provider'),
                (string) $this->input('open_url'),
            )) {
                $validator->errors()->add('open_url', 'provider_url');
            }
        }];
    }

    protected function prepareForValidation(): void
    {
        if (array_diff(array_keys($this->all()), self::KEYS) !== []) {
            throw ValidationException::withMessages(['payload' => ['unknown_keys']]);
        }
    }
}
