<?php

namespace App\Http\Requests;

use App\Domain\PrayerDrafts\PrayerDraftInput;
use App\Models\User;
use Closure;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Arr;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class GeneratePrayerDraftRequest extends FormRequest
{
    private const TOP_LEVEL_KEYS = [
        'attempt_id', 'disclosure_version', 'consent', 'style', 'reach',
        'grounding', 'language_preference', 'purpose', 'request_text', 'choices', 'contexts',
    ];

    private const CHOICE_KEYS = [
        'beneficiary', 'surrender', 'responsibility', 'alignment',
    ];

    private const CONTEXT_KEYS = [
        'type', 'source_id', 'display_label', 'excerpt_snapshot',
        'translation', 'book', 'chapter', 'first_verse', 'last_verse',
    ];

    public function authorize(): bool
    {
        return true;
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'attempt_id' => ['required', 'uuid'],
            'disclosure_version' => [
                'required',
                'string',
                Rule::in([(string) config('services.deepseek.disclosure_version')]),
            ],
            'consent' => ['required', 'accepted'],
            'style' => ['required', Rule::in(['daily', 'situational'])],
            'reach' => ['required', Rule::in(['personal', 'encompassing'])],
            'grounding' => ['required', Rule::in(['general_christian', 'catholic'])],
            'language_preference' => ['sometimes', Rule::in(['christian', 'catholic', 'jesus', 'all'])],
            'purpose' => ['required', Rule::in([
                'daily', 'gratitude', 'guidance', 'family', 'healing', 'work',
                'forgiveness', 'difficult_time',
            ])],
            'request_text' => ['required', 'string', 'min:1', 'max:500'],
            'choices' => ['present', 'array'],
            'choices.beneficiary' => [
                'nullable',
                Rule::requiredIf(fn (): bool => $this->input('style') === 'situational'),
                Rule::in(['me', 'household_family', 'another_person', 'people_affected', 'beyond_my_sight']),
            ],
            'choices.surrender' => [
                'nullable',
                Rule::requiredIf(fn (): bool => $this->input('style') === 'situational'),
                Rule::in(['outcome', 'timing', 'way_it_happens', 'all']),
            ],
            'choices.responsibility' => [
                'nullable',
                Rule::requiredIf(fn (): bool => $this->input('style') === 'situational'),
                Rule::in(['use_wisely', 'share_or_serve', 'repair_attention', 'act_faithfully', 'time_to_discern']),
            ],
            'choices.alignment' => [
                'nullable',
                Rule::requiredIf(fn (): bool => $this->input('style') === 'situational'),
                Rule::in(['no_conflict_seen', 'examine_further']),
            ],
            'contexts' => ['present', 'array', 'max:2'],
            'contexts.*.type' => ['required', Rule::in(['encounter', 'scripture'])],
            'contexts.*.source_id' => ['required', 'string', 'max:120'],
            'contexts.*.display_label' => ['required', 'string', 'max:200'],
            'contexts.*.excerpt_snapshot' => [
                'required',
                'string',
                function (string $attribute, mixed $value, Closure $fail): void {
                    if (! is_string($value)) {
                        return;
                    }
                    preg_match('/contexts\.(\d+)\./', $attribute, $matches);
                    $type = $this->input('contexts.'.($matches[1] ?? '').'.type');
                    $maximum = $type === 'scripture' ? 4000 : 2000;
                    if (mb_strlen($value) > $maximum) {
                        $fail('context_excerpt_too_long');
                    }
                },
            ],
            'contexts.*.translation' => ['nullable', 'string', Rule::in(['RSVCE'])],
            'contexts.*.book' => ['nullable', 'string', 'max:80'],
            'contexts.*.chapter' => ['nullable', 'integer', 'min:1', 'max:200'],
            'contexts.*.first_verse' => ['nullable', 'integer', 'min:1', 'max:200'],
            'contexts.*.last_verse' => ['nullable', 'integer', 'min:1', 'max:200'],
        ];
    }

    protected function prepareForValidation(): void
    {
        $unknown = array_diff(array_keys($this->all()), self::TOP_LEVEL_KEYS);
        $choices = $this->input('choices');
        if (is_array($choices)) {
            $unknown = [...$unknown, ...array_diff(array_keys($choices), self::CHOICE_KEYS)];
        }
        $contexts = $this->input('contexts');
        if (is_array($contexts)) {
            foreach ($contexts as $context) {
                if (is_array($context)) {
                    $unknown = [...$unknown, ...array_diff(array_keys($context), self::CONTEXT_KEYS)];
                }
            }
        }
        if ($unknown !== []) {
            throw ValidationException::withMessages(['payload' => ['unknown_keys']]);
        }
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator): void {
            $contexts = $this->input('contexts');
            if (! is_array($contexts)) {
                return;
            }
            $types = [];
            foreach ($contexts as $index => $context) {
                if (! is_array($context) || ! is_string($context['type'] ?? null)) {
                    continue;
                }
                $type = $context['type'];
                if (in_array($type, $types, true)) {
                    $validator->errors()->add("contexts.{$index}.type", 'duplicate_context_type');
                }
                $types[] = $type;
                $scriptureKeys = ['translation', 'book', 'chapter', 'first_verse', 'last_verse'];
                if ($type === 'encounter' && Arr::hasAny($context, $scriptureKeys)) {
                    $validator->errors()->add("contexts.{$index}", 'invalid_context_shape');
                }
                if ($type === 'scripture') {
                    foreach ($scriptureKeys as $key) {
                        if (! array_key_exists($key, $context) || $context[$key] === null || $context[$key] === '') {
                            $validator->errors()->add("contexts.{$index}.{$key}", 'required');
                        }
                    }
                    $first = $context['first_verse'] ?? null;
                    $last = $context['last_verse'] ?? null;
                    if (is_int($first) && is_int($last) && ($last < $first || $last - $first + 1 > 20)) {
                        $validator->errors()->add("contexts.{$index}.last_verse", 'invalid_verse_range');
                    }
                }
            }
        });
    }

    public function toDomain(User $user): PrayerDraftInput
    {
        return PrayerDraftInput::fromValidated($this->validated(), $user);
    }
}
