<?php

namespace App\Domain\Companions;

use Illuminate\Support\Facades\Http;
use Throwable;

class TelegramBotSender
{
    public function sendLinkConfirmed(string $chatId): bool
    {
        $token = (string) config('services.telegram.bot_token');
        if ($token === '') {
            return false;
        }

        try {
            return Http::timeout(10)
                ->post("https://api.telegram.org/bot{$token}/sendMessage", [
                    'chat_id' => $chatId,
                    'text' => 'SoulBuddy connected. Daily notes are off.',
                ])
                ->successful();
        } catch (Throwable) {
            return false;
        }
    }
}
