<?php

namespace App\Domain\Companions;

use Illuminate\Support\Facades\Http;
use Throwable;

class TelegramBotSender
{
    public function sendLinkConfirmed(string $chatId): bool
    {
        return $this->send(
            $chatId,
            'SoulBuddy is ready. Daily Scripture, formation, prayer, and Sacred Hour prompts are active. Send /settings for the rhythm.',
        );
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

    /** @param object{title: string, youtube_url: string, stable_id: string, channel: string, runtime_seconds: int} $video */
    public function sendFormationVideo(string $chatId, object $video): bool
    {
        return $this->send(
            $chatId,
            "Daily formation\n\n{$video->title}\n{$video->channel}",
            [
                'inline_keyboard' => [
                    [['text' => 'Watch', 'url' => $video->youtube_url]],
                    [['text' => 'I watched this', 'callback_data' => 'formation:'.$video->stable_id]],
                ],
            ],
        );
    }

    public function sendPrayerReminder(string $chatId, string $title): bool
    {
        return $this->send($chatId, "Prayer time\n\n{$title}");
    }

    public function sendSacredHour(string $chatId, string $name): bool
    {
        return $this->send(
            $chatId,
            "Sacred Hour · {$name}\n\nGod speaks to us in meditation.\nListen to know if your prayer needs something from you.",
        );
    }

    public function sendWeeklyPersonPrayer(string $chatId, string $name): bool
    {
        return $this->send($chatId, "Lift {$name} in prayer today.");
    }

    public function sendWeeklyFormationReturn(string $chatId): bool
    {
        return $this->send($chatId, 'Make time for a formation video this week.');
    }

    public function sendPreferences(string $chatId): bool
    {
        return $this->send(
            $chatId,
            "Rhythm\n\n/pause · pause all prompts\n/resume · restore all prompts\n/formation on|off\n/prayers on|off\n/sacred on|off\n/care on|off",
        );
    }

    public function answerCallbackQuery(string $callbackId, string $text): bool
    {
        return $this->request('answerCallbackQuery', [
            'callback_query_id' => $callbackId,
            'text' => $text,
        ]);
    }

    /** @param array<string, mixed>|null $replyMarkup */
    public function send(string $chatId, string $text, ?array $replyMarkup = null): bool
    {
        $payload = ['chat_id' => $chatId, 'text' => $text];
        if ($replyMarkup !== null) {
            $payload['reply_markup'] = $replyMarkup;
        }

        return $this->request('sendMessage', $payload);
    }

    /** @param array<string, mixed> $payload */
    private function request(string $method, array $payload): bool
    {
        $token = (string) config('services.telegram.bot_token');
        if ($token === '') {
            return false;
        }

        try {
            return Http::timeout(10)
                ->post("https://api.telegram.org/bot{$token}/{$method}", $payload)
                ->successful();
        } catch (Throwable) {
            return false;
        }
    }
}
