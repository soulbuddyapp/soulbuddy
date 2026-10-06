<?php

use App\Domain\PrayerReleases\InvalidReleaseContent;
use App\Domain\PrayerReleases\ReleaseContent;
use Ramsey\Uuid\Uuid;

const RELEASE_SLUG = 'renewed-mind-and-guarded-heart-v1';

const EXPECTED_PREPARATION = <<<'TEXT'
Before you Pray - Preparation for a graceful prayer
Begin with the sign of the cross. Before petitioning God, clear your mind of all inclinations, occasions or taint of sin. Check if you have any subconscious desires of occasions of sin -  seeds sown through what you saw, what you said, what you touched, or an unlawful desire already planted in your heart; if you have such, determine now that God help you get rid of it; and decide how many times you should say the prayers during your day to stay on guard. Don’t pray carelessly, kneel or stand or vocalize to mean what you say, whatever works best for you.
TEXT;

const EXPECTED_FIRST_PRAYER = <<<'TEXT'
+
Jesus humbled himself unto death, even death on a Cross
May I not regress in my transformation journey to be as Christ

I acknowledge that no good intention comes from my flesh, and it is the Spirit in me that speaks good for my soul. And it’s the spirit of sonship of the same Great and Mighty God; the child spirit of the Alpha and the Omega, the Beginning and the End, the Elohim, the ElShaddai, the King of Kings and the Lord of Lords. The same God who humbled himself and took human form for my sake.

Through the grace and mercy of God, may my mind be healed and my soul sanctified. Heal my mind dear Lord and restore and renew my spiritual vitality today: a heart awake to Your presence, a will ready to obey, and attention available for Your love and to Love.

I reject all thoughts that distract me from Your presence and any selfish desires that objectify others or myself. I reject all selfish attitudes and pleasure that obstruct your presence and perfect will in my life. Let the strength recovered from wasteful wrongdoing become patience, honest work, prayer and generosity. May your goodness and love flow in me and through me without restraint. Help me to guard my mind this day with discipline and to remember that your presence is greater than any other treasure. Protect me from the lures of the world and its devices. Create in me a pure heart and renew a right spirit within me. May your Spirit dear Lord make me whole. Amen.
TEXT;

const EXPECTED_MEDITATION = <<<'TEXT'
The Holy Spirit is our greatest gift for transformation. Listen silently in your heart now for good inspirations for your day (not of ego, but of true humble service).

Dear Holy Spirit, help me heed inspirations of discipline or warnings and bear fruits in the good inspirations you have given or will give me today. Amen.
TEXT;

const EXPECTED_THIRD_PRAYER = <<<'TEXT'
+
I hereby give myself to God and immerse my will in God’s will, that my purpose may be illuminated; that my will may be fully aligned with God’s will; and that my mind may be sanctified in the perfect will of God.
May God free and shield me from all distractions that hold me back from growing in my mission/assignment in this world. Amen
TEXT;

const EXPECTED_REPETITIONS = <<<'TEXT'
Dear Lord, renew my mind and heart and make me a new Adam in Christ Jesus (x50)
In moments that distract me from your perfect will, let Satan be rebuked o Lord (x10)
TEXT;

const EXPECTED_FIFTH_PRAYER = <<<'TEXT'
Heavenly Father, Your Word says that out of the abundance of the heart, the mouth speaks. Purify the heart from which my words and actions flow. Remove bitterness, pride, laziness, lust and all forms of licentiousness from my life. Fill me deeply with your Love, that I may truly be a light wherever I go. Sanctify my mind that I may recognize your daily presence in thanksgiving. Grant me your passion so that I may have great strength and courage to carry out Your will. Give me your peace and serenity that I may stand resolute in temptations/trials. I renounce all works of evil today. In moments of distraction or boredom, fill me with your Word. Where I have sinned, lead me to repentance, confession and healing. Do not let shame lead me to excuses or keep me from abiding in You.

Jesus my Redeemer, order my steps in your words.
May all my steps, words and works today, be to the glory of Your name.

Amen.
TEXT;

function releaseArtifactPath(): string
{
    return dirname(__DIR__, 3).'/resources/prayer-releases/'.RELEASE_SLUG.'.json';
}

function loadedRelease(): ReleaseContent
{
    return ReleaseContent::fromJsonFile(releaseArtifactPath());
}

