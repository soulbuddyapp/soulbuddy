<?php

it('does not expose server prayer draft generation routes', function () {
    $this->postJson('/api/prayer-drafts', [])->assertNotFound();
    $this->deleteJson('/api/prayer-drafts/attempt-1')->assertNotFound();
});
