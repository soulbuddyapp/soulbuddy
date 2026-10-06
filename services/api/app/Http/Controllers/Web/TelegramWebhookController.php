<?php

namespace App\Http\Controllers\Web;

use App\Domain\Companions\TelegramBotSender;
use App\Domain\Companions\TelegramCompanionService;
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
        TelegramCompanionService $companion,
    ): JsonResponse {
        $expected = (string) config('services.telegram.webhook_secret');
        $received = (string) $request->header('X-Telegram-Bot-Api-Secret-Token');
        if ($expected === '' || ! hash_equals($expected, $received)) {
            abort(403);
        }

        $callback = $request->input('callback_query');
        if (is_array($callback)) {
            return $this->callbackResponse($callback, $sender, $companion);
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
        if ($text === '/settings') {
            return response()->json([
                'delivered' => $companion->isConnected($chatId)
                    && $sender->sendPreferences($chatId),
            ]);
        }
        if ($text === '/pause' || $text === '/resume') {
            $enabled = $text === '/resume';

            $updated = $companion->setPreference($chatId, 'all', $enabled);

            return response()->json([
                'updated' => $updated,
                'delivered' => $updated && $sender->send(
                    $chatId,
                    $enabled ? 'Daily prompts are active.' : 'Daily prompts are paused.',
                ),
            ]);
        }
        if (is_string($text)
            && preg_match('/^\\/(formation|prayers|sacred|care)\\s+(on|off)$/', trim($text), $preferences)) {
            $enabled = $preferences[2] === 'on';

            $updated = $companion->setPreference($chatId, $preferences[1], $enabled);

            return response()->json([
                'updated' => $updated,
                'delivered' => $updated && $sender->send(
                    $chatId,
                    ucfirst($preferences[1]).($enabled ? ' prompts are active.' : ' prompts are paused.'),
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

    private function callbackResponse(
        array $callback,
        TelegramBotSender $sender,
        TelegramCompanionService $companion,
    ): JsonResponse {
        $message = $callback['message'] ?? null;
        $callbackId = $callback['id'] ?? null;
        $data = $callback['data'] ?? null;
        if (! is_array($message)
            || ! is_array($message['chat'] ?? null)
            || ($message['chat']['type'] ?? null) !== 'private'
            || ! is_string($callbackId)
            || ! is_string($data)
            || ! is_int($message['chat']['id'] ?? null) && ! is_string($message['chat']['id'] ?? null)) {
            return response()->json(['recorded' => false]);
        }
        if (! preg_match('/^formation:([A-Za-z0-9_-]{1,120})$/', $data, $matches)) {
            return response()->json(['recorded' => false]);
        }
        $recorded = $companion->recordTelegramFormationActivity((string) $message['chat']['id'], $matches[1]);
        $sender->answerCallbackQuery($callbackId, $recorded ? 'Formation recorded.' : 'Connect SoulBuddy first.');

        return response()->json(['recorded' => $recorded]);
    }
}
