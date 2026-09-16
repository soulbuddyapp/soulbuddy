<?php

namespace App\Console\Commands;

use App\Domain\Formation\FormationCatalog;
use Illuminate\Console\Command;
use Throwable;

final class PublishFormationCatalog extends Command
{
    protected $signature = 'formation:publish {file : Validated formation catalog JSON}';

    protected $description = 'Publish a reviewed daily formation catalog';

    public function handle(FormationCatalog $catalog): int
    {
        try {
            $summary = $catalog->publish($this->argument('file'));
        } catch (Throwable $exception) {
            $this->error('Formation catalog publication failed: '.$exception->getMessage());

            return self::FAILURE;
        }

        $this->info("Published formation catalog v{$summary['version']} with {$summary['videos']} videos, {$summary['packs']} packs, and {$summary['days']} days.");

        return self::SUCCESS;
    }
}
