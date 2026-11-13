[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'Prepare-CallList.ps1'
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "Call-list preparation tool not found: $scriptPath"
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("BroadcastLite-CallList-Test-" + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $tempRoot

try {
    $inputFile = Join-Path $tempRoot 'input.tsv'
    $consentFile = Join-Path $tempRoot 'consent.txt'
    $suppressionFile = Join-Path $tempRoot 'suppression.txt'
    $outputFile = Join-Path $tempRoot 'output.tsv'
    $tab = [string][char]9

    $header = (@('PHONE','COMPANY','CITY','ST','ZIP','CONTACTNAME','SICDESCRIPTION','SICCODE','DATEDIALED','ACTION','RECORDEDMESSAGE','CALLLOG','UNDEFINED1','UNDEFINED2','UNDEFINED3') -join $tab)
    $rows = @(
        (@('2025550101','Synthetic Accepted','TEST','TS','00000','','','','','','','','','','') -join $tab),
        (@('2025550102','Synthetic Suppressed','TEST','TS','00000','','','','','','','','','','') -join $tab),
        (@('2025550103','Synthetic No Consent','TEST','TS','00000','','','','','','','','','','') -join $tab),
        (@('2025550104','Synthetic Prior OptOut','TEST','TS','00000','','','','','OptOut','','','','','') -join $tab),
        (@('2025550101','Synthetic Duplicate','TEST','TS','00000','','','','','','','','','','') -join $tab)
    )

    [System.IO.File]::WriteAllLines($inputFile, (@($header) + $rows), (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllLines($consentFile, @('2025550101','2025550102','2025550104'), (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllLines($suppressionFile, @('2025550102'), (New-Object System.Text.UTF8Encoding($false)))

    $beforeHash = (Get-FileHash -LiteralPath $inputFile -Algorithm SHA256).Hash

    & $scriptPath -InputPath $inputFile -ConsentListPath $consentFile -SuppressionListPath $suppressionFile -OutputPath $outputFile

    if (-not (Test-Path -LiteralPath $outputFile -PathType Leaf)) {
        throw 'FAIL: expected output file was not created.'
    }

    $afterHash = (Get-FileHash -LiteralPath $inputFile -Algorithm SHA256).Hash
    if ($beforeHash -ne $afterHash) {
        throw 'FAIL: original input changed.'
    }

    $outputLines = [System.IO.File]::ReadAllLines($outputFile)
    if ($outputLines.Count -ne 2) {
        throw "FAIL: expected header plus one approved row; found $($outputLines.Count) lines."
    }

    $outputHeader = $outputLines[0].Split([char]9)
    $outputRow = $outputLines[1].Split([char]9)

    if ($outputHeader.Count -ne 15 -or $outputRow.Count -ne 15) {
        throw 'FAIL: output did not contain exactly 15 columns.'
    }

    if ($outputRow[0] -ne '2025550101') {
        throw 'FAIL: the expected consent-approved synthetic row was not the only output recipient.'
    }

    if (($outputLines -join [Environment]::NewLine) -match '2025550102|2025550103|2025550104') {
        throw 'FAIL: suppression, missing consent or prior OptOut was not applied.'
    }

    Write-Host 'PASS: consent-approved synthetic row retained.'
    Write-Host 'PASS: explicit suppression, missing consent and prior OptOut excluded.'
    Write-Host 'PASS: duplicate phone row excluded.'
    Write-Host 'PASS: output has exactly 15 columns.'
    Write-Host 'PASS: original input hash unchanged.'
    Write-Host 'All call-list tests passed. No calls were placed.'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
