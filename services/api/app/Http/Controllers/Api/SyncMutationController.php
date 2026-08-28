<?php

namespace App\Http\Controllers\Api;

use App\Domain\Sync\ApplyCompositeSyncMutation;
use App\Http\Controllers\Controller;
use App\Http\Requests\SyncMutationBatchRequest;
use Illuminate\Http\JsonResponse;

class SyncMutationController extends Controller
{
    public function __invoke(
        SyncMutationBatchRequest $request,
        ApplyCompositeSyncMutation $mutations,
    ): JsonResponse {
        return response()->json(
            $mutations->apply($request->user(), $request->validated('operations')),
        );
    }
}
