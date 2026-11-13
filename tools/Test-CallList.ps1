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
$tab = [string][char]9
$encoding = New-Object System.Text.UTF8Encoding($false)

try {
    $consentFile = Join-Path $tempRoot 'consent.txt'
    $suppressionFile = Join-Path $tempRoot 'suppression.txt'
    [System.IO.File]::WriteAllLines($consentFile, @('2025550101','2025550102','2025550104'), $encoding)
    [System.IO.File]::WriteAllLines($suppressionFile, @('2025550102'), $encoding)

    # Test the 15-column README schema and its consent/opt-out protections.
    $input15 = Join-Path $tempRoot 'input-15.tsv'
    $output15 = Join-Path $tempRoot 'output-15.tsv'
    $header15 = (@('PHONE','COMPANY','CITY','ST','ZIP','CONTACTNAME','SICDESCRIPTION','SICCODE','DATEDIALED','ACTION','RECORDEDMESSAGE','CALLLOG','UNDEFINED1','UNDEFINED2','UNDEFINED3') -join $tab)
    $rows15 = @(
        (@('2025550101','Synthetic Accepted','TEST','TS','00000','','','','','','','','','','') -join $tab),
        (@('2025550102','Synthetic Suppressed','TEST','TS','00000','','','','','','','','','','') -join $tab),
        (@('2025550103','Synthetic No Consent','TEST','TS','00000','','','','','','','','','','') -join $tab),
        (@('2025550104','Synthetic Prior OptOut','TEST','TS','00000','','','','','OptOut','','','','','') -join $tab),
        (@('2025550101','Synthetic Duplicate','TEST','TS','00000','','','','','','','','','','') -join $tab),
        (@('NOT-A-NUMBER','Synthetic Invalid','TEST','TS','00000','','','','','','','','','','') -join $tab)
    )
    [System.IO.File]::WriteAllLines($input15, (@($header15) + $rows15), $encoding)
    $beforeHash15 = (Get-FileHash -LiteralPath $input15 -Algorithm SHA256).Hash

    & $scriptPath -InputPath $input15 -ConsentListPath $consentFile -SuppressionListPath $suppressionFile -OutputPath $output15

    if (-not (Test-Path -LiteralPath $output15 -PathType Leaf)) {
        throw 'FAIL: 15-column input did not create an output file.'
    }
    if ((Get-FileHash -LiteralPath $input15 -Algorithm SHA256).Hash -ne $beforeHash15) {
        throw 'FAIL: 15-column original input changed.'
    }

    $result15 = [System.IO.File]::ReadAllLines($output15)
    if ($result15.Count -ne 2) {
        throw "FAIL: expected one approved 15-column row; found $($result15.Count - 1)."
    }
    if ($result15[0].Split([char]9).Count -ne 15 -or $result15[1].Split([char]9).Count -ne 15) {
        throw 'FAIL: 15-column source did not produce a 15-column output.'
    }
    if ($result15[1].Split([char]9)[0] -ne '2025550101') {
        throw 'FAIL: wrong row retained from the 15-column test.'
    }

    # Test the actual 12-column sample shape, including its extra trailing tab.
    $input12 = Join-Path $tempRoot 'input-12.tsv'
    $output12 = Join-Path $tempRoot 'output-12.tsv'
    $header12 = (@('PHONE','COMPANY','CITY','ST','ZIP','CONTACTNAME','SICDESCRIPTION','SICCODE','DATEDIALED','ACTION','RECORDEDMESSAGE','CALLLOG') -join $tab)
    $rows12 = @(
        ((@('2025550101','Synthetic Twelve Column Accepted','TEST','TS','00000','','','','','','','') -join $tab) + $tab),
        ((@('2025550102','Synthetic Twelve Column Suppressed','TEST','TS','00000','','','','','','','') -join $tab) + $tab),
        ((@('2025550103','Synthetic Twelve Column No Consent','TEST','TS','00000','','','','','','','') -join $tab) + $tab),
        ((@('2025550104','Synthetic Twelve Column OptOut','TEST','TS','00000','','','','','OptOut','','') -join $tab) + $tab),
        ((@('NOT-A-NUMBER','Synthetic Twelve Column Invalid','TEST','TS','00000','','','','','','','') -join $tab) + $tab)
    )
    [System.IO.File]::WriteAllLines($input12, (@($header12) + $rows12), $encoding)
    $beforeHash12 = (Get-FileHash -LiteralPath $input12 -Algorithm SHA256).Hash

    & $scriptPath -InputPath $input12 -ConsentListPath $consentFile -SuppressionListPath $suppressionFile -OutputPath $output12

    if (-not (Test-Path -LiteralPath $output12 -PathType Leaf)) {
        throw 'FAIL: 12-column input did not create an output file.'
    }
    if ((Get-FileHash -LiteralPath $input12 -Algorithm SHA256).Hash -ne $beforeHash12) {
        throw 'FAIL: 12-column original input changed.'
    }

    $result12 = [System.IO.File]::ReadAllLines($output12)
    if ($result12.Count -ne 2) {
        throw "FAIL: expected one approved 12-column row; found $($result12.Count - 1)."
    }
    if ($result12[0].Split([char]9).Count -ne 15 -or $result12[1].Split([char]9).Count -ne 15) {
        throw 'FAIL: 12-column source did not normalize to exactly 15 columns.'
    }
    if ($result12[1].Split([char]9)[0] -ne '2025550101') {
        throw 'FAIL: wrong row retained from the 12-column test.'
    }
    if ($result12[1].Split([char]9)[12] -ne '' -or
        $result12[1].Split([char]9)[13] -ne '' -or
        $result12[1].Split([char]9)[14] -ne '') {
        throw 'FAIL: the three absent legacy fields were not padded with empty values.'
    }

    # Test that TEST CO example rows cannot be prepared as production records.
    $sampleInput = Join-Path $tempRoot 'sample-test-co.tsv'
    $sampleOutput = Join-Path $tempRoot 'sample-output.tsv'
    $sampleHeader = $header12
    $sampleRow = ((@('7025551111','TEST CO #01','HENDERSON','NV','89074','','','','','','','') -join $tab) + $tab)
    [System.IO.File]::WriteAllLines($sampleInput, @($sampleHeader,$sampleRow), $encoding)

    $sampleRefused = $false
    try {
        & $scriptPath -InputPath $sampleInput -ConsentListPath $consentFile -SuppressionListPath $suppressionFile -OutputPath $sampleOutput
    }
    catch {
        $sampleRefused = $true
    }
    if (-not $sampleRefused) {
        throw 'FAIL: sample TEST CO rows were not refused by default.'
    }
    if (Test-Path -LiteralPath $sampleOutput) {
        throw 'FAIL: an output file was created from the sample TEST CO data.'
    }

    # Existing outputs must never be overwritten.
    $existingContent = [System.IO.File]::ReadAllText($output15)
    $overwriteRefused = $false
    try {
        & $scriptPath -InputPath $input15 -ConsentListPath $consentFile -SuppressionListPath $suppressionFile -OutputPath $output15
    }
    catch {
        $overwriteRefused = $true
    }
    if (-not $overwriteRefused) {
        throw 'FAIL: existing output was not protected from overwrite.'
    }
    if ([System.IO.File]::ReadAllText($output15) -ne $existingContent) {
        throw 'FAIL: existing output content changed during overwrite test.'
    }

    Write-Host 'PASS: 15-column input validation and output.'
    Write-Host 'PASS: 12-column input with surplus trailing tab normalizes to 15 columns.'
    Write-Host 'PASS: absent legacy columns are padded with empty values.'
    Write-Host 'PASS: invalid, duplicate, suppressed, no-consent and prior OptOut rows are excluded.'
    Write-Host 'PASS: TEST CO sample records are refused by default.'
    Write-Host 'PASS: existing outputs and original inputs remain unchanged.'
    Write-Host 'All call-list regression tests passed. No calls were placed.'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
