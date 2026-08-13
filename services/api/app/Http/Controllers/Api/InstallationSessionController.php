<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\InstallationSessionRequest;
use App\Models\AppInstallation;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class InstallationSessionController extends Controller
{
    public function __invoke(InstallationSessionRequest $request): JsonResponse
    {
        $validated = $request->validated();
        $created = false;
        $result = DB::transaction(function () use ($validated, &$created): array {
            $user = User::query()->where('public_id', $validated['owner_id'])->lockForUpdate()->first();
            if ($user === null) {
                $claimed = AppInstallation::query()->whereKey($validated['device_id'])->exists();
                abort_if($claimed, 409);
                $user = new User;
                $user->forceFill([
                    'public_id' => $validated['owner_id'],
                    'name' => 'SoulBuddy '.str_pad((string) random_int(0, 9999), 4, '0', STR_PAD_LEFT),
                    'email' => $validated['owner_id'].'@install.soulbuddy.invalid',
                    'password' => Str::random(64),
                ])->save();
                $installation = AppInstallation::create([
                    'id' => $validated['device_id'],
                    'user_id' => $user->id,
                    'secret_hash' => Hash::make($validated['installation_secret']),
                ]);
                $created = true;
            } else {
                $installation = AppInstallation::query()
                    ->whereKey($validated['device_id'])
                    ->where('user_id', $user->id)
                    ->lockForUpdate()
                    ->first();
                abort_if($installation === null, 409);
                abort_unless(Hash::check($validated['installation_secret'], $installation->secret_hash), 401);
            }

            $user->tokens()->where('name', 'installation:'.$installation->id)->delete();
            $token = $user->createToken('installation:'.$installation->id, ['app'])->plainTextToken;

            return [
                'token' => $token,
                'owner_id' => $user->public_id,
                'display_name' => $user->name,
            ];
        }, attempts: 3);

        return response()->json($result, $created ? 201 : 200);
    }
}
