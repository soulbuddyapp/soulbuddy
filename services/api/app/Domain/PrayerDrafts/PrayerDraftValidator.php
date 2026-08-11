<?php

namespace App\Domain\PrayerDrafts;

final class PrayerDraftValidator
{
    private const BIBLE_REFERENCE_PATTERN = '/\b(?:(?:[1-3]\s+)?(?:Samuel|Kings|Chronicles|Maccabees|Corinthians|Thessalonians|Timothy|Peter|John)|Genesis|Exodus|Leviticus|Numbers|Deuteronomy|Joshua|Judges|Ruth|Ezra|Nehemiah|Tobit|Judith|Esther|Job|Psalms?|Proverbs|Ecclesiastes|Song of Songs|Song of Solomon|Canticle of Canticles|Wisdom|Sirach|Isaiah|Jeremiah|Lamentations|Baruch|Ezekiel|Daniel|Hosea|Joel|Amos|Obadiah|Jonah|Micah|Nahum|Habakkuk|Zephaniah|Haggai|Zechariah|Malachi|Matthew|Mark|Luke|Acts|Romans|Galatians|Ephesians|Philippians|Colossians|Titus|Philemon|Hebrews|James|Jude|Revelation)\s+\d{1,3}(?::\d{1,3}(?:-\d{1,3})?)?/iu';

    /** @return list<string> */
    public function codes(PrayerDraftResult $draft, PrayerDraftInput $input): array
    {
        $codes = [];
        $this->validateText($draft->title, 'title', 1, 120, $codes);
        $this->validateText($draft->body, 'body', 1, 10000, $codes);

        $bodyIsUtf8 = mb_check_encoding($draft->body, 'UTF-8');
        if ($bodyIsUtf8) {
            $bodyWords = $this->wordCount($draft->body);
            if ($bodyWords < 60 || $bodyWords > 140) {
                $codes[] = 'body_word_count';
            }
        }
        if ($draft->action !== null) {
            $this->validateText($draft->action, 'action', 1, 500, $codes);
            if (mb_check_encoding($draft->action, 'UTF-8')) {
                $actionWords = $this->wordCount($draft->action);
                if ($actionWords < 3 || $actionWords > 18) {
                    $codes[] = 'action_word_count';
                }
            }
        }

        $texts = [$draft->title, $draft->body, $draft->action];
        $prohibited = [
            '/\b(?:God|the Lord|the Holy Spirit) (?:told|showed|revealed) (?:me|us|you)\b/iu',
            '/\b(?:God|the Lord|the Holy Spirit) (?:says|is saying) (?:that\s+)?(?:I|we|you)\b/iu',
            '/\b(?:God|the Lord) (?:promises|guarantees) (?:me|us|you)\b/iu',
            '/\b(?:God|the Lord) will (?:certainly|definitely|surely)\b/iu',
            '/\b(?:God|the Lord) (?:caused|sent|gave you) (?:this|that|the|your)\b/iu',
            '/\bthis (?:will|is guaranteed to) happen\b/iu',
            '/\bthus says the Lord\b/iu',
            '/\byou (?:lack faith|are spiritually (?:immature|dead|weak)|are being punished)\b/iu',
            '/\byour (?:faith|motive|spiritual state) is (?:weak|selfish|sinful|immature|impure)\b/iu',
            '/\bthis happened because of (?:your|their) (?:sin|lack of faith)\b/iu',
        ];
        foreach ($prohibited as $pattern) {
            if ($this->anyMatch($texts, $pattern)) {
                $codes[] = 'prohibited_claim';
                break;
            }
        }

        if (! $input->hasScriptureContext() && $this->anyMatch($texts, self::BIBLE_REFERENCE_PATTERN)) {
            $codes[] = 'unselected_scripture_reference';
        }
        foreach ($texts as $text) {
            if ($text !== null
                && mb_check_encoding($text, 'UTF-8')
                && preg_match_all('/[“"]([^”"]{8,})[”"]/u', $text, $matches) > 0) {
                $selectedText = implode("\n", array_column($input->contexts, 'excerpt_snapshot'));
                foreach ($matches[1] as $quote) {
                    if (! str_contains($selectedText, $quote)) {
                        $codes[] = 'unselected_quotation';
                        break;
                    }
                }
            }
        }

        return array_values(array_unique($codes));
    }

    /** @param list<string> $codes */
    private function validateText(string $value, string $field, int $minimum, int $maximum, array &$codes): void
    {
        if (! mb_check_encoding($value, 'UTF-8')) {
            $codes[] = $field.'_utf8';

            return;
        }
        $length = mb_strlen($value);
        if ($length < $minimum || $length > $maximum) {
            $codes[] = $field.'_length';
        }
        if (preg_match('/[\p{Cc}\p{Cf}]/u', $value) === 1) {
            $codes[] = $field.'_control_characters';
        }
    }

    private function wordCount(string $value): int
    {
        preg_match_all('/[\p{L}\p{N}]+(?:[’\'-][\p{L}\p{N}]+)*/u', $value, $matches);

        return count($matches[0]);
    }

    /** @param list<?string> $values */
    private function anyMatch(array $values, string $pattern): bool
    {
        foreach ($values as $value) {
            if ($value !== null
                && mb_check_encoding($value, 'UTF-8')
                && preg_match($pattern, $value) === 1) {
                return true;
            }
        }

        return false;
    }
}
