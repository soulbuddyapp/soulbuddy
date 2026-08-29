<?php

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

it('searches Circle names and purposes case-insensitively', function () {
    $owner = User::factory()->create();
    $this->actingAs($owner)->postJson('/api/circles', [
        'name' => 'Gamma Study',
        'category' => 'bible_study',
        'description' => 'Read Scripture Together each week.',
        'visibility' => 'public',
        'provider' => 'telegram',
        'open_url' => 'https://t.me/+gamma-study',
    ])->assertCreated();

    $this->actingAs($owner)
        ->getJson('/api/circles?q=gamma')
        ->assertOk()
        ->assertJsonCount(1, 'data')
        ->assertJsonPath('data.0.name', 'Gamma Study');

    $this->actingAs($owner)
        ->getJson('/api/circles?q=scripture')
        ->assertOk()
        ->assertJsonCount(1, 'data')
        ->assertJsonPath('data.0.name', 'Gamma Study');
});
