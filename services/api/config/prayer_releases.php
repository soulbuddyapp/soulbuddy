<?php

return [

    /*
    |---------------------------------------------------------------------------
    | Weekly prayer release publication
    |---------------------------------------------------------------------------
    |
    | The first release is published by an explicit UTC date rather than by
    | `now()`, so a deployment is reproducible and a seeder run can never move a
    | live release forward. Set PRAYER_RELEASE_PUBLISHED_AT before deploying a
    | later release.
    |
    */

    'published_at' => env('PRAYER_RELEASE_PUBLISHED_AT', '2026-10-05 07:00:00'),

];
