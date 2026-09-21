<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppInstallation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class InstallationPushController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $data = $request->validate([
            'device_id' => ['required', 'uuid'],
            'push_token' => ['nullable', 'string', 'max:512'],
            'time_zone' => ['required', 'timezone'],
        ]);

        $installation = AppInstallation::query()
            ->whereKey($data['device_id'])
            ->where('user_id', $request->user()->id)
            ->firstOrFail();
        $installation->forceFill([
            'push_token' => $data['push_token'] ?? null,
            'time_zone' => $data['time_zone'],
        ])->save();

        return response()->json(['registered' => $installation->push_token !== null]);
    }
}
