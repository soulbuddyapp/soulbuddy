<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\ReportCircleRequest;
use App\Models\Circle;
use App\Models\CircleDirectoryReport;
use App\Models\CircleModerationEvent;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;

class CircleReportController extends Controller
{
    public function __invoke(ReportCircleRequest $request, Circle $circle): JsonResponse
    {
        Gate::authorize('report', $circle);
        $user = $request->user();
        abort_unless($user instanceof User, 401);
        $reason = (string) $request->validated('reason');

        $created = false;
        $report = DB::transaction(function () use ($circle, $user, $reason, &$created): CircleDirectoryReport {
            $report = CircleDirectoryReport::query()->firstOrCreate([
                'circle_id' => $circle->id,
                'reporter_user_id' => $user->id,
                'reason_code' => $reason,
                'status' => 'open',
            ]);
            $created = $report->wasRecentlyCreated;
            if ($created) {
                CircleModerationEvent::create([
                    'circle_id' => $circle->id,
                    'actor_user_id' => $user->id,
                    'event_type' => 'reported',
                    'reason_code' => $reason,
                    'created_at' => now(),
                ]);
            }

            return $report;
        });

        return response()->json([
            'status' => 'received',
            'report_id' => $report->id,
            'created' => $created,
        ], 202);
    }
}