it('keeps the release as five ordered entries', function () {
    $release = loadedRelease();

    expect($release->slug)->toBe(RELEASE_SLUG)
        ->and($release->title)->toBe('Renewed mind & guarded heart')
        ->and($release->discoveryLabel)->toBe('This week’s prayer')
        ->and($release->discoveryDetail)->toBe(
            'Prayer and meditation for purity, discipline, and a renewed mind.',
        )
        ->and($release->items)->toHaveCount(5)
        ->and(array_map(
            fn ($item): array => [$item->sortOrder, $item->kind, $item->title],
            $release->items,
        ))->toBe([
            [0, 'prayer', 'Daily Prayer Against Temptations'],
            [1, 'meditation_prayer', 'Brief Meditation'],
            [2, 'prayer', 'Affirmative Prayer to resist occasions of Sin'],
            [3, 'meditation_prayer', 'New Adam repetitions'],
            [4, 'prayer', 'Daily Prayer to join our hearts to the heart of Jesus'],
        ])
        ->and(array_map(fn ($item): string => $item->kind, $release->items))->toBe([
            'prayer',
            'meditation_prayer',
            'prayer',
            'meditation_prayer',
            'prayer',
        ]);
});

it('preserves every supplied source character', function () {
    $release = loadedRelease();

    expect($release->preparationText)->toBe(EXPECTED_PREPARATION)
        ->and($release->items[0]->body)->toBe(EXPECTED_FIRST_PRAYER)
        ->and($release->items[1]->body)->toBe(EXPECTED_MEDITATION)
        ->and($release->items[2]->body)->toBe(EXPECTED_THIRD_PRAYER)
        ->and($release->items[3]->body)->toBe(EXPECTED_REPETITIONS)
        ->and($release->items[4]->body)->toBe(EXPECTED_FIFTH_PRAYER)
        ->and($release->items[0]->body)->toStartWith("+\n")
        ->and($release->items[2]->body)->toStartWith("+\n");
});

it('preserves the punctuation and spacing the source relies on', function () {
    $release = loadedRelease();
    $preparation = $release->preparationText;

    expect($preparation)->toContain('sin -  seeds')
        ->and($preparation)->toContain('Don’t pray carelessly')
        ->and($release->items[0]->body)->toContain('And it’s the spirit of sonship')
        ->and($release->items[2]->body)->toContain('my mission/assignment in this world.')
        ->and($release->items[3]->body)->toContain('rebuked o Lord (x10)')
        ->and(substr_count($preparation, '  '))->toBe(1);
});

it('keeps the repetition item as two structured steps that rebuild the source lines', function () {
    $release = loadedRelease();
    $item = $release->items[3];

    expect($item->practice?->mode)->toBe(ReleaseContent::PRACTICE_MODE_AFFIRMATION_REPETITION)
        ->and($item->practice?->steps)->toHaveCount(2)
        ->and(array_map(
            fn ($step): array => [$step->phrase, $step->targetCount, $step->sourceLine],
            $item->practice->steps,
        ))->toBe([
            [
                'Dear Lord, renew my mind and heart and make me a new Adam in Christ Jesus',
                50,
                'Dear Lord, renew my mind and heart and make me a new Adam in Christ Jesus (x50)',
            ],
            [
                'In moments that distract me from your perfect will, let Satan be rebuked o Lord',
                10,
                'In moments that distract me from your perfect will, let Satan be rebuked o Lord (x10)',
            ],
        ])
        ->and(implode("\n", array_map(
            fn ($step): string => $step->phrase.' (x'.$step->targetCount.')',
            $item->practice->steps,
        )))->toBe(EXPECTED_REPETITIONS)
        ->and($release->items[0]->practice)->toBeNull()
        ->and($release->items[1]->practice)->toBeNull()
        ->and($release->items[2]->practice)->toBeNull()
        ->and($release->items[4]->practice)->toBeNull();
});

it('leaves the item action prompts empty and keeps the released tags', function () {
    $release = loadedRelease();

    foreach ($release->items as $item) {
        expect($item->action)->toBeNull();
    }

    expect(array_map(fn ($item): string => $item->purpose, $release->items))->toBe([
        'daily',
        'guidance',
        'daily',
        'guidance',
        'daily',
    ]);

    foreach ($release->items as $item) {
        expect($item->grounding)->toBe('general_christian')
            ->and($item->languageStyle)->toBe('christian');
    }
});

it('does not carry the memorare until its source wording exists', function () {
    $artifact = (string) file_get_contents(releaseArtifactPath());

    expect(stripos($artifact, 'memorare'))->toBeFalse();
});

