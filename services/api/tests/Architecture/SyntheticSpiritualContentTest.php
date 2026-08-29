<?php

it('has no server runtime synthetic prayer generation surface', function () {
    $root = dirname(__DIR__, 2);
    $app = $root.DIRECTORY_SEPARATOR.'app';
    $markers = [
        'PrayerDraftProvider',
        'GeneratePrayerDraft',
        'DeepSeekPrayerDraftProvider',
        'PrayerDraftController',
        'PrayerDraftAttemptController',
    ];
    $found = [];
    $files = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($app, FilesystemIterator::SKIP_DOTS),
    );

    foreach ($files as $file) {
        if (! $file->isFile() || $file->getExtension() !== 'php') {
            continue;
        }
        $content = file_get_contents($file->getPathname());
        if (! is_string($content)) {
            continue;
        }
        foreach ($markers as $marker) {
            if (! str_contains($content, $marker)) {
                continue;
            }
            $relative = substr($file->getPathname(), strlen($root) + 1);
            $found[] = str_replace(DIRECTORY_SEPARATOR, '/', $relative);
            break;
        }
    }

    sort($found);
    expect($found)->toBe([]);

    $routes = file_get_contents($root.'/routes/api.php');
    expect($routes)->toBeString()->not->toContain('/prayer-drafts');

    $services = file_get_contents($root.'/config/services.php');
    expect($services)
        ->toBeString()
        ->not->toContain("'deepseek'")
        ->not->toContain('DEEPSEEK_')
        ->not->toContain('PRAYER_GENERATION_ENABLED')
        ->not->toContain('PRAYER_DRAFT_');

    $environment = file_get_contents($root.'/.env.example');
    expect($environment)
        ->toBeString()
        ->not->toContain('AI_PROVIDER')
        ->not->toContain('DEEPSEEK_')
        ->not->toContain('PRAYER_GENERATION_ENABLED')
        ->not->toContain('PRAYER_DRAFT_');
});
