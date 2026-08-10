<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class SyncMutationBatchRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'operations' => ['required', 'array', 'min:1', 'max:100'],
            'operations.*.operation_id' => ['required', 'uuid', 'distinct'],
            'operations.*.table' => ['required', 'string', 'max:64'],
            'operations.*.type' => ['required', 'string', 'in:put,patch,delete'],
            'operations.*.id' => ['required', 'uuid'],
            'operations.*.data' => ['present', 'array'],
        ];
    }
}