it('binds every item to the approved content hash', function () {
    $release = loadedRelease();
    $artifact = json_decode((string) file_get_contents(releaseArtifactPath()), true, flags: JSON_THROW_ON_ERROR);

    foreach ($release->items as $item) {
        expect(hash('sha256', $item->title."\n".$item->body))
            ->toBe(ReleaseContent::contentHash($item->title, $item->body));
    }

    expect(array_map(
        fn (array $row): string => $row['content_sha256'],
        $artifact['items'],
    ))->toBe(array_map(
        fn ($item): string => hash('sha256', $item->title."\n".$item->body),
        $release->items,
    ));
});

it('rejects a one character source change that leaves a stale checksum', function () {
    $artifact = json_decode((string) file_get_contents(releaseArtifactPath()), true, flags: JSON_THROW_ON_ERROR);
    $artifact['items'][0]['body'] = str_replace('Amen.', 'Amen!', $artifact['items'][0]['body']);

    expect(static fn () => ReleaseContent::fromArray($artifact))
        ->toThrow(InvalidReleaseContent::class, 'content_sha256');
});

it('rejects a repetition profile that cannot rebuild its source line', function () {
    $artifact = json_decode((string) file_get_contents(releaseArtifactPath()), true, flags: JSON_THROW_ON_ERROR);
    $artifact['items'][3]['practice']['steps'][0]['target_count'] = 40;
    $artifact['items'][3]['content_sha256'] = hash(
        'sha256',
        $artifact['items'][3]['title']."\n".$artifact['items'][3]['body'],
    );

    expect(static fn () => ReleaseContent::fromArray($artifact))
        ->toThrow(InvalidReleaseContent::class, 'source_line');
});

it('rejects memorare while its source wording is still unsupplied', function () {
    $artifact = json_decode((string) file_get_contents(releaseArtifactPath()), true, flags: JSON_THROW_ON_ERROR);
    $artifact['items'][] = [
        'sort_order' => 5,
        'kind' => 'prayer',
        'purpose' => 'daily',
        'grounding' => 'general_christian',
        'language_style' => 'christian',
        'action' => null,
        'title' => 'Memorare',
        'body' => 'placeholder',
        'content_sha256' => hash('sha256', "Memorare\nplaceholder"),
        'practice' => null,
    ];

    expect(static fn () => ReleaseContent::fromArray($artifact))
        ->toThrow(InvalidReleaseContent::class, 'Memorare');
});

it('rejects duplicate release positions and unknown item kinds', function () {
    $artifact = json_decode((string) file_get_contents(releaseArtifactPath()), true, flags: JSON_THROW_ON_ERROR);
    $artifact['items'][1]['sort_order'] = 0;

    expect(static fn () => ReleaseContent::fromArray($artifact))
        ->toThrow(InvalidReleaseContent::class, 'sort_order');

    $artifact = json_decode((string) file_get_contents(releaseArtifactPath()), true, flags: JSON_THROW_ON_ERROR);
    $artifact['items'][0]['kind'] = 'hymn';

    expect(static fn () => ReleaseContent::fromArray($artifact))
        ->toThrow(InvalidReleaseContent::class, 'kind');
});

it('rejects a missing required field before a release can be seeded', function () {
    $artifact = json_decode((string) file_get_contents(releaseArtifactPath()), true, flags: JSON_THROW_ON_ERROR);
    unset($artifact['preparation_text']);

    expect(static fn () => ReleaseContent::fromArray($artifact))
        ->toThrow(InvalidReleaseContent::class, 'preparation_text');

    $artifact = json_decode((string) file_get_contents(releaseArtifactPath()), true, flags: JSON_THROW_ON_ERROR);
    $artifact['slug'] = 'Renewed Mind';

    expect(static fn () => ReleaseContent::fromArray($artifact))
        ->toThrow(InvalidReleaseContent::class, 'slug');
});

it('derives stable identifiers for the release, its items, and their canonical prayers', function () {
    $release = loadedRelease();
    $first = loadedRelease();

    expect($release->releaseId())->toBe($first->releaseId())
        ->and($release->itemId(3))->toBe($first->itemId(3))
        ->and($release->libraryPrayerId(3))->toBe($first->libraryPrayerId(3))
        ->and($release->releaseId())->not->toBe($release->libraryPrayerId(0))
        ->and($release->itemId(0))->not->toBe($release->itemId(1))
        ->and(Uuid::isValid($release->releaseId()))->toBeTrue()
        ->and(Uuid::isValid($release->libraryPrayerId(4)))->toBeTrue();
});
