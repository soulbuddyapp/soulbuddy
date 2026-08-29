param(
  [string]$ChromePath = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
)

$ErrorActionPreference = 'Stop'

$resolvedChrome = (Resolve-Path -LiteralPath $ChromePath -ErrorAction Stop).Path
$chromeVersion = (Get-Item -LiteralPath $resolvedChrome).VersionInfo.FileVersion
$driverRoot = Join-Path $env:TEMP "soulbuddy-chromedriver-$chromeVersion"
$driverExecutable = Join-Path $driverRoot 'chromedriver-win64\chromedriver.exe'

if (-not (Test-Path -LiteralPath $driverExecutable -PathType Leaf)) {
  New-Item -ItemType Directory -Path $driverRoot -Force | Out-Null
  $manifest = Invoke-RestMethod `
    'https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json'
  $versionEntry = $manifest.versions | Where-Object version -eq $chromeVersion
  if (-not $versionEntry) {
    $build = ($chromeVersion -split '\.')[0..2] -join '.'
    $buildManifest = Invoke-RestMethod `
      'https://googlechromelabs.github.io/chrome-for-testing/latest-patch-versions-per-build-with-downloads.json'
    $buildEntry = $buildManifest.builds.$build
    if (-not $buildEntry) {
      throw "No compatible ChromeDriver is published for Chrome $chromeVersion."
    }
    $versionEntry = $buildEntry
  }
  $download = $versionEntry.downloads.chromedriver |
    Where-Object platform -eq 'win64' |
    Select-Object -First 1
  if (-not $download) {
    throw "No Windows ChromeDriver is published for Chrome $chromeVersion."
  }

  $archive = Join-Path $driverRoot 'chromedriver.zip'
  Invoke-WebRequest -UseBasicParsing $download.url -OutFile $archive
  Expand-Archive -LiteralPath $archive -DestinationPath $driverRoot -Force
}

$driverListener = Get-NetTCPConnection `
  -State Listen `
  -LocalPort 4444 `
  -ErrorAction SilentlyContinue |
  Select-Object -First 1
if ($driverListener) {
  $listenerProcess = Get-Process `
    -Id $driverListener.OwningProcess `
    -ErrorAction Stop
  if ($listenerProcess.Path -ne $driverExecutable) {
    throw "Port 4444 is owned by an unexpected process."
  }
  Stop-Process -Id $listenerProcess.Id -Force
  $listenerProcess.WaitForExit()
}
$driverProcess = Start-Process `
  -FilePath $driverExecutable `
  -ArgumentList '--port=4444', '--allowed-origins=*' `
  -WindowStyle Hidden `
  -PassThru
Start-Sleep -Seconds 1

Push-Location "$PSScriptRoot\..\apps\soulbuddy"
try {
  $targets = @(
    'integration_test/offline_encounter_flow_test.dart',
    'integration_test/offline_audio_memory_flow_test.dart',
    'integration_test/offline_prayer_flow_test.dart',
    'integration_test/prayer_reminder_flow_test.dart'
  )

  foreach ($target in $targets) {
    Write-Host "Running $target"
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    flutter drive `
      -d chrome `
      --driver=test_driver/integration_test.dart `
      --target=$target `
      --headless `
      --no-web-resources-cdn `
      --browser-dimension=390x844 `
      --web-browser-flag=--autoplay-policy=no-user-gesture-required `
      --web-browser-flag=--use-fake-device-for-media-stream `
      --web-browser-flag=--use-fake-ui-for-media-stream
    $targetExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($targetExitCode -ne 0) { exit $targetExitCode }
  }
} finally {
  Pop-Location
  if ($driverProcess -ne $null -and -not $driverProcess.HasExited) {
    Stop-Process -Id $driverProcess.Id
  }
}
