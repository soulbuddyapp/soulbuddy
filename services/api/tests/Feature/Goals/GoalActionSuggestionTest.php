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
        ' Put the phone outside the bedroom tonight. ',
        'God told you to choose this path.',
        'Put the phone outside the bedroom tonight.',
        'Write the decision factors on one page.',
        'Ask a trusted person for fifteen minutes to talk.',
        'A fourth valid choice is ignored.',
    ]);
    app()->instance(GoalActionSuggestionProvider::class, $provider);

    $this->actingAs(User::factory()->create())
        ->postJson('/api/goal-action-suggestions', validSuggestionPayload())
        ->assertOk()
        ->assertExactJson([
            'suggestions' => [
                'Put the phone outside the bedroom tonight.',
                'Write the decision factors on one page.',
                'Ask a trusted person for fifteen minutes to talk.',
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
