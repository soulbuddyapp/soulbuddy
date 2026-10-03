<?php

namespace App\Domain\Companions;

use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class TelegramLinkService
{
    /**
     * @return array{code: string, expires_at: string, start_url: ?string}
     */
    public function issue(User $user): array
    {
        $id = (string) Str::uuid();
        $code = $this->code();
        $expiresAt = now()->addMinutes(10);

        DB::transaction(function () use ($user, $id, $code, $expiresAt): void {
            DB::table('companion_link_codes')
                ->where('user_id', $user->id)
                ->where('channel', 'telegram')
                ->whereNull('consumed_at')
                ->update(['consumed_at' => now()]);

            DB::table('companion_link_codes')->insert([
                'id' => $id,
                'user_id' => $user->id,
                'channel' => 'telegram',
                'token_hash' => hash('sha256', $code),
                'expires_at' => $expiresAt,
                'created_at' => now(),
            ]);
        });

        $username = trim((string) config('services.telegram.bot_username'));

        return [
            'code' => $code,
            'expires_at' => $expiresAt->toIso8601String(),
            'start_url' => $username === '' ? null : "https://t.me/{$username}?start={$code}",
        ];
    }

    public function consume(string $code, string $chatId, ?string $username): bool
    {
        return DB::transaction(function () use ($code, $chatId, $username): bool {
            $link = DB::table('companion_link_codes')
                ->where('token_hash', hash('sha256', $code))
                ->lockForUpdate()
                ->first();
            if ($link === null ||
                $link->channel !== 'telegram' ||
                $link->consumed_at !== null ||
                now()->greaterThan($link->expires_at)) {
                return false;
            }

            $existingChat = DB::table('telegram_connections')
                ->where('chat_id', $chatId)
                ->lockForUpdate()
                ->first();
            if ($existingChat !== null && $existingChat->user_id !== $link->user_id) {
                return false;
            }

            $existingUser = DB::table('telegram_connections')
                ->where('user_id', $link->user_id)
                ->lockForUpdate()
                ->first();
            if ($existingUser === null) {
                DB::table('telegram_connections')->insert([
                    'id' => (string) Str::uuid(),
                    'user_id' => $link->user_id,
                    'chat_id' => $chatId,
                    'username' => $username,
                    'daily_enabled' => false,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            } elseif ($existingUser->chat_id === $chatId) {
                DB::table('telegram_connections')
                    ->where('id', $existingUser->id)
                    ->update(['username' => $username, 'updated_at' => now()]);
            } else {
                DB::table('telegram_connections')
                    ->where('id', $existingUser->id)
                    ->update([
                        'chat_id' => $chatId,
                        'username' => $username,
                        'updated_at' => now(),
                    ]);
            }

            DB::table('companion_link_codes')
                ->where('id', $link->id)
                ->update(['consumed_at' => now()]);

            return true;
        }, attempts: 3);
    }

    private function code(): string
    {
        return rtrim(strtr(base64_encode(random_bytes(32)), '+/', '-_'), '=');
    }
}
