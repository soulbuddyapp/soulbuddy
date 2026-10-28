<?php

namespace App\Domain\LifePlanning;

use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;

class LifePlannerService
{
    public const DOMAINS = [
        'prayer', 'learning', 'self_examination', 'work', 'relationships', 'service', 'rest',
    ];

    public function current(User $user): array
    {
        $plan = DB::table('life_plans')->where('user_id', $user->id)
            ->whereNull('archived_at')->orderByDesc('created_at')->first();

        return $plan ? $this->snapshot($user, $plan) : [
            'plan' => null,
            'message' => 'No seven-day plan yet.',
        ];
    }

    public function history(User $user, array $input): array
    {
        $data = Validator::make($input, ['page' => ['sometimes', 'integer', 'between:1,10000']])->validate();
        $page = $data['page'] ?? 1;
        $plans = DB::table('life_plans')->where('user_id', $user->id)
            ->orderByDesc('created_at')->orderByDesc('id')
            ->offset(($page - 1) * 20)->limit(21)->get();

        return [
            'plans' => $plans->take(20)->map(fn (object $plan): array => [
                'id' => $plan->id,
                'focus' => $plan->focus,
                'starts_on' => $plan->starts_on,
                'timezone' => $plan->timezone,
                'archived' => $plan->archived_at !== null,
            ])->values()->all(),
            'next_page' => $plans->count() > 20 ? $page + 1 : null,
        ];
    }

    public function get(User $user, array $input): array
    {
        $data = Validator::make($input, ['plan_id' => ['sometimes', 'uuid']])->validate();
        if (! isset($data['plan_id'])) {
            return $this->current($user);
        }
        $plan = DB::table('life_plans')->where('user_id', $user->id)->where('id', $data['plan_id'])->first();
        if (! $plan) {
            throw ValidationException::withMessages(['plan_id' => ['Plan not found.']]);
        }

        return $this->snapshot($user, $plan);
    }

