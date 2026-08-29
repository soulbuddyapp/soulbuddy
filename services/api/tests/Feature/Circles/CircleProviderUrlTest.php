<?php

use App\Domain\Circles\CircleProviderUrl;

it('accepts only external group links for Circle providers', function () {
    expect(CircleProviderUrl::isAllowed('telegram', 'https://t.me/+group'))->toBeTrue()
        ->and(CircleProviderUrl::isAllowed('whatsapp_link', 'https://chat.whatsapp.com/group'))->toBeTrue()
        ->and(CircleProviderUrl::isAllowed('whatsapp_link', 'https://wa.me/2348012345678'))->toBeFalse()
        ->and(CircleProviderUrl::isAllowed('telegram', 'https://chat.whatsapp.com/group'))->toBeFalse();
});
