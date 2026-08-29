<?php

use App\Domain\Circles\CircleModerationService;
use App\Models\Circle;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;

uses(RefreshDatabase::class);

it('creates a server-backed external Circle and exposes only public active directory entries', function () {
    $owner = User::factory()->create();
    $viewer = User::factory()->create();

    $created = $this->actingAs($owner)->postJson('/api/circles', circlePayload())
        ->assertCreated()
        ->assertJsonPath('name', 'Walk together')
        ->assertJsonPath('category', 'accountability')
        ->assertJsonPath('provider', 'telegram')
        ->assertJsonPath('open_url', 'https://t.me/+soulbuddy-test')
        ->assertJsonPath('directory_listed', true)
        ->assertJsonPath('is_owner', true);

    expect($created->json('public_id'))->not->toBeEmpty()
        ->and(Schema::hasTable('circle_messages'))->toBeFalse();
    $this->assertDatabaseHas('circles', [
        'public_id' => $created->json('public_id'),
        'owner_user_id' => $owner->id,
        'visibility' => 'public',
        'status' => 'active',
        'directory_listed' => true,
    ]);
    $this->assertDatabaseHas('circle_provider_bindings', [
        'provider' => 'telegram',
        'binding_status' => 'ready',
    ]);

    $this->actingAs($viewer)->getJson('/api/circles?category=accountability')
        ->assertOk()
        ->assertJsonCount(1, 'data')
        ->assertJsonPath('data.0.public_id', $created->json('public_id'))
        ->assertJsonPath('data.0.is_owner', false);
});

it('keeps unlisted and private Circles out of discovery while preserving direct access rules', function () {
    $owner = User::factory()->create();
    $viewer = User::factory()->create();
    $unlisted = $this->actingAs($owner)
        ->postJson('/api/circles', circlePayload(['visibility' => 'unlisted']))
        ->assertCreated()->json('public_id');
    $private = $this->actingAs($owner)
        ->postJson('/api/circles', circlePayload([
            'name' => 'Private Circle',
            'visibility' => 'private',
            'open_url' => 'https://t.me/+private-test',
        ]))
        ->assertCreated()->json('public_id');

    $this->actingAs($viewer)->getJson('/api/circles')
        ->assertOk()->assertJsonCount(0, 'data');
    $this->actingAs($viewer)->getJson("/api/circles/{$unlisted}")
        ->assertOk()->assertJsonPath('visibility', 'unlisted');
    $this->actingAs($viewer)->getJson("/api/circles/{$private}")
        ->assertForbidden();
    $this->actingAs($owner)->getJson("/api/circles/{$private}")
        ->assertOk()->assertJsonPath('is_owner', true);
});

it('keeps draft Circles owner-visible but undiscoverable until published', function () {
    $owner = User::factory()->create();
    $viewer = User::factory()->create();
    $publicId = $this->actingAs($owner)
        ->postJson('/api/circles', circlePayload(['status' => 'draft']))
        ->assertCreated()
        ->assertJsonPath('status', 'draft')
        ->json('public_id');

    $this->actingAs($viewer)->getJson('/api/circles')
        ->assertOk()->assertJsonCount(0, 'data');
    $this->actingAs($viewer)->getJson("/api/circles/{$publicId}")
        ->assertForbidden();
    $this->actingAs($owner)->getJson('/api/circles/mine')
        ->assertOk()
        ->assertJsonPath('data.0.public_id', $publicId)
        ->assertJsonPath('data.0.status', 'draft');

    $this->actingAs($owner)->patchJson("/api/circles/{$publicId}", ['status' => 'active'])
        ->assertOk()->assertJsonPath('status', 'active');
    $this->actingAs($viewer)->getJson('/api/circles')
        ->assertOk()
        ->assertJsonCount(1, 'data')
        ->assertJsonPath('data.0.public_id', $publicId);
});

it('enforces owner edits and lifecycle visibility', function () {
    $owner = User::factory()->create();
    $other = User::factory()->create();
    $publicId = $this->actingAs($owner)->postJson('/api/circles', circlePayload())
        ->assertCreated()->json('public_id');

    $this->actingAs($other)->patchJson("/api/circles/{$publicId}", ['name' => 'Hijacked'])
        ->assertForbidden();
    $this->actingAs($owner)->patchJson("/api/circles/{$publicId}", ['status' => 'paused'])
        ->assertOk()->assertJsonPath('status', 'paused');
    $this->actingAs($other)->getJson('/api/circles')->assertJsonCount(0, 'data');
    $this->actingAs($owner)->getJson('/api/circles/mine')
        ->assertOk()->assertJsonPath('data.0.public_id', $publicId);
    $this->actingAs($owner)->patchJson("/api/circles/{$publicId}", ['status' => 'active'])
        ->assertOk();
    $this->actingAs($owner)->patchJson("/api/circles/{$publicId}", ['status' => 'archived'])
        ->assertOk()->assertJsonPath('status', 'archived');
    $this->actingAs($owner)->getJson('/api/circles/mine')->assertJsonCount(0, 'data');
});

