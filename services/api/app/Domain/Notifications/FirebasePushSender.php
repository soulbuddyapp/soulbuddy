<?php

namespace App\Domain\Notifications;

use Firebase\JWT\JWT;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;

class FirebasePushSender
{
    public function sendMorning(string $deviceToken): bool
    {
        $project = (string) config('services.firebase.project_id');
        if ($project === '') {
            throw new RuntimeException('Firebase project is not configured.');
        }

        $response = $this->send($project, $deviceToken);
        if ($response->status() === 401) {
            // A revoked or stale cached credential must not block the next 50 minutes.
            Cache::forget('firebase_messaging_access_token');
            $response = $this->send($project, $deviceToken);
        }
        if ($response->successful()) {
            return true;
        }

        $code = $this->errorCode($response);
        Log::warning('Firebase morning notification rejected.', [
            'http_status' => $response->status(),
            'error_code' => $code,
        ]);
        if ($code === 'UNREGISTERED') {
            throw new UnregisteredPushToken;
        }

        return false;
    }

    private function errorCode(Response $response): string
    {
        $details = $response->json('error.details');
        foreach (is_array($details) ? $details : [] as $detail) {
            if (! is_array($detail) || ($detail['@type'] ?? null) !== 'type.googleapis.com/google.firebase.fcm.v1.FcmError') {
                continue;
            }
            $code = $detail['errorCode'] ?? null;
            if (in_array($code, ['UNREGISTERED', 'INVALID_ARGUMENT', 'SENDER_ID_MISMATCH', 'QUOTA_EXCEEDED', 'UNAVAILABLE', 'INTERNAL', 'THIRD_PARTY_AUTH_ERROR'], true)) {
                return $code;
            }
        }

        $status = $response->json('error.status');

        return in_array($status, ['INVALID_ARGUMENT', 'UNAUTHENTICATED', 'PERMISSION_DENIED', 'NOT_FOUND', 'RESOURCE_EXHAUSTED', 'UNAVAILABLE', 'INTERNAL'], true)
            ? $status : 'UNKNOWN';
    }

    private function send(string $project, string $deviceToken): Response
    {
        return Http::withToken($this->accessToken())
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
