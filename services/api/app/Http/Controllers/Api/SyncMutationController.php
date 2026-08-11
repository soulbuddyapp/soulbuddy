<?php

namespace App\Http\Controllers\Api;

use App\Domain\Sync\ApplySyncMutation;
use App\Http\Controllers\Controller;
use App\Http\Requests\SyncMutationBatchRequest;
use Illuminate\Http\JsonResponse;

class SyncMutationController extends Controller
{
    public function __invoke(
        SyncMutationBatchRequest $request,
        ApplySyncMutation $mutations,
    ): JsonResponse {
        return response()->json(
            $mutations->apply($request->user(), $request->validated('operations')),
        );
    }
}
