<?php

namespace App\Domain\PrayerReleases;

use JsonException;
use Ramsey\Uuid\Uuid;

/**
 * The checked-in release artifact, decoded and validated before anything is
 * seeded or served. Source wording is never edited here: an artifact that does
 * not match its own checksums or repetition profile is refused outright.
 */
final class ReleaseContent
{
    public const SCHEMA_VERSION = 1;

    public const KIND_PRAYER = 'prayer';

    public const KIND_MEDITATION_PRAYER = 'meditation_prayer';

    /** @var list<string> */
    public const KINDS = [self::KIND_PRAYER, self::KIND_MEDITATION_PRAYER];

    /** Internal practice name; the customer-facing experience is a Prayer of attention. */
    public const PRACTICE_MODE_AFFIRMATION_REPETITION = 'affirmation_repetition';

    /** Fixed namespace so release, item, and canonical prayer ids stay stable across deployments. */
    public const ID_NAMESPACE = '0b3f5f1e-2a4d-5c6b-8e9f-1a2b3c4d5e6f';

    private const DOCUMENT_KEYS = [
        'schema_version', 'slug', 'title', 'discovery_label', 'discovery_detail',
        'preparation_text', 'items',
    ];

    private const ITEM_KEYS = [
        'sort_order', 'kind', 'purpose', 'grounding', 'language_style', 'action',
        'title', 'body', 'content_sha256', 'practice',
    ];

    private const STEP_KEYS = ['phrase', 'target_count', 'source_line'];

    /** Memorare has no supplied source body, so no release may carry it yet. */
    private const UNSUPPLIED_CONTENT = 'Memorare';

    /** @param  list<ReleaseItem>  $items */
    private function __construct(
        public readonly string $slug,
        public readonly string $title,
        public readonly string $discoveryLabel,
        public readonly string $discoveryDetail,
        public readonly string $preparationText,
        public readonly array $items,
    ) {}

