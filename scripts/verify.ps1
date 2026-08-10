$ErrorActionPreference = 'Stop'

Push-Location "$PSScriptRoot\..\apps\soulbuddy"
try {
  flutter analyze
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  flutter test
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  flutter build web --debug
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
  Pop-Location
}

Push-Location "$PSScriptRoot\..\services\api"
try {
  composer validate --strict --no-check-publish
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  vendor\bin\pint --test
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  php artisan test
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
  Pop-Location
}
