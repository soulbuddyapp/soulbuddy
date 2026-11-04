<?php

namespace App\Domain\PrayerReleases;

use RuntimeException;

/**
 * A release artifact failed its own integrity checks, so it must never be
 * seeded or served.
 */
class InvalidReleaseContent extends RuntimeException {}
