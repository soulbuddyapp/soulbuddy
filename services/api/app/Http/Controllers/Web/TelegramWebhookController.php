<?php

namespace App\Http\Controllers\Web;

use App\Domain\Companions\TelegramBotSender;
use App\Domain\Companions\TelegramLinkService;
use App\Domain\Scripture\DailyScripture;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TelegramWebhookController extends Controller
{
    public function __invoke(
        Request $request,
        TelegramLinkService $links,
        TelegramBotSender $sender,
        DailyScripture $scriptures,
    ): JsonResponse {
        $expected = (string) config('services.telegram.webhook_secret');
        $received = (string) $request->header('X-Telegram-Bot-Api-Secret-Token');
        if ($expected === '' || ! hash_equals($expected, $received)) {
            abort(403);
        }

        $message = $request->input('message');
        if (! is_array($message) ||
            ! is_array($message['chat'] ?? null) ||
            ($message['chat']['type'] ?? null) !== 'private' ||
            ! is_int($message['chat']['id'] ?? null) && ! is_string($message['chat']['id'] ?? null)) {
            return response()->json(['linked' => false]);
        }
        $text = $message['text'] ?? null;
        $chatId = (string) $message['chat']['id'];
        if ($text === '/today') {
            $connected = \DB::table('telegram_connections')
                ->where('chat_id', $chatId)
                ->exists();

            return response()->json([
                'delivered' => $connected && $sender->sendDailyScripture(
                    $chatId,
                    $scriptures->forDate(now()->toDateString()),
                ),
            ]);
        }
        if (! is_string($text) || ! preg_match('/^\\/start\\s+([A-Za-z0-9_-]{32,64})$/', trim($text), $matches)) {
            return response()->json(['linked' => false]);
        }

        $from = $message['from'] ?? [];
        $username = is_array($from) && is_string($from['username'] ?? null)
            ? $from['username']
            : null;

        $linked = $links->consume($matches[1], $chatId, $username);

        return response()->json([
            'linked' => $linked,
            'acknowledged' => $linked && $sender->sendLinkConfirmed($chatId),
        ]);
    }
}
