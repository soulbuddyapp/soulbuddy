<?php

namespace App\Console\Commands;

use App\Domain\Scripture\DailyScripture;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Throwable;

final class ReplaceDailyScripture extends Command
{
    protected $signature = 'scriptures:replace {date} {file : UTF-8 JSON file containing one scripture}';

    protected $description = 'Replace a dated daily scripture with reviewed editorial content';

    public function handle(): int
    {
        try {
            $path = $this->argument('file');
            if (! is_file($path) || ! is_readable($path) || filesize($path) > 65536) {
                $this->error('A readable JSON file under 64 KB is required.');

                return self::FAILURE;
            }
            $content = json_decode(file_get_contents($path), true, flags: JSON_THROW_ON_ERROR);
            if (! is_array($content)) {
                $this->error('A scripture object is required.');

                return self::FAILURE;
            }
            $content['date'] = $this->argument('date');
            $validated = Validator::make($content, DailyScripture::rules())->validate();
            DB::table('daily_scripture_overrides')->updateOrInsert(
                ['date' => $validated['date']],
                ['content' => json_encode($validated, JSON_THROW_ON_ERROR), 'created_at' => now(), 'updated_at' => now()],
            );
        } catch (Throwable $error) {
            $this->error('Replacement failed: '.$error->getMessage());

            return self::FAILURE;
        }
        $this->info('Daily scripture replaced for '.$validated['date'].'.');

        return self::SUCCESS;
    }
}
