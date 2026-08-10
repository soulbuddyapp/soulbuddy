<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Firebase\JWT\JWT;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PowerSyncTokenController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $secret = (string) config('services.powersync.secret');
        $issuer = (string) config('services.powersync.issuer');
        $audience = (string) config('services.powersync.audience');
        $keyId = (string) config('services.powersync.kid');
        $ttl = (int) config('services.powersync.ttl_seconds', 600);
        $signingKey = JWT::urlsafeB64Decode($secret);

        if (
            $issuer === '' || $audience === '' || $keyId === ''
            || strlen($signingKey) < 32 || $ttl < 60 || $ttl > 3600
        ) {
            return response()->json([
                'message' => 'Sync credentials are unavailable.',
            ], 503);
        }

        $issuedAt = now()->timestamp;
        $user = $request->user();
        $token = JWT::encode([
            'iss' => $issuer,
            'aud' => $audience,
            'sub' => $user->public_id,
            'iat' => $issuedAt,
            'exp' => $issuedAt + $ttl,
        ], $signingKey, 'HS256', $keyId);

        return response()->json([
            'token' => $token,
            'user_id' => $user->public_id,
        ]);
    }
}
