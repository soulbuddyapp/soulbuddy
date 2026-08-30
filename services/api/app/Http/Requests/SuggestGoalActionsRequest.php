<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class SuggestGoalActionsRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'starter_key' => ['required', Rule::in(['closer_to_god', 'stop_control', 'direction', 'difficult_time', 'other'])],
            'stop_behavior_key' => ['nullable', Rule::in(['pornography', 'gambling', 'nicotine_tobacco', 'alcohol', 'digital_distraction', 'other'])],
            'title' => ['required', 'string', 'max:120'],
            'situation' => ['nullable', 'string', 'max:2000'],
            'agency_choice' => ['required', Rule::in(['steps_i_can_take', 'mostly_pray_and_wait', 'not_sure'])],
            'locale' => ['required', 'string', 'regex:/^[A-Za-z]{2,3}(?:[-_][A-Za-z]{2})?$/', 'max:12'],
            'private_recording' => ['prohibited'],
        ];
    }

    public function context(): array
    {
        return $this->safe()->only([
            'starter_key',
            'stop_behavior_key',
            'title',
            'situation',
            'agency_choice',
            'locale',
        ]);
    }
}
