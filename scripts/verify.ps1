$ErrorActionPreference = 'Stop'

Push-Location "$PSScriptRoot\..\apps\soulbuddy"
try {
  flutter analyze
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  flutter test
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
  Pop-Location
}

Push-Location "$PSScriptRoot\..\services\api"
try {
  php artisan test
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
  Pop-Location
}
