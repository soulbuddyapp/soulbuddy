<?php

namespace App\Console\Commands;

use App\Domain\Companions\TelegramCompanionService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;
use Throwable;

class SendTelegramCompanionNotifications extends Command
{
    protected $signature = 'telegram-companion:send';

    protected $description = 'Send due Telegram companion prompts';

    public function handle(TelegramCompanionService $companion): int
    {
        try {
            $result = $companion->sendDue();
        } catch (Throwable $exception) {
            Log::warning('Telegram companion delivery run failed.', [
                'exception_type' => $exception::class,
            ]);
            $this->components->error('Telegram companion delivery failed.');

            return self::FAILURE;
        }

        $this->components->info("Telegram companion: {$result['sent']} sent, {$result['failed']} failed.");

        return $result['failed'] === 0 ? self::SUCCESS : self::FAILURE;
    }
}
