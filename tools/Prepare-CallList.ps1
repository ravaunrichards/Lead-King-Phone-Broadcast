[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InputPath,

    [string]$OutputPath,
    [string]$ConsentListPath,
    [string]$SuppressionListPath,
    [switch]$AllowSampleRows
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertFrom-TsvLine {
    param([Parameter(Mandatory = $true)][string]$Line)

    $fields = New-Object 'System.Collections.Generic.List[string]'
    $builder = New-Object System.Text.StringBuilder
    $insideQuotes = $false

    for ($i = 0; $i -lt $Line.Length; $i++) {
        $character = $Line[$i]

        if ($character -eq [char]34) {
            if ($insideQuotes -and $i + 1 -lt $Line.Length -and $Line[$i + 1] -eq [char]34) {
                $null = $builder.Append([char]34)
                $i++
            }
            else {
                $insideQuotes = -not $insideQuotes
            }
        }
        elseif ($character -eq [char]9 -and -not $insideQuotes) {
            $fields.Add($builder.ToString())
            $null = $builder.Clear()
        }
        else {
            $null = $builder.Append($character)
        }
    }

    if ($insideQuotes) {
        throw 'A tab-delimited line contains an unmatched quote. No output was written.'
    }

    $fields.Add($builder.ToString())
    return ,$fields.ToArray()
}

function ConvertTo-TsvField {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return ''
    }

    if ($Value.Contains([string][char]9) -or
        $Value.Contains([string][char]34) -or
        $Value.Contains([string][char]10) -or
        $Value.Contains([string][char]13)) {
        $quote = [string][char]34
        return $quote + $Value.Replace($quote, $quote + $quote) + $quote
    }

    return $Value
}

function Read-PhoneSet {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required list file not found: $Path"
    }

    $set = @{}
    $lineNumber = 0

    foreach ($line in [System.IO.File]::ReadAllLines((Resolve-Path -LiteralPath $Path).Path)) {
        $lineNumber++
        $value = $line.Trim()

        if ([string]::IsNullOrWhiteSpace($value) -or $value.StartsWith('#')) {
            continue
        }

        if ($value -notmatch '^\d{10}$') {
            throw "Invalid phone entry at line $lineNumber in $Path. Expected exactly 10 digits; values are not logged."
        }

        $set[$value] = $true
    }

    return $set
}

$resolvedInput = (Resolve-Path -LiteralPath $InputPath -ErrorAction Stop).Path
$lines = [System.IO.File]::ReadAllLines($resolvedInput, [System.Text.Encoding]::UTF8)
$lines = @($lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

if ($lines.Count -lt 1) {
    throw 'The input file is empty.'
}

$documented12 = @(
    'PHONE', 'COMPANY', 'CITY', 'ST', 'ZIP', 'CONTACTNAME',
    'SICDESCRIPTION', 'SICCODE', 'DATEDIALED', 'ACTION',
    'RECORDEDMESSAGE', 'CALLLOG'
)
$documented15 = $documented12 + @('UNDEFINED1', 'UNDEFINED2', 'UNDEFINED3')

$header = ConvertFrom-TsvLine -Line $lines[0]
$headerUpper = @($header | ForEach-Object { $_.Trim().ToUpperInvariant() })

if (($headerUpper -join '|') -ne ($documented12 -join '|') -and
    ($headerUpper -join '|') -ne ($documented15 -join '|')) {
    throw 'Unsupported call-list header. Expected the documented 12-column sample layout or the 15-column layout from ReadMe.txt.'
}

$inputColumnCount = $header.Count
$normalizedHeader = @($documented15)
$rows = New-Object 'System.Collections.Generic.List[object]'
$sampleCount = 0
$invalidCount = 0
$duplicateCount = 0
$seen = @{}
$listOptOuts = @{}

for ($lineIndex = 1; $lineIndex -lt $lines.Count; $lineIndex++) {
    $fields = ConvertFrom-TsvLine -Line $lines[$lineIndex]

    # The supplied sample has one surplus trailing tab on each data row.
    # Ignore exactly one surplus empty trailing field; retain all actual data.
    if ($fields.Count -eq ($inputColumnCount + 1) -and $fields[-1] -eq '') {
        $fields = @($fields[0..($fields.Count - 2)])
    }

    if ($fields.Count -ne $inputColumnCount) {
        throw "Column count mismatch at input line $($lineIndex + 1). No output was written."
    }

    if ($inputColumnCount -eq 12) {
        $fields = @($fields) + @('', '', '')
    }

    $phone = ([string]$fields[0]).Trim()
    $company = [string]$fields[1]
    $action = [string]$fields[9]

    if ($company -match '^TEST\s+CO(?:\s|#)') {
        $sampleCount++
    }

    if ($phone -notmatch '^\d{10}
        $duplicateCount++
        continue
    }

    $seen[$phone] = $true
    $rows.Add([pscustomobject]@{
        Fields = @($fields)
        Phone = $phone
        Action = $action
        Company = $company
    })
}

Write-Host "Input rows: $($lines.Count - 1)"
Write-Host "Documented input columns: $inputColumnCount"
Write-Host 'Prepared output schema: 15 columns'
Write-Host "Invalid phone rows: $invalidCount"
Write-Host "Duplicate phone rows: $duplicateCount"
Write-Host "Rows marked as sample/test companies: $sampleCount"

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    Write-Warning 'Audit-only mode. No call list was generated and no calls were made.'
    if ($sampleCount -gt 0) {
        Write-Warning 'Test-company rows were detected. They must not be treated as production contacts.'
    }
    return
}

