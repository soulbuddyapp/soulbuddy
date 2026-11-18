<?php

it('keeps the MySQL-only owner projection out of ordinary migrations', function () {
    $database = dirname(__DIR__, 2).'/database';

    expect(glob($database.'/migrations/*_add_powersync_owner_projection.php'))->toBe([])
        ->and(glob($database.'/powersync/*_add_powersync_owner_projection.php'))->toHaveCount(1);
});
