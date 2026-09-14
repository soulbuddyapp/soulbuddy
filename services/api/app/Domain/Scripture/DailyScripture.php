<?php

namespace App\Domain\Scripture;

use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

final class DailyScripture
{
    public function forDate(string $date): array
    {
        $override = DB::table('daily_scripture_overrides')->where('date', $date)->value('content');
        if ($override !== null) {
            return array_replace(json_decode($override, true, flags: JSON_THROW_ON_ERROR), ['date' => $date]);
        }

        $catalog = json_decode(file_get_contents(resource_path('scripture/daily_scriptures.json')), true, flags: JSON_THROW_ON_ERROR);
        $day = CarbonImmutable::parse($date, 'UTC')->getTimestamp() / 86400;
        $index = (((int) $day % count($catalog)) + count($catalog)) % count($catalog);

        return array_replace($catalog[$index], ['date' => $date]);
    }

    public static function rules(): array
    {
        return [
            'date' => ['required', 'date_format:Y-m-d'],
            'id' => ['required', 'string', 'max:100'],
            'reference' => ['required', 'string', 'max:150'],
            'text' => ['required', 'string', 'max:12000'],
            'translation' => ['required', 'string', 'max:50'],
            'book' => ['required', 'string', 'max:80'],
            'chapter' => ['required', 'integer', 'min:1', 'max:150'],
            'first_verse' => ['required', 'integer', 'min:1', 'max:176'],
            'last_verse' => ['required', 'integer', 'gte:first_verse', 'max:176'],
            'theme' => ['required', 'string', 'max:150'],
            'reflection' => ['required', 'string', 'max:2000'],
            'prayer' => ['required', 'string', 'max:2000'],
            'practice' => ['required', 'string', 'max:500'],
            'precept' => ['required', 'in:guard-the-gate,strength-for-today'],
        ];
    }
}