    public static function fromJsonFile(string $path): self
    {
        $raw = is_readable($path) ? file_get_contents($path) : false;
        if ($raw === false) {
            throw new InvalidReleaseContent("Prayer release artifact could not be read at {$path}.");
        }

        try {
            $decoded = json_decode($raw, true, flags: JSON_THROW_ON_ERROR);
        } catch (JsonException $exception) {
            throw new InvalidReleaseContent('Prayer release artifact is not valid JSON: '.$exception->getMessage());
        }

        if (! is_array($decoded) || array_is_list($decoded)) {
            throw new InvalidReleaseContent('Prayer release artifact must be a JSON object.');
        }

        return self::fromArray($decoded);
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public static function fromArray(array $data): self
    {
        if (array_diff(array_keys($data), self::DOCUMENT_KEYS) !== []) {
            throw new InvalidReleaseContent('Prayer release document carries unknown fields.');
        }

        $schemaVersion = $data['schema_version'] ?? null;
        if ($schemaVersion !== self::SCHEMA_VERSION) {
            throw new InvalidReleaseContent('Unsupported prayer release schema_version: '.var_export($schemaVersion, true).'.');
        }

        $slug = self::requireText($data, 'slug');
        if (preg_match('/^[a-z0-9]+(?:-[a-z0-9]+)*$/', $slug) !== 1) {
            throw new InvalidReleaseContent("Prayer release slug is not a stable identifier: {$slug}.");
        }

        $title = self::requireText($data, 'title');
        self::guardUnsuppliedContent($title, 'title');

        $items = $data['items'] ?? null;
        if (! is_array($items) || ! array_is_list($items) || $items === []) {
            throw new InvalidReleaseContent('Prayer release items must be a non-empty ordered list.');
        }

        $releaseItems = [];
        $positions = [];
        foreach ($items as $index => $item) {
            if (! is_array($item) || array_is_list($item)) {
                throw new InvalidReleaseContent("Prayer release item {$index} must be a JSON object.");
            }
            $releaseItems[] = self::releaseItem($item, $index);
            $positions[] = $releaseItems[$index]->sortOrder;
        }

        if ($positions !== range(0, count($positions) - 1)) {
            throw new InvalidReleaseContent('Prayer release item sort_order values must be unique and contiguous from zero.');
        }

        return new self(
            $slug,
            $title,
            self::requireText($data, 'discovery_label'),
            self::requireText($data, 'discovery_detail'),
            self::requireText($data, 'preparation_text'),
            $releaseItems,
        );
    }

    /**
     * The one hash narration generation and every test must agree on.
     */
    public static function contentHash(string $title, string $body): string
    {
        return hash('sha256', $title."\n".$body);
    }

    public function releaseId(): string
    {
        return Uuid::uuid5(self::ID_NAMESPACE, 'prayer-release:'.$this->slug)->toString();
    }

    public function itemId(int $sortOrder): string
    {
        return Uuid::uuid5(self::ID_NAMESPACE, "prayer-release-item:{$this->slug}:{$sortOrder}")->toString();
    }

    public function libraryPrayerId(int $sortOrder): string
    {
        return Uuid::uuid5(self::ID_NAMESPACE, "library-prayer:{$this->slug}:{$sortOrder}")->toString();
    }

    /**
     * @param  array<string, mixed>  $item
     */
    private static function releaseItem(array $item, int $index): ReleaseItem
    {
        if (array_diff(array_keys($item), self::ITEM_KEYS) !== []) {
            throw new InvalidReleaseContent("Prayer release item {$index} carries unknown fields.");
        }

        $sortOrder = $item['sort_order'] ?? null;
        if (! is_int($sortOrder)) {
            throw new InvalidReleaseContent("Prayer release item {$index} requires an integer sort_order.");
        }

        $kind = $item['kind'] ?? null;
        if (! is_string($kind) || ! in_array($kind, self::KINDS, true)) {
            throw new InvalidReleaseContent("Prayer release item {$index} has an unsupported kind: ".var_export($kind, true).'.');
        }

        $itemTitle = self::requireText($item, 'title');
        $body = self::requireText($item, 'body');
        self::guardUnsuppliedContent($itemTitle, "item {$index} title");
        self::guardUnsuppliedContent($body, "item {$index} body");

        $purpose = $item['purpose'] ?? null;
        if (! is_string($purpose) || $purpose === '') {
            throw new InvalidReleaseContent("Prayer release item {$index} requires a purpose.");
        }

        $grounding = $item['grounding'] ?? null;
        if (! is_string($grounding) || $grounding === '') {
            throw new InvalidReleaseContent("Prayer release item {$index} requires a grounding.");
        }

        $languageStyle = $item['language_style'] ?? null;
        if (! is_string($languageStyle) || $languageStyle === '') {
            throw new InvalidReleaseContent("Prayer release item {$index} requires a language_style.");
        }

        $action = $item['action'] ?? null;
        if ($action !== null && (! is_string($action) || trim($action) === '')) {
            throw new InvalidReleaseContent("Prayer release item {$index} carries an empty action prompt.");
        }

        $declaredHash = $item['content_sha256'] ?? null;
        if (! is_string($declaredHash) || preg_match('/^[a-f0-9]{64}$/', $declaredHash) !== 1) {
            throw new InvalidReleaseContent("Prayer release item {$index} requires a lowercase SHA-256 content_sha256.");
        }
        if (! hash_equals(self::contentHash($itemTitle, $body), $declaredHash)) {
            throw new InvalidReleaseContent(
                "Prayer release item {$index} content_sha256 does not match its UTF-8 title and body."
            );
        }

        return new ReleaseItem(
            $sortOrder,
            $kind,
            $purpose,
            $grounding,
            $languageStyle,
            $action,
            $itemTitle,
            $body,
            self::practice($item['practice'] ?? null, $kind, $index, $body),
        );
    }

    private static function practice(mixed $practice, string $kind, int $index, string $body): ?RepetitionPractice
    {
        if ($practice === null) {
            return null;
        }

        if (! is_array($practice) || array_is_list($practice)) {
            throw new InvalidReleaseContent("Prayer release item {$index} practice must be a JSON object.");
        }
        if (array_diff(array_keys($practice), ['mode', 'steps']) !== []) {
            throw new InvalidReleaseContent("Prayer release item {$index} practice carries unknown fields.");
        }
        if (($practice['mode'] ?? null) !== self::PRACTICE_MODE_AFFIRMATION_REPETITION) {
            throw new InvalidReleaseContent(
                "Prayer release item {$index} practice mode is not ".self::PRACTICE_MODE_AFFIRMATION_REPETITION.'.'
            );
        }
        if ($kind !== self::KIND_MEDITATION_PRAYER) {
            throw new InvalidReleaseContent("Prayer release item {$index} may only carry a practice as a meditation prayer.");
        }

        $rows = $practice['steps'] ?? null;
        if (! is_array($rows) || ! array_is_list($rows) || $rows === []) {
            throw new InvalidReleaseContent("Prayer release item {$index} practice requires an ordered step list.");
        }

        $steps = [];
        foreach ($rows as $position => $row) {
            if (! is_array($row) || array_is_list($row) || array_diff(array_keys($row), self::STEP_KEYS) !== []) {
                throw new InvalidReleaseContent("Prayer release item {$index} practice step {$position} is malformed.");
            }

            $phrase = $row['phrase'] ?? null;
            $targetCount = $row['target_count'] ?? null;
            $sourceLine = $row['source_line'] ?? null;
            if (! is_string($phrase) || trim($phrase) === '' || ! mb_check_encoding($phrase, 'UTF-8')) {
                throw new InvalidReleaseContent("Prayer release item {$index} practice step {$position} requires a phrase.");
            }
            if (! is_int($targetCount) || $targetCount < 1) {
                throw new InvalidReleaseContent("Prayer release item {$index} practice step {$position} requires a positive target_count.");
            }
            if (! is_string($sourceLine) || $sourceLine === '') {
                throw new InvalidReleaseContent("Prayer release item {$index} practice step {$position} requires a source_line.");
            }
            if (! hash_equals(RepetitionStep::sourceLineFor($phrase, $targetCount), $sourceLine)) {
                throw new InvalidReleaseContent(
                    "Prayer release item {$index} practice step {$position} source_line does not rebuild from its phrase and target_count."
                );
            }

            $steps[] = new RepetitionStep($phrase, $targetCount, $sourceLine);
        }

        $repetition = new RepetitionPractice(self::PRACTICE_MODE_AFFIRMATION_REPETITION, $steps);
        if (! hash_equals($body, $repetition->sourceBody())) {
            throw new InvalidReleaseContent(
                "Prayer release item {$index} practice source_line values do not rebuild its body."
            );
        }

        return $repetition;
    }

    /**
     * @param  array<string, mixed>  $data
     */
    private static function requireText(array $data, string $key): string
    {
        $value = $data[$key] ?? null;
        if (! is_string($value) || trim($value) === '') {
            throw new InvalidReleaseContent("Prayer release requires a non-empty {$key}.");
        }
        if (! mb_check_encoding($value, 'UTF-8')) {
            throw new InvalidReleaseContent("Prayer release {$key} is not valid UTF-8.");
        }

        return $value;
    }

    private static function guardUnsuppliedContent(string $value, string $field): void
    {
        if (stripos($value, self::UNSUPPLIED_CONTENT) !== false) {
            throw new InvalidReleaseContent(
                self::UNSUPPLIED_CONTENT.' has no supplied source wording and must stay out of every release.'
            );
        }
    }
}
