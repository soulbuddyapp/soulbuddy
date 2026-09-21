<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'powersync' => [
        'issuer' => env('POWERSYNC_JWT_ISSUER', env('APP_URL')),
        'audience' => env('POWERSYNC_JWT_AUDIENCE'),
        'secret' => env('POWERSYNC_JWT_SECRET'),
        'kid' => env('POWERSYNC_JWT_KID'),
        'ttl_seconds' => (int) env('POWERSYNC_JWT_TTL_SECONDS', 600),
    ],

    'deepgram' => [
        'key' => env('DEEPGRAM_API_KEY'),
        'base_url' => env('DEEPGRAM_BASE_URL', 'https://api.deepgram.com'),
        'model' => env('DEEPGRAM_TTS_MODEL', 'aura-2-thalia-en'),
        'encoding' => env('DEEPGRAM_TTS_ENCODING', 'mp3'),
        'bit_rate' => (int) env('DEEPGRAM_TTS_BIT_RATE', 32000),
        'disclosure_version' => env('PRAYER_NARRATION_DISCLOSURE_VERSION', 'deepgram-aura2-1'),
    ],

    'firebase' => [
        'project_id' => env('FIREBASE_PROJECT_ID'),
        'service_account_path' => env('FIREBASE_SERVICE_ACCOUNT_PATH'),
    ],

    'goal_guidance' => [
        'key' => env('DEEPSEEK_API_KEY'),
        'base_url' => env('GOAL_GUIDANCE_BASE_URL', 'https://api.deepseek.com'),
        'model' => env('GOAL_GUIDANCE_MODEL', 'deepseek-chat'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

];
