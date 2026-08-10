<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Firebase\JWT\JWT;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

class PowerSyncTokenController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $secret = (string) config('services.powersync.secret');
        $issuer = (string) config('services.powersync.issuer');
        $audience = (string) config('services.powersync.audience');
        $ttl = (int) config('services.powersync.ttl_seconds', 600);

        if ($secret === '' || $issuer === '' || $audience === '' || $ttl < 60) {
            throw new RuntimeException('PowerSync token issuance is not configured.');
        }

        $issuedAt = now()->timestamp;
        $user = $request->user();
        $token = JWT::encode([
            'iss' => $issuer,
            'aud' => $audience,
            'sub' => $user->public_id,
            'iat' => $issuedAt,
            'exp' => $issuedAt + $ttl,
        ], $secret, 'HS256');

        return response()->json([
            'token' => $token,
            'user_id' => $user->public_id,
        ]);
    }
}