if ($sampleCount -gt 0 -and -not $AllowSampleRows) {
    throw 'Output refused because sample/test-company records were found. Supply production records, or use -AllowSampleRows only for controlled testing.'
}

if ([string]::IsNullOrWhiteSpace($ConsentListPath) -or [string]::IsNullOrWhiteSpace($SuppressionListPath)) {
    throw 'Preparing an output file requires both an explicit consent list and a do-not-call suppression list.'
}

$consent = Read-PhoneSet -Path $ConsentListPath
$suppressed = Read-PhoneSet -Path $SuppressionListPath

# Any OptOut in the input suppresses the number, even if that OptOut was
# present on a duplicate row that was excluded from the output record list.
foreach ($phone in $listOptOuts.Keys) {
    $suppressed[$phone] = $true
}

# Existing OptOut outcomes on retained rows are also kept in suppression.
foreach ($record in $rows) {
    if ($record.Action.Trim().Equals('OptOut', [System.StringComparison]::OrdinalIgnoreCase)) {
        $suppressed[$record.Phone] = $true
    }
}

$eligible = New-Object 'System.Collections.Generic.List[object]'
$noConsentCount = 0
$suppressedCount = 0

foreach ($record in $rows) {
    if ($suppressed.ContainsKey($record.Phone)) {
        $suppressedCount++
        continue
    }

    if (-not $consent.ContainsKey($record.Phone)) {
        $noConsentCount++
        continue
    }

    $eligible.Add($record)
}

$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
if ($resolvedOutput.Equals($resolvedInput, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputPath must be different from InputPath. Original input is never overwritten.'
}

if (Test-Path -LiteralPath $resolvedOutput) {
    throw "Output file already exists; refusing to overwrite it: $resolvedOutput"
}

$outputDirectory = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    throw "Output directory does not exist: $outputDirectory. Initialize the private workspace first."
}

$outputLines = New-Object 'System.Collections.Generic.List[string]'
$headerLine = (($normalizedHeader | ForEach-Object { ConvertTo-TsvField -Value $_ }) -join ([string][char]9))
$outputLines.Add($headerLine)

foreach ($record in $eligible) {
    $escaped = @($record.Fields | ForEach-Object { ConvertTo-TsvField -Value ([string]$_) })
    $outputLines.Add(($escaped -join ([string][char]9)))
}

$encoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($resolvedOutput, $outputLines.ToArray(), $encoding)

