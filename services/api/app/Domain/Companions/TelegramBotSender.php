<?php

namespace App\Domain\Companions;

use Illuminate\Support\Facades\Http;
use Throwable;

class TelegramBotSender
{
    public function sendLinkConfirmed(string $chatId): bool
    {
        return $this->send($chatId, 'SoulBuddy connected. Daily notes are off.');
    }

    /**
     * @param  array{reference: string, text: string, practice: string}  $scripture
     */
    public function sendDailyScripture(string $chatId, array $scripture): bool
    {
        return $this->send(
            $chatId,
            $scripture['reference']."\n\n".$scripture['text']."\n\nPractice: ".$scripture['practice'],
        );
    }

    private function send(string $chatId, string $text): bool
    {
        $token = (string) config('services.telegram.bot_token');
        if ($token === '') {
            return false;
        }

        try {
            return Http::timeout(10)
                ->post("https://api.telegram.org/bot{$token}/sendMessage", [
                    'chat_id' => $chatId,
                    'text' => $text,
                ])
                ->successful();
        } catch (Throwable) {
            return false;
        }
    }
}
