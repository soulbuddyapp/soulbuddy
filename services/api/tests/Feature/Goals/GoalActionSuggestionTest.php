<?php

use App\Domain\GoalGuidance\GoalActionSuggestionProvider;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

it('requires authentication', function () {
    $this->postJson('/api/goal-action-suggestions', validSuggestionPayload())
        ->assertUnauthorized();
});

it('returns only normalized safe practical actions', function () {
    $provider = Mockery::mock(GoalActionSuggestionProvider::class);
    $provider->shouldReceive('suggest')->once()->andReturn([
        ' Write the two clearest options on one page ',
        'God told you to choose this path.',
        'Write the two clearest options on one page',
        'Name one responsibility that is already in front of you',
        'Ask one trusted person for a short, honest conversation',
        'A fourth valid choice is ignored.',
    ]);
    app()->instance(GoalActionSuggestionProvider::class, $provider);

    $this->actingAs(User::factory()->create())
        ->postJson('/api/goal-action-suggestions', validSuggestionPayload())
        ->assertOk()
        ->assertExactJson([
            'suggestions' => [
                'Write the two clearest options on one page',
                'Name one responsibility that is already in front of you',
                'Ask one trusted person for a short, honest conversation',
            ],
        ]);
});

it('rejects unsafe provider advice before it reaches the app', function () {
    $provider = Mockery::mock(GoalActionSuggestionProvider::class);
    $provider->shouldReceive('suggest')->once()->andReturn([
        'Stop taking your insulin tonight.',
        'Cut yourself tonight.',
        'Confront them alone.',
        'Quit alcohol cold turkey today.',
        'Write the two clearest options on one page',
    ]);
    app()->instance(GoalActionSuggestionProvider::class, $provider);

    $this->actingAs(User::factory()->create())
        ->postJson('/api/goal-action-suggestions', [
            ...validSuggestionPayload(),
            'situation' => 'I am being abused and do not feel safe at home.',
        ])
        ->assertOk()
        ->assertExactJson([
            'suggestions' => [
                'Write the two clearest options on one page',
            ],
        ]);
});

it('validates the private context boundary', function (array $change) {
    $this->actingAs(User::factory()->create())
        ->postJson('/api/goal-action-suggestions', [
            ...validSuggestionPayload(),
            ...$change,
        ])
        ->assertUnprocessable();
})->with([
    'unknown starter' => [['starter_key' => 'prophecy']],
    'unknown agency' => [['agency_choice' => 'god_will_do_it']],
    'oversized situation' => [['situation' => str_repeat('x', 2001)]],
    'unknown field' => [['private_recording' => 'not accepted']],
]);

function validSuggestionPayload(): array
{
    return [
        'starter_key' => 'direction',
        'title' => 'Find direction',
        'situation' => 'I am choosing between two paths.',
        'agency_choice' => 'not_sure',
        'locale' => 'en',
    ];
}
