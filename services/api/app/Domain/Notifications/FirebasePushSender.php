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
    /**
     * @param  array{title: string, body: string, route: string, kind: string, channel_id: string, tag: string}  $notice
     */
    public function sendNotice(string $deviceToken, array $notice): bool
    {
        $project = (string) config('services.firebase.project_id');
        if ($project === '') {
            throw new RuntimeException('Firebase project is not configured.');
        }

        $response = $this->sendMessage($project, $deviceToken, $notice);
        if ($response->status() === 401) {
            Cache::forget('firebase_messaging_access_token');
            $response = $this->sendMessage($project, $deviceToken, $notice);
        }
        if ($response->successful()) {
            return true;
        }

        $code = $this->errorCode($response);
        Log::warning($this->rejectionMessage($notice['kind']), [
            'http_status' => $response->status(),
            'error_code' => $code,
        ]);
        if ($code === 'UNREGISTERED') {
            throw new UnregisteredPushToken;
        }

        return false;
    }

    public function sendMorning(string $deviceToken): bool
    {
        return $this->sendNotice($deviceToken, [
            'title' => 'Begin with God',
            'body' => 'A new day to pray, listen, and plant something good.',
            'route' => '/today',
            'kind' => 'morning',
            'channel_id' => 'soulbuddy_morning_v1',
            'tag' => 'soulbuddy-morning',
        ]);
    }

    /**
     * Each notice kind keeps its own operational log line, so existing morning
     * diagnostics stay unchanged.
     */
    private function rejectionMessage(string $kind): string
    {
        return $kind === 'morning'
            ? 'Firebase morning notification rejected.'
            : 'Firebase notification rejected.';
    }

    /**
     * @param  array{title: string, body: string, route: string, kind: string, channel_id: string, tag: string}  $notice
     */
    private function sendMessage(string $project, string $deviceToken, array $notice): Response
    {
        return Http::withToken($this->accessToken())
            ->timeout(15)
            ->post("https://fcm.googleapis.com/v1/projects/{$project}/messages:send", [
                'message' => [
                    'token' => $deviceToken,
                    'notification' => [
                        'title' => $notice['title'],
                        'body' => $notice['body'],
                    ],
                    'data' => ['route' => $notice['route'], 'kind' => $notice['kind']],
                    'android' => [
                        'priority' => 'high',
                        'notification' => [
                            'channel_id' => $notice['channel_id'],
                            'tag' => $notice['tag'],
                        ],
                    ],
                ],
            ]);
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
