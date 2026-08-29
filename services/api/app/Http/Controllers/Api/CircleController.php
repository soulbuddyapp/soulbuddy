<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreCircleRequest;
use App\Http\Requests\UpdateCircleRequest;
use App\Models\Circle;
use App\Models\CircleProviderBinding;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Pagination\Cursor;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;

class CircleController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'category' => ['nullable', Rule::in(['accountability', 'daily_exhortation', 'bible_study'])],
            'q' => ['nullable', 'string', 'max:80'],
            'cursor' => ['nullable', 'string', 'max:500'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:30'],
        ]);
        $user = $this->user($request);
        $limit = (int) ($validated['limit'] ?? 20);
        $cursor = Cursor::fromEncoded($validated['cursor'] ?? null);
        $query = Circle::query()
            ->with('providerBinding')
            ->where('directory_listed', true)
            ->where('visibility', 'public')
            ->where('status', 'active')
            ->whereHas('providerBinding', fn ($binding) => $binding->where('binding_status', 'ready'));

        if (($validated['category'] ?? null) !== null) {
            $query->where('category', $validated['category']);
        }
        $search = trim((string) ($validated['q'] ?? ''));
        if ($search !== '') {
            $query->where(function ($nested) use ($search): void {
                $nested->where('name', 'like', "%{$search}%")
                    ->orWhere('description', 'like', "%{$search}%");
            });
        }

        $page = $query
            ->orderBy('public_id')
            ->cursorPaginate($limit, ['*'], 'cursor', $cursor);

        return response()->json([
            'data' => $page->getCollection()
                ->map(fn (Circle $circle) => $this->payload($circle, $user))
                ->values()
                ->all(),
            'next_cursor' => $page->nextCursor()?->encode(),
        ]);
    }

    public function mine(Request $request): JsonResponse
    {
        $user = $this->user($request);
        $circles = Circle::query()
            ->with('providerBinding')
            ->where('owner_user_id', $user->id)
            ->where('status', '!=', 'archived')
            ->orderByDesc('updated_at')
            ->orderByDesc('id')
            ->get();

        return response()->json([
            'data' => $circles->map(fn (Circle $circle) => $this->payload($circle, $user))->all(),
        ]);
    }

    public function store(StoreCircleRequest $request): JsonResponse
    {
        $user = $this->user($request);
        Gate::authorize('create', Circle::class);
        $validated = $request->validated();

        $circle = DB::transaction(function () use ($user, $validated): Circle {
            $circle = Circle::create([
                'owner_user_id' => $user->id,
                'name' => trim($validated['name']),
                'category' => $validated['category'],
                'description' => trim($validated['description']),
                'visibility' => $validated['visibility'],
                'status' => 'active',
                'directory_listed' => true,
            ]);
            $circle->providerBinding()->create([
                'provider' => $validated['provider'],
                'open_url' => trim($validated['open_url']),
                'capabilities' => ['open_link'],
                'binding_status' => 'ready',
                'bound_at' => now(),
            ]);

            return $circle->load('providerBinding');
        });

        return response()->json($this->payload($circle, $user), 201);
    }

    public function show(Request $request, Circle $circle): JsonResponse
    {
        Gate::authorize('view', $circle);
        $circle->load('providerBinding');

        return response()->json($this->payload($circle, $this->user($request)));
    }

    public function update(UpdateCircleRequest $request, Circle $circle): JsonResponse
    {
        Gate::authorize('update', $circle);
        $validated = $request->validated();

        DB::transaction(function () use ($circle, $validated): void {
            $attributes = [];
            foreach (['name', 'category', 'description', 'visibility', 'status'] as $field) {
                if (array_key_exists($field, $validated)) {
                    $attributes[$field] = is_string($validated[$field])
                        ? trim($validated[$field])
                        : $validated[$field];
                }
            }
            if ($attributes !== []) {
                $circle->fill($attributes)->save();
            }
            if (isset($validated['provider'], $validated['open_url'])) {
                CircleProviderBinding::query()->updateOrCreate(
                    ['circle_id' => $circle->id],
                    [
                        'provider' => $validated['provider'],
                        'open_url' => trim($validated['open_url']),
                        'capabilities' => ['open_link'],
                        'binding_status' => 'ready',
                        'bound_at' => now(),
                        'last_verified_at' => null,
                    ],
                );
            }
        });

        return response()->json(
            $this->payload($circle->fresh()->load('providerBinding'), $this->user($request)),
        );
    }

    private function payload(Circle $circle, User $viewer): array
    {
        $binding = $circle->providerBinding;

        return [
            'public_id' => $circle->public_id,
            'name' => $circle->name,
            'category' => $circle->category,
            'description' => $circle->description,
            'visibility' => $circle->visibility,
            'status' => $circle->status,
            'directory_listed' => $circle->directory_listed,
            'provider' => $binding?->provider,
            'open_url' => $binding?->binding_status === 'ready' ? $binding->open_url : null,
            'capabilities' => $binding?->capabilities ?? [],
            'member_count' => null,
            'is_owner' => $circle->owner_user_id === $viewer->id,
            'updated_at' => $circle->updated_at?->toISOString(),
        ];
    }

    private function user(Request $request): User
    {
        $user = $request->user();
        abort_unless($user instanceof User, 401);

        return $user;
    }
}
