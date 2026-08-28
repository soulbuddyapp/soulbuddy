<?php

it('keeps legacy synthetic prayer generation inside its reviewed boundary', function () {
    $markers = ['PrayerDraftProvider', 'GeneratePrayerDraft'];
    $allowed = [
        'app/Domain/PrayerDrafts/DeepSeekPrayerDraftProvider.php',
        'app/Domain/PrayerDrafts/GeneratePrayerDraft.php',
        'app/Domain/PrayerDrafts/PrayerDraftProvider.php',
        'app/Http/Controllers/Api/PrayerDraftController.php',
        'app/Http/Requests/GeneratePrayerDraftRequest.php',
        'app/Providers/AppServiceProvider.php',
    ];
    $found = [];
    $files = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator(app_path(), FilesystemIterator::SKIP_DOTS),
    );

    foreach ($files as $file) {
        if (! $file->isFile() || $file->getExtension() !== 'php') {
            continue;
        }
        $content = file_get_contents($file->getPathname());
        if (! is_string($content)) {
            continue;
        }
        $matchesLegacyBoundary = false;
        foreach ($markers as $marker) {
            if (str_contains($content, $marker)) {
                $matchesLegacyBoundary = true;
                break;
            }
        }
        if (! $matchesLegacyBoundary) {
            continue;
        }
        $relative = substr($file->getPathname(), strlen(app_path()) + 1);
        $found[] = 'app/'.str_replace(DIRECTORY_SEPARATOR, '/', $relative);
    }

    sort($found);
    sort($allowed);

    expect($found)->toBe($allowed);
});
