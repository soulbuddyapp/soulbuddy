#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$targets = @(
    'C:\Users\Son\.cursor',
    'C:\Users\Son\.claude',
    'C:\Users\Son\.copilot',
    'C:\Users\Son\AppData\Roaming\Cursor',
    'C:\Users\Son\AppData\Roaming\Claude',
    'C:\Users\Son\AppData\Local\Claude',
    'C:\Users\Son\AppData\Local\Claude Nest-3p',
    'C:\Users\Son\AppData\Local\Claude-3p',
    'C:\Users\Son\AppData\Local\claude-cli-nodejs',
    'C:\ProgramData\Claude',
    'C:\Users\Son\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Anthropic',
    'C:\Users\Son\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Thorium Apps\Claude.lnk',
    'C:\Users\Son\AppData\Local\Temp\copilot_setup.log',
    'C:\Users\Son\AppData\Local\Temp\jiti\oauth-anthropic.87af3de6.cjs',
    'C:\Users\Son\AppData\Local\Temp\jiti\oauth-github-copilot.ae13a155.cjs',
    'C:\Users\Son\AppData\Local\Temp\jiti\providers-anthropic.d4732c0e.cjs',
    'C:\Users\Son\AppData\Local\Temp\jiti\providers-github-copilot-headers.9b181b13.cjs'
)

$allowedRoots = @(
    'C:\Users\Son\.cursor',
    'C:\Users\Son\.claude',
    'C:\Users\Son\.copilot',
    'C:\Users\Son\AppData',
    'C:\ProgramData\Claude'
)

function Get-TargetSize([string] $Path) {
    $item = Get-Item -LiteralPath $Path -Force
    if (-not $item.PSIsContainer) {
        return [int64] $item.Length
    }
    return [int64] ((Get-ChildItem -LiteralPath $Path -Force -Recurse -File -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum).Sum)
}

$driveBefore = (Get-PSDrive -Name C).Free
$removedBytes = [int64] 0

foreach ($target in $targets) {
    if (-not (Test-Path -LiteralPath $target)) {
        Write-Host "Absent: $target" -ForegroundColor DarkGray
        continue
    }

    $resolved = (Resolve-Path -LiteralPath $target).Path
    $isAllowed = $false
    foreach ($root in $allowedRoots) {
        if ($resolved.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
            $isAllowed = $true
            break
        }
    }
    if (-not $isAllowed) {
        throw "Refusing to remove a path outside the approved targets: $resolved"
    }

    $size = Get-TargetSize $resolved
    if ($PSCmdlet.ShouldProcess($resolved, 'Permanently remove retired AI tool data')) {
        Remove-Item -LiteralPath $resolved -Force -Recurse
        $removedBytes += $size
        Write-Host ('Removed: {0} ({1:N2} GB)' -f $resolved, ($size / 1GB)) -ForegroundColor Green
    }
}

$driveAfter = (Get-PSDrive -Name C).Free
Write-Host ''
Write-Host ('Removed data: {0:N2} GB' -f ($removedBytes / 1GB))
Write-Host ('C: free space: {0:N2} GB -> {1:N2} GB' -f ($driveBefore / 1GB), ($driveAfter / 1GB))
