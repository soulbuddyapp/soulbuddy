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
    throw "No matching ChromeDriver is published for Chrome $chromeVersion."
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

$driverProcess = $null
$driverAlreadyRunning = Get-NetTCPConnection `
  -State Listen `
  -LocalPort 4444 `
  -ErrorAction SilentlyContinue
if (-not $driverAlreadyRunning) {
  $driverProcess = Start-Process `
    -FilePath $driverExecutable `
    -ArgumentList '--port=4444', '--allowed-origins=*' `
    -WindowStyle Hidden `
    -PassThru
  Start-Sleep -Seconds 1
}

Push-Location "$PSScriptRoot\..\apps\soulbuddy"
try {
  flutter drive `
    -d chrome `
    --driver=test_driver/integration_test.dart `
    --target=integration_test/offline_encounter_flow_test.dart `
    --headless `
    --browser-dimension=390x844
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
  Pop-Location
  if ($driverProcess -ne $null -and -not $driverProcess.HasExited) {
    Stop-Process -Id $driverProcess.Id
  }
}
