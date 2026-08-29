<?php

use App\Domain\Circles\CircleProviderUrl;

it('accepts only external group links for Circle providers', function () {
    expect(CircleProviderUrl::isAllowed('telegram', 'https://t.me/+group'))->toBeTrue()
        ->and(CircleProviderUrl::isAllowed('telegram', 'https://t.me/joinchat/group'))->toBeTrue()
        ->and(CircleProviderUrl::isAllowed('telegram', 'https://t.me/public_group'))->toBeTrue()
        ->and(CircleProviderUrl::isAllowed('whatsapp_link', 'https://chat.whatsapp.com/group'))->toBeTrue()
        ->and(CircleProviderUrl::isAllowed('whatsapp_link', 'https://wa.me/2348012345678'))->toBeFalse()
        ->and(CircleProviderUrl::isAllowed('telegram', 'https://chat.whatsapp.com/group'))->toBeFalse()
        ->and(CircleProviderUrl::isAllowed('telegram', 'https://t.me/share?url=https://example.com'))->toBeFalse()
        ->and(CircleProviderUrl::isAllowed('telegram', 'https://t.me/proxy?server=example.com&port=443'))->toBeFalse()
        ->and(CircleProviderUrl::isAllowed('telegram', 'https://t.me/public_group/42'))->toBeFalse()
        ->and(CircleProviderUrl::isAllowed('telegram', 'https://t.me/public_group?start=payload'))->toBeFalse();
});
