[CmdletBinding(SupportsShouldProcess = $true)]
param([string]$Root = $null)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Root)) {
    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        throw 'LOCALAPPDATA is unavailable. Supply -Root with a private local folder.'
    }
    $Root = Join-Path $env:LOCALAPPDATA 'LeadKing\BroadcastLite'
}

$rootFull = [System.IO.Path]::GetFullPath($Root)
$repoFull = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repoPrefix = $repoFull.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

if ($rootFull.Equals($repoFull, [System.StringComparison]::OrdinalIgnoreCase) -or
    $rootFull.StartsWith($repoPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Runtime data must not be created inside the Git repository. Use a private local-data folder outside the repository.'
}

$directories = @(
    'Audio\Introduction_Messages',
    'Audio\Pre_Introduction_Messages',
    'Audio\Pre_Leave_Message_Prompts',
    'Audio\Leave_Message_Prompts',
    'Audio\Test_Audio',
    'Audio\Call_Announcements',
    'Recordings\Recorded_Messages',
    'Recordings\Call_Recordings',
    'Recordings\Archived_Messages',
    'Recordings\Failed_Recordings',
    'Call_Lists\Imports',
    'Call_Lists\Examples',
    'Call_Lists\Processed',
    'Call_Lists\Exports',
    'Configuration',
    'Logs',
    'Backups'
)

$created = 0
$alreadyPresent = 0

foreach ($relativePath in $directories) {
    $target = Join-Path $rootFull $relativePath

    if (-not $PSCmdlet.ShouldProcess($target, 'Create missing directory')) {
        continue
    }

    if (Test-Path -LiteralPath $target) {
        $item = Get-Item -LiteralPath $target -Force
        if (-not $item.PSIsContainer) {
            throw "A file already occupies a required directory path: $target"
        }
        $alreadyPresent++
        continue
    }

    New-Item -ItemType Directory -Path $target -Force | Out-Null
    $created++
}

Write-Host "Workspace: $rootFull"
Write-Host "Directories created: $created"
Write-Host "Directories already present: $alreadyPresent"
Write-Host 'No existing files were moved, renamed, overwritten, or deleted.'
Write-Warning 'Keep this workspace private. Do not commit customer lists, credentials, message recordings, or call recordings to GitHub.'
