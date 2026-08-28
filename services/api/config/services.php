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

    'deepseek' => [
        'provider' => env('AI_PROVIDER', 'deepseek'),
        'key' => env('DEEPSEEK_API_KEY'),
        'base_url' => env('DEEPSEEK_BASE_URL', 'https://api.deepseek.com'),
        'model' => env('DEEPSEEK_MODEL', 'deepseek-v4-flash'),
        'prompt_version' => env('PRAYER_DRAFT_PROMPT_VERSION', '1'),
        'disclosure_version' => env('PRAYER_DRAFT_DISCLOSURE_VERSION', 'deepseek-1'),
        'prayer_generation_enabled' => env('PRAYER_GENERATION_ENABLED', true),
    ],

    'deepgram' => [
        'key' => env('DEEPGRAM_API_KEY'),
        'base_url' => env('DEEPGRAM_BASE_URL', 'https://api.deepgram.com'),
        'model' => env('DEEPGRAM_TTS_MODEL', 'aura-2-thalia-en'),
        'encoding' => env('DEEPGRAM_TTS_ENCODING', 'mp3'),
        'bit_rate' => (int) env('DEEPGRAM_TTS_BIT_RATE', 32000),
        'disclosure_version' => env('PRAYER_NARRATION_DISCLOSURE_VERSION', 'deepgram-aura2-1'),
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