it('validates provider hosts and rejects conversation-shaped payloads', function () {
    $owner = User::factory()->create();

    $this->actingAs($owner)->postJson('/api/circles', circlePayload([
        'open_url' => 'https://chat.whatsapp.com/not-telegram',
    ]))->assertUnprocessable()->assertJsonValidationErrors('open_url');
    $this->actingAs($owner)->postJson('/api/circles', circlePayload([
        'open_url' => 'https://example.com/not-a-circle',
    ]))->assertUnprocessable()->assertJsonValidationErrors('open_url');
    $this->actingAs($owner)->postJson('/api/circles', circlePayload([
        'chat_body' => 'Do not accept external conversation content.',
    ]))->assertUnprocessable()->assertJsonPath('errors.payload.0', 'unknown_keys');
});

it('filters, searches and cursor-paginates the public directory deterministically', function () {
    $owner = User::factory()->create();
    foreach ([
        ['name' => 'Alpha accountability', 'category' => 'accountability', 'open_url' => 'https://t.me/+alpha'],
        ['name' => 'Beta accountability', 'category' => 'accountability', 'open_url' => 'https://t.me/+beta'],
        ['name' => 'Gamma study', 'category' => 'bible_study', 'open_url' => 'https://t.me/+gamma'],
    ] as $attributes) {
        $this->actingAs($owner)->postJson('/api/circles', circlePayload($attributes))->assertCreated();
    }

    $first = $this->actingAs($owner)
        ->getJson('/api/circles?category=accountability&limit=1')
        ->assertOk()->assertJsonCount(1, 'data');
    expect($first->json('next_cursor'))->not->toBeNull();
    $second = $this->actingAs($owner)
        ->getJson('/api/circles?category=accountability&limit=1&cursor='.urlencode($first->json('next_cursor')))
        ->assertOk()->assertJsonCount(1, 'data');
    expect($second->json('data.0.public_id'))->not->toBe($first->json('data.0.public_id'));

    $this->actingAs($owner)->getJson('/api/circles?q=Gamma')
        ->assertOk()->assertJsonCount(1, 'data')
        ->assertJsonPath('data.0.category', 'bible_study');
});

it('records minimal reports and keeps moderation delisting authoritative', function () {
    $owner = User::factory()->create();
    $reporter = User::factory()->create();
    $moderator = User::factory()->create();
    $publicId = $this->actingAs($owner)->postJson('/api/circles', circlePayload())
        ->assertCreated()->json('public_id');
    $circle = Circle::query()->where('public_id', $publicId)->firstOrFail();

    $this->actingAs($reporter)->postJson("/api/circles/{$publicId}/reports", [
        'reason' => 'unsafe',
        'evidence' => 'External chat should never be copied into SoulBuddy reports.',
    ])->assertUnprocessable()->assertJsonPath('errors.payload.0', 'unknown_keys');
    $this->actingAs($reporter)->postJson("/api/circles/{$publicId}/reports", ['reason' => 'unsafe'])
        ->assertAccepted()->assertJsonPath('status', 'received');
    $this->assertDatabaseHas('circle_directory_reports', [
        'circle_id' => $circle->id,
        'reporter_user_id' => $reporter->id,
        'reason_code' => 'unsafe',
    ]);

    $service = app(CircleModerationService::class);
    $service->delist($circle, $moderator, 'review_pending');
    expect($circle->fresh()->visibility)->toBe('public')
        ->and($circle->fresh()->directory_listed)->toBeFalse();

    $this->actingAs($owner)->patchJson("/api/circles/{$publicId}", ['visibility' => 'unlisted'])
        ->assertOk()->assertJsonPath('directory_listed', false);
    $this->actingAs($owner)->patchJson("/api/circles/{$publicId}", ['visibility' => 'public'])
        ->assertOk()->assertJsonPath('directory_listed', false);
    $this->actingAs($reporter)->getJson('/api/circles')->assertJsonCount(0, 'data');

    $service->relist($circle->fresh(), $moderator, 'review_cleared');
    expect($circle->fresh()->directory_listed)->toBeTrue();
    $this->actingAs($reporter)->getJson('/api/circles')->assertJsonCount(1, 'data');

    $service->delist($circle->fresh(), $moderator, 'confirmed_unsafe');
    $service->suspend($circle->fresh(), $moderator, 'confirmed_unsafe');
    expect($circle->fresh()->status)->toBe('suspended')
        ->and($circle->fresh()->directory_listed)->toBeFalse();
    $this->actingAs($owner)->patchJson("/api/circles/{$publicId}", ['status' => 'active'])
        ->assertForbidden();

    $this->assertDatabaseHas('circle_moderation_events', [
        'circle_id' => $circle->id,
        'event_type' => 'reported',
        'reason_code' => 'unsafe',
    ]);
    $this->assertDatabaseHas('circle_moderation_events', [
        'circle_id' => $circle->id,
        'event_type' => 'delisted',
        'reason_code' => 'review_pending',
    ]);
    $this->assertDatabaseHas('circle_moderation_events', [
        'circle_id' => $circle->id,
        'event_type' => 'relisted',
        'reason_code' => 'review_cleared',
    ]);
    $this->assertDatabaseHas('circle_moderation_events', [
        'circle_id' => $circle->id,
        'event_type' => 'suspended',
        'reason_code' => 'confirmed_unsafe',
    ]);
    $this->actingAs($reporter)->getJson('/api/circles')->assertJsonCount(0, 'data');
});

function circlePayload(array $overrides = []): array
{
    return array_merge([
        'name' => 'Walk together',
        'category' => 'accountability',
        'description' => 'A small group for honest accountability and prayer.',
        'visibility' => 'public',
        'provider' => 'telegram',
        'open_url' => 'https://t.me/+soulbuddy-test',
    ], $overrides);
}
