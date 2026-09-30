<?php

namespace App\Domain\Notifications;

use RuntimeException;

class UnregisteredPushToken extends RuntimeException
{
    public function __construct()
    {
        parent::__construct('Firebase registration is no longer valid.');
    }
}
