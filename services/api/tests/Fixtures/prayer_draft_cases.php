<?php

$purposes = [
    'daily', 'gratitude', 'guidance', 'family', 'healing', 'work',
    'forgiveness', 'difficult_time',
];
$topics = [
    ['status', 'Help me remain humble when my work is recognized.'],
    ['money', 'Give me wisdom to use limited money faithfully.'],
    ['healing', 'Help our household remain faithful during treatment.'],
    ['conflict', 'Guide us toward truth and peace in this disagreement.'],
    ['forgiveness', 'Help me forgive without hiding what needs repair.'],
    ['work', 'Guide my choices and service at work today.'],
    ['family', 'Keep our family patient and attentive to one another.'],
    ['disappointment', 'Meet me in disappointment and keep me faithful.'],
];
$beneficiaries = ['me', 'household_family', 'another_person', 'people_affected', 'beyond_my_sight'];
$surrenders = ['outcome', 'timing', 'way_it_happens', 'all'];
$responsibilities = ['use_wisely', 'share_or_serve', 'repair_attention', 'act_faithfully', 'time_to_discern'];
$alignments = ['no_conflict_seen', 'examine_further'];
$body = 'Father, give us wisdom as we face this moment. Keep us truthful, patient, and ready to listen. Guard us from fear, pride, and haste. Help us consider everyone affected, receive correction with humility, and act with love. We entrust the outcome, the timing, and the way forward to you. Strengthen us to do what is faithful, repair any harm, and serve one another in peace. Through uncertainty, keep our hearts near you and our steps honest. Amen.';

$cases = [];
$situationalIndex = 0;
for ($index = 0; $index < 32; $index++) {
    $style = $index % 2 === 0 ? 'daily' : 'situational';
    $choices = [
        'beneficiary' => null,
        'surrender' => null,
        'responsibility' => null,
        'alignment' => null,
    ];
    if ($style === 'situational') {
        $choices = [
            'beneficiary' => $beneficiaries[$situationalIndex % count($beneficiaries)],
            'surrender' => $surrenders[$situationalIndex % count($surrenders)],
            'responsibility' => $responsibilities[$situationalIndex % count($responsibilities)],
            'alignment' => $alignments[$situationalIndex % count($alignments)],
        ];
        $situationalIndex++;
    }

    $contexts = match ($index % 4) {
        1 => [[
            'type' => 'encounter',
            'source_id' => 'encounter-fixture',
            'display_label' => 'A remembered act of patience',
            'excerpt_snapshot' => 'We stopped, listened, and answered peacefully.',
        ]],
        2 => [[
            'type' => 'scripture',
            'source_id' => 'John-15-9-10',
            'display_label' => 'John 15:9-10',
            'excerpt_snapshot' => '9 Remain in my love. 10 Keep my commandments.',
            'translation' => 'RSVCE',
            'book' => 'John',
            'chapter' => 15,
            'first_verse' => 9,
            'last_verse' => 10,
        ]],
        3 => [[
            'type' => 'encounter',
            'source_id' => 'encounter-fixture',
            'display_label' => 'A remembered act of service',
            'excerpt_snapshot' => 'Someone quietly helped when help was needed.',
        ], [
            'type' => 'scripture',
            'source_id' => 'Matthew-5-9-9',
            'display_label' => 'Matthew 5:9',
            'excerpt_snapshot' => '9 Blessed are the peacemakers.',
            'translation' => 'RSVCE',
            'book' => 'Matthew',
            'chapter' => 5,
            'first_verse' => 9,
            'last_verse' => 9,
        ]],
        default => [],
    };
    [$topic, $request] = $topics[$index % count($topics)];
    $cases[] = [
        'name' => "case-{$index}-{$topic}",
        'topic' => $topic,
        'input' => [
            'attempt_id' => '00000000-0000-7000-8000-'.str_pad((string) $index, 12, '0', STR_PAD_LEFT),
            'style' => $style,
            'reach' => intdiv($index, 2) % 2 === 0 ? 'personal' : 'encompassing',
            'grounding' => intdiv($index, 4) % 2 === 0 ? 'general_christian' : 'catholic',
            'purpose' => $purposes[$index % count($purposes)],
            'request_text' => $request,
            'choices' => $choices,
            'contexts' => $contexts,
        ],
        'draft' => [
            'title' => 'For faithful wisdom',
            'body' => $body,
            'action' => 'Listen carefully before choosing a response.',
        ],
    ];
}

return $cases;