    public function create(User $user, array $input): array
    {
        $data = Validator::make($input, [
            'request_id' => ['required', 'uuid'],
            'confirmed' => ['required', 'accepted'],
            'replace_active' => ['sometimes', 'boolean'],
            'focus' => ['required', 'string', 'min:8', 'max:240'],
            'starts_on' => ['required', 'date_format:Y-m-d'],
            'timezone' => ['required', 'timezone'],
            'items' => ['required', 'array', 'min:7', 'max:35'],
            'items.*.day' => ['required', 'integer', 'between:0,6'],
            'items.*.domain' => ['required', 'in:'.implode(',', self::DOMAINS)],
            'items.*.title' => ['required', 'string', 'min:3', 'max:140'],
            'items.*.minutes' => ['required', 'integer', 'between:2,180'],
        ])->validate();

        if (count(array_unique(array_column($data['items'], 'day'))) !== 7) {
            throw ValidationException::withMessages([
                'items' => ['Include at least one commitment for each of the seven days.'],
            ]);
        }
        $dailyCounts = array_count_values(array_column($data['items'], 'day'));
        if (max($dailyCounts) > 5) {
            throw ValidationException::withMessages([
                'items' => ['Use no more than five commitments per day.'],
            ]);
        }

        $starts = Carbon::createFromFormat('!Y-m-d', $data['starts_on'], $data['timezone']);
        $now = Carbon::now($data['timezone'])->startOfDay();
        if ($starts->lt($now) || $starts->gt($now->copy()->addDays(14))) {
            throw ValidationException::withMessages([
                'starts_on' => ['Choose a start date between today and fourteen days from now in the selected timezone.'],
            ]);
        }

        $planId = DB::transaction(function () use ($user, $data, $starts): string {
            // Serialize competing plan writes per account, including the initial creation.
            User::query()->whereKey($user->id)->lockForUpdate()->firstOrFail();

            $previous = DB::table('life_plans')->where('user_id', $user->id)
                ->where('request_id', $data['request_id'])->first();
            if ($previous) {
                return $previous->id; // Retry-safe even if this plan was archived.
            }

            $active = DB::table('life_plans')->where('user_id', $user->id)
                ->whereNull('archived_at')->get();
            if ($active->isNotEmpty() && ! ($data['replace_active'] ?? false)) {
                throw ValidationException::withMessages([
                    'replace_active' => ['An active plan exists. Review it before explicitly replacing it.'],
                ]);
            }
            if ($active->isNotEmpty()) {
                DB::table('life_plans')->where('user_id', $user->id)
                    ->whereNull('archived_at')->update(['archived_at' => now(), 'updated_at' => now()]);
            }

            $id = (string) Str::uuid();
            DB::table('life_plans')->insert([
                'id' => $id,
                'user_id' => $user->id,
                'request_id' => $data['request_id'],
                'focus' => $data['focus'],
                'starts_on' => $data['starts_on'],
                'timezone' => $data['timezone'],
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            foreach ($data['items'] as $item) {
                DB::table('life_plan_items')->insert([
                    'id' => (string) Str::uuid(),
                    'plan_id' => $id,
                    'user_id' => $user->id,
                    'planned_on' => $starts->copy()->addDays($item['day'])->toDateString(),
                    'domain' => $item['domain'],
                    'title' => $item['title'],
                    'minutes' => $item['minutes'],
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }

            return $id;
        }, attempts: 3);

        $plan = DB::table('life_plans')->where('user_id', $user->id)->where('id', $planId)->firstOrFail();

        return $this->snapshot($user, $plan);
    }

    public function checkIn(User $user, array $input): array
    {
        $data = Validator::make($input, [
            'item_id' => ['required', 'uuid'],
            'outcome' => ['required', 'in:done,partial,skipped'],
            'note' => ['nullable', 'string', 'max:300'],
            'confirmed' => ['required', 'accepted'],
        ])->validate();

        $item = DB::table('life_plan_items as items')
            ->join('life_plans as plans', 'plans.id', '=', 'items.plan_id')
            ->where('items.user_id', $user->id)
            ->where('plans.user_id', $user->id)
            ->whereNull('plans.archived_at')
            ->where('items.id', $data['item_id'])
            ->select('items.id', 'items.plan_id')->first();
        if (! $item) {
            throw ValidationException::withMessages(['item_id' => ['The active commitment was not found.']]);
        }

        DB::transaction(function () use ($user, $item, $data): void {
            // Lock the parent row so duplicate calls cannot race to insert a second check-in.
            DB::table('life_plan_items')->where('id', $item->id)->lockForUpdate()->first();
            $previous = DB::table('life_plan_checkins')->where('item_id', $item->id)->first();
            $payload = [
                'outcome' => $data['outcome'],
                'note' => $data['note'] ?? null,
                'updated_at' => now(),
            ];
            if ($previous) {
                DB::table('life_plan_checkins')->where('item_id', $item->id)->update($payload);
            } else {
                DB::table('life_plan_checkins')->insert($payload + [
                    'id' => (string) Str::uuid(),
                    'item_id' => $item->id,
                    'plan_id' => $item->plan_id,
                    'user_id' => $user->id,
                    'created_at' => now(),
                ]);
            }
        });

        return $this->current($user);
    }

    public function weeklySummary(User $user): array
    {
        $snapshot = $this->current($user);
        if ($snapshot['plan'] === null) {
            return $snapshot;
        }
        $outcomes = collect($snapshot['items'])->countBy(fn (array $item): string => $item['outcome'] ?? 'not_recorded');

        return [
            'plan' => $snapshot['plan'],
            'outcomes' => [
                'done' => $outcomes->get('done', 0),
                'partial' => $outcomes->get('partial', 0),
                'skipped' => $outcomes->get('skipped', 0),
                'not_recorded' => $outcomes->get('not_recorded', 0),
            ],
            'items' => $snapshot['items'],
            'review' => $snapshot['review'],
            'reflection_prompts' => [
                'What helped you respond well to your responsibilities?',
                'Where did your plan feel unrealistic or out of balance?',
                'What one adjustment would make next week more faithful and sustainable?',
            ],
            'note' => 'Commitments are practical observations, not a score of holiness or spiritual worth.',
        ];
    }

    public function saveReview(User $user, array $input): array
    {
        $data = Validator::make($input, [
            'plan_id' => ['required', 'uuid'],
            'reflection' => ['required', 'string', 'min:8', 'max:2000'],
            'next_adjustment' => ['required', 'string', 'min:3', 'max:500'],
            'confirmed' => ['required', 'accepted'],
        ])->validate();

        $plan = DB::table('life_plans')->where('id', $data['plan_id'])
            ->where('user_id', $user->id)->whereNull('archived_at')->first();
        if (! $plan) {
            throw ValidationException::withMessages(['plan_id' => ['The active plan was not found.']]);
        }
        $existing = DB::table('life_plan_reviews')->where('plan_id', $plan->id)->first();

        DB::table('life_plan_reviews')->updateOrInsert(['plan_id' => $plan->id], [
            'id' => $existing?->id ?? (string) Str::uuid(),
            'user_id' => $user->id,
            'reflection' => $data['reflection'],
            'next_adjustment' => $data['next_adjustment'],
            'created_at' => $existing?->created_at ?? now(),
            'updated_at' => now(),
        ]);

        return $this->weeklySummary($user);
    }

    public function delete(User $user, array $input): array
    {
        $data = Validator::make($input, [
            'plan_id' => ['required', 'uuid'],
            'confirmed' => ['required', 'accepted'],
        ])->validate();

        $deleted = DB::table('life_plans')->where('user_id', $user->id)
            ->where('id', $data['plan_id'])->delete();

        return ['deleted' => $deleted === 1, 'message' => 'Plan, commitments, check-ins and review deleted if owned by this account.'];
    }

    private function snapshot(User $user, object $plan): array
    {
        $checkins = DB::table('life_plan_checkins')->where('user_id', $user->id)
            ->where('plan_id', $plan->id)->get()->keyBy('item_id');
        $items = DB::table('life_plan_items')->where('user_id', $user->id)
            ->where('plan_id', $plan->id)->orderBy('planned_on')->orderBy('created_at')
            ->get()->map(function (object $item) use ($checkins): array {
                $checkin = $checkins->get($item->id);

                return [
                    'id' => $item->id,
                    'date' => $item->planned_on,
                    'domain' => $item->domain,
                    'title' => $item->title,
                    'minutes' => $item->minutes,
                    'outcome' => $checkin?->outcome,
                    'note' => $checkin?->note,
                ];
            })->all();

        $review = DB::table('life_plan_reviews')->where('user_id', $user->id)
            ->where('plan_id', $plan->id)->first();

        return [
            'plan' => [
                'id' => $plan->id,
                'focus' => $plan->focus,
                'starts_on' => $plan->starts_on,
                'timezone' => $plan->timezone,
                'archived' => $plan->archived_at !== null,
            ],
            'items' => $items,
            'review' => $review ? [
                'reflection' => $review->reflection,
                'next_adjustment' => $review->next_adjustment,
            ] : null,
            'guidance' => 'Balance prayer, learning, self-examination, service, relationships, work and rest. Do not infer holiness from completed items.',
        ];
    }
}
