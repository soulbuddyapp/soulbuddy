<?php

namespace App\Domain\Notifications;

use Firebase\JWT\JWT;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class FirebasePushSender
{
    public function sendMorning(string $deviceToken): bool
    {
        $project = (string) config('services.firebase.project_id');
        if ($project === '') {
            throw new RuntimeException('Firebase project is not configured.');
        }

        $response = Http::withToken($this->accessToken())
            ->timeout(15)
            ->post("https://fcm.googleapis.com/v1/projects/{$project}/messages:send", [
                'message' => [
                    'token' => $deviceToken,
                    'notification' => [
                        'title' => 'Begin with God',
                        'body' => 'A new day to pray, listen, and plant something good.',
                    ],
                    'data' => ['route' => '/today', 'kind' => 'morning'],
                    'android' => [
                        'priority' => 'high',
                        'notification' => [
                            'channel_id' => 'soulbuddy_morning_v1',
                            'tag' => 'soulbuddy-morning',
                        ],
                    ],
                ],
            ]);

        return $response->successful();
    }

    private function accessToken(): string
    {
        return Cache::remember('firebase_messaging_access_token', now()->addMinutes(50), function (): string {
            $path = (string) config('services.firebase.service_account_path');
            if ($path === '' || ! is_readable($path)) {
                throw new RuntimeException('Firebase service account is not configured.');
            }
            $account = json_decode((string) file_get_contents($path), true, flags: JSON_THROW_ON_ERROR);
            $now = time();
            $assertion = JWT::encode([
                'iss' => $account['client_email'],
                'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
                'aud' => 'https://oauth2.googleapis.com/token',
                'iat' => $now,
                'exp' => $now + 3600,
            ], $account['private_key'], 'RS256');
            $response = Http::asForm()->timeout(15)->post('https://oauth2.googleapis.com/token', [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $assertion,
            ]);
            if (! $response->successful() || ! is_string($response->json('access_token'))) {
                throw new RuntimeException('Firebase authorization failed.');
            }

            return $response->json('access_token');
        });
    }
}
