<?php

use App\Domain\PrayerDrafts\PrayerDraftInput;
use App\Domain\PrayerDrafts\PrayerDraftResult;
use App\Domain\PrayerDrafts\PrayerDraftValidator;
use App\Models\User;
use Illuminate\Support\Str;

it('accepts at least 32 synthetic cases across the complete controlled choice set', function () {
    $cases = (static fn (): array => require base_path('tests/Fixtures/prayer_draft_cases.php'))();
    $validator = app(PrayerDraftValidator::class);
    $user = User::factory()->make(['public_id' => (string) Str::uuid()]);
    $styles = $reaches = $groundings = $purposes = $topics = $contextCounts = [];
    $choiceValues = [];

    expect($cases)->toHaveCount(32);
    foreach ($cases as $case) {
        $input = PrayerDraftInput::fromValidated($case['input'], $user);
        $draft = PrayerDraftResult::fromArray($case['draft']);
        expect($validator->codes($draft, $input))->toBe([], $case['name']);
        $styles[] = $input->style;
        $reaches[] = $input->reach;
        $groundings[] = $input->grounding;
        $purposes[] = $input->purpose;
        $topics[] = $case['topic'];
        $contextCounts[] = count($input->contexts);
        $choiceValues = [...$choiceValues, ...array_values(array_filter($input->choices))];
    }

    expect(array_unique($styles))->toHaveCount(2)
        ->and(array_unique($reaches))->toHaveCount(2)
        ->and(array_unique($groundings))->toHaveCount(2)
        ->and(array_unique($purposes))->toHaveCount(8)
        ->and(array_unique($topics))->toHaveCount(8)
        ->and(array_unique($contextCounts))->toHaveCount(3);
    foreach ([
        'me', 'household_family', 'another_person', 'people_affected', 'beyond_my_sight',
        'outcome', 'timing', 'way_it_happens', 'all', 'use_wisely',
        'share_or_serve', 'repair_attention', 'act_faithfully', 'time_to_discern',
        'no_conflict_seen', 'examine_further',
    ] as $choice) {
        expect($choiceValues)->toContain($choice);
    }
});

it('returns only safe validation codes for unsafe or malformed wording', function (
    string $body,
    ?string $action,
    array $contexts,
    string $expectedCode,
    string $title = 'Safe title',
) {
    $case = (static fn (): array => require base_path('tests/Fixtures/prayer_draft_cases.php'))()[0];
    $case['input']['contexts'] = $contexts;
    $input = PrayerDraftInput::fromValidated(
        $case['input'],
        User::factory()->make(['public_id' => (string) Str::uuid()]),
    );
    $codes = app(PrayerDraftValidator::class)->codes(
        new PrayerDraftResult($title, $body, $action),
        $input,
    );

    expect($codes)->toContain($expectedCode)
        ->and(json_encode($codes, JSON_THROW_ON_ERROR))->not->toContain($body);
})->with([
    'claimed revelation' => [
        str_repeat('Father guide us in patience and love today. ', 8).'God told me this will happen. Amen.',
        null,
        [],
        'prohibited_claim',
    ],
    'unselected Bible reference' => [
        str_repeat('Father guide us in patience and love today. ', 8).'Keep John 3:16 before us. Amen.',
        null,
        [],
        'unselected_scripture_reference',
    ],
    'unselected quotation' => [
        str_repeat('Father guide us in patience and love today. ', 8).'You said “a private sentence not selected here.” Amen.',
        null,
        [],
        'unselected_quotation',
    ],
    'short action' => [
        str_repeat('Father guide us in patience and love today. ', 8).'Amen.',
        'Listen.',
        [],
        'action_word_count',
    ],
    'control character' => [
        str_repeat('Father guide us in patience and love today. ', 8)."Keep us faithful.\u{0007} Amen.",
        null,
        [],
        'body_control_characters',
    ],
    'invalid UTF-8' => [
        str_repeat('Father guide us in patience and love today. ', 8)."Keep us faithful.\xC3\x28 Amen.",
        null,
        [],
        'body_utf8',
    ],
    'claimed Holy Spirit message in title' => [
        str_repeat('Father guide us in patience and love today. ', 8).'Keep us faithful. Amen.',
        null,
        [],
        'prohibited_claim',
        'The Holy Spirit is saying you will prevail',
    ],
    'claimed cause in action' => [
        str_repeat('Father guide us in patience and love today. ', 8).'Keep us faithful. Amen.',
        'God caused this illness for your growth.',
        [],
        'prohibited_claim',
    ],
    'spiritual diagnosis' => [
        str_repeat('Father guide us in patience and love today. ', 8).'You lack faith. Keep us faithful. Amen.',
        null,
        [],
        'prohibited_claim',
    ],
    'unselected Isaiah reference' => [
        str_repeat('Father guide us in patience and love today. ', 8).'Keep Isaiah 41:10 before us. Amen.',
        null,
        [],
        'unselected_scripture_reference',
    ],
]);