Write-Host "Consent-approved rows written: $($eligible.Count)"
Write-Host "Rows blocked by missing consent: $noConsentCount"
Write-Host "Rows blocked by suppression or prior OptOut: $suppressedCount"
Write-Host "Output: $resolvedOutput"
Write-Warning 'This tool only prepares a tab-delimited file. It does not start BroadcastLite, place calls, or prove that the legacy application accepts the documented 15-column layout.'
) {
        $invalidCount++
        continue
    }

    # Capture OptOut before duplicate detection so a later duplicate OptOut
    # suppresses an earlier otherwise-eligible row for the same number.
    if ($action.Trim().Equals('OptOut', [System.StringComparison]::OrdinalIgnoreCase)) {
        $listOptOuts[$phone] = $true
    }

    if ($seen.ContainsKey($phone)) {
        $duplicateCount++
        continue
    }

    $seen[$phone] = $true
    $rows.Add([pscustomobject]@{
        Fields = @($fields)
        Phone = $phone
        Action = $action
        Company = $company
    })
}

Write-Host "Input rows: $($lines.Count - 1)"
Write-Host "Documented input columns: $inputColumnCount"
Write-Host 'Prepared output schema: 15 columns'
Write-Host "Invalid phone rows: $invalidCount"
Write-Host "Duplicate phone rows: $duplicateCount"
Write-Host "Rows marked as sample/test companies: $sampleCount"

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    Write-Warning 'Audit-only mode. No call list was generated and no calls were made.'
    if ($sampleCount -gt 0) {
        Write-Warning 'Test-company rows were detected. They must not be treated as production contacts.'
    }
    return
}

if ($sampleCount -gt 0 -and -not $AllowSampleRows) {
    throw 'Output refused because sample/test-company records were found. Supply production records, or use -AllowSampleRows only for controlled testing.'
}

if ([string]::IsNullOrWhiteSpace($ConsentListPath) -or [string]::IsNullOrWhiteSpace($SuppressionListPath)) {
    throw 'Preparing an output file requires both an explicit consent list and a do-not-call suppression list.'
}

$consent = Read-PhoneSet -Path $ConsentListPath
$suppressed = Read-PhoneSet -Path $SuppressionListPath

# Existing OptOut outcomes are always added to suppression.
foreach ($record in $rows) {
    if ($record.Action.Trim().Equals('OptOut', [System.StringComparison]::OrdinalIgnoreCase)) {
        $suppressed[$record.Phone] = $true
    }
}

$eligible = New-Object 'System.Collections.Generic.List[object]'
$noConsentCount = 0
$suppressedCount = 0

foreach ($record in $rows) {
    if ($suppressed.ContainsKey($record.Phone)) {
        $suppressedCount++
        continue
    }

    if (-not $consent.ContainsKey($record.Phone)) {
        $noConsentCount++
        continue
    }

    $eligible.Add($record)
}

$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
if ($resolvedOutput.Equals($resolvedInput, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputPath must be different from InputPath. Original input is never overwritten.'
}

if (Test-Path -LiteralPath $resolvedOutput) {
    throw "Output file already exists; refusing to overwrite it: $resolvedOutput"
}

$outputDirectory = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    throw "Output directory does not exist: $outputDirectory. Initialize the private workspace first."
}

$outputLines = New-Object 'System.Collections.Generic.List[string]'
$headerLine = (($normalizedHeader | ForEach-Object { ConvertTo-TsvField -Value $_ }) -join ([string][char]9))
$outputLines.Add($headerLine)

foreach ($record in $eligible) {
    $escaped = @($record.Fields | ForEach-Object { ConvertTo-TsvField -Value ([string]$_) })
    $outputLines.Add(($escaped -join ([string][char]9)))
}

$encoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($resolvedOutput, $outputLines.ToArray(), $encoding)

Write-Host "Consent-approved rows written: $($eligible.Count)"
Write-Host "Rows blocked by missing consent: $noConsentCount"
Write-Host "Rows blocked by suppression or prior OptOut: $suppressedCount"
Write-Host "Output: $resolvedOutput"
Write-Warning 'This tool only prepares a tab-delimited file. It does not start BroadcastLite, place calls, or prove that the legacy application accepts the documented 15-column layout.'
