[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Join-Path $PSScriptRoot '..')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-AssemblyIdentity {
    param([Parameter(Mandatory = $true)][string]$Path)

    $name = [System.Reflection.AssemblyName]::GetAssemblyName($Path)
    $tokenBytes = $name.GetPublicKeyToken()
    $token = if ($null -eq $tokenBytes -or $tokenBytes.Length -eq 0) {
        ''
    }
    else {
        ([System.BitConverter]::ToString($tokenBytes)).Replace('-', '').ToLowerInvariant()
    }

    [pscustomobject]@{
        Name = $name.Name
        Version = [string]$name.Version
        Culture = if ([string]::IsNullOrWhiteSpace($name.CultureName)) { 'neutral' } else { $name.CultureName }
        PublicKeyToken = $token
    }
}

function Get-PeMachine {
    param([Parameter(Mandatory = $true)][string]$Path)

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $reader = New-Object System.IO.BinaryReader($stream)
        if ($stream.Length -lt 64 -or
            [System.Text.Encoding]::ASCII.GetString($reader.ReadBytes(2)) -ne 'MZ') {
            throw "File is not a valid PE image: $Path"
        }

        $stream.Position = 0x3C
        $peOffset = $reader.ReadUInt32()
        if ($peOffset -gt ($stream.Length - 6)) {
            throw "PE header offset is outside the file: $Path"
        }

        $stream.Position = $peOffset
        $signature = [System.Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
        if ($signature -ne ('PE' + [char]0 + [char]0)) {
            throw "PE signature is missing: $Path"
        }

        $machine = $reader.ReadUInt16()
        switch ($machine) {
            0x014C { return 'x86' }
            0x8664 { return 'x64' }
            0xAA64 { return 'ARM64' }
            default { return ('unknown-0x{0:X4}' -f $machine) }
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Get-ClrExecutionTarget {
    param([Parameter(Mandatory = $true)][string]$Path)

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $reader = New-Object System.IO.BinaryReader($stream)
        if ($stream.Length -lt 64) {
            return [pscustomobject]@{ IsManaged = $false; Flags = $null; Target = 'No CLR header' }
        }

        $stream.Position = 0
        if ([System.Text.Encoding]::ASCII.GetString($reader.ReadBytes(2)) -ne 'MZ') {
            return [pscustomobject]@{ IsManaged = $false; Flags = $null; Target = 'No CLR header' }
        }

        $stream.Position = 0x3C
        $peOffset = [long]$reader.ReadUInt32()
        if ($peOffset -gt ($stream.Length - 26)) {
            throw "PE header offset is outside the file: $Path"
        }

        $stream.Position = $peOffset
        if ([System.Text.Encoding]::ASCII.GetString($reader.ReadBytes(4)) -ne ('PE' + [char]0 + [char]0)) {
            throw "PE signature is missing: $Path"
        }

        $null = $reader.ReadUInt16()
        $sectionCount = $reader.ReadUInt16()
        $null = $reader.ReadBytes(12)
        $optionalHeaderSize = $reader.ReadUInt16()
        $null = $reader.ReadUInt16()
        $optionalStart = $peOffset + 24
        $stream.Position = $optionalStart
        $optionalMagic = $reader.ReadUInt16()

        if ($optionalMagic -ne 0x010B -and $optionalMagic -ne 0x020B) {
            return [pscustomobject]@{ IsManaged = $false; Flags = $null; Target = 'No CLR header' }
        }

        $numberOfDirectoriesOffset = if ($optionalMagic -eq 0x010B) { 92 } else { 108 }
        $directoriesStart = if ($optionalMagic -eq 0x010B) { 96 } else { 112 }
        if ($optionalHeaderSize -lt ($directoriesStart + (15 * 8))) {
            return [pscustomobject]@{ IsManaged = $false; Flags = $null; Target = 'No CLR header' }
        }

        $stream.Position = $optionalStart + $numberOfDirectoriesOffset
        $numberOfDirectories = $reader.ReadUInt32()
        if ($numberOfDirectories -le 14) {
            return [pscustomobject]@{ IsManaged = $false; Flags = $null; Target = 'No CLR header' }
        }

        $stream.Position = $optionalStart + $directoriesStart + (14 * 8)
        $cliRva = [long]$reader.ReadUInt32()
        $cliSize = $reader.ReadUInt32()
        if ($cliRva -eq 0 -or $cliSize -lt 20) {
            return [pscustomobject]@{ IsManaged = $false; Flags = $null; Target = 'No CLR header' }
        }

        $sectionHeaders = $optionalStart + $optionalHeaderSize
        $cliFileOffset = $null
        for ($i = 0; $i -lt $sectionCount; $i++) {
            $stream.Position = $sectionHeaders + ($i * 40)
            $null = $reader.ReadBytes(8)
            $virtualSize = [long]$reader.ReadUInt32()
            $virtualAddress = [long]$reader.ReadUInt32()
            $rawSize = [long]$reader.ReadUInt32()
            $rawPointer = [long]$reader.ReadUInt32()
            $null = $reader.ReadBytes(16)

            $mappedSize = [Math]::Max($virtualSize, $rawSize)
            if ($cliRva -ge $virtualAddress -and $cliRva -lt ($virtualAddress + $mappedSize)) {
                $cliFileOffset = $rawPointer + ($cliRva - $virtualAddress)
                break
            }
        }

        if ($null -eq $cliFileOffset -or $cliFileOffset + 20 -gt $stream.Length) {
            return [pscustomobject]@{ IsManaged = $false; Flags = $null; Target = 'CLR header RVA could not be mapped' }
        }

        $stream.Position = $cliFileOffset + 16
        $flags = [uint32]$reader.ReadUInt32()
        $ilOnly = (($flags -band 0x00000001) -ne 0)
        $requires32Bit = (($flags -band 0x00000002) -ne 0)
        $prefers32Bit = (($flags -band 0x00020000) -ne 0)

        if (-not $ilOnly) {
            $target = 'Mixed-mode or native CLR image'
        }
        elseif ($requires32Bit) {
            $target = 'IL-only, 32-bit required'
        }
        elseif ($prefers32Bit) {
            $target = 'IL-only, prefers 32-bit'
        }
        else {
            $target = 'IL-only, AnyCPU-compatible'
        }

        return [pscustomobject]@{
            IsManaged = $true
            Flags = ('0x{0:X8}' -f $flags)
            Target = $target
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Assert-IdentityMatch {
    param(
        [Parameter(Mandatory = $true)]$Expected,
        [Parameter(Mandatory = $true)]$Actual,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if ($Expected.Name -ne $Actual.Name -or
        $Expected.Version -ne $Actual.Version -or
        $Expected.Culture -ne $Actual.Culture -or
        $Expected.PublicKeyToken -ne $Actual.PublicKeyToken) {
        throw "$Label does not match the VoIPSDK assembly identity required by BroadcastLite.exe."
    }
}

$root = [System.IO.Path]::GetFullPath($RepositoryRoot)
$appPath = Join-Path $root 'BroadcastLite.exe'
$x86ManagedPath = Join-Path $root 'VoIPSDK_x86\VoIPSDK_32bit.dll'
$x64ManagedPath = Join-Path $root 'VoIPSDK_x64\VoIPSDK_64bit.dll'
$x86NativePath = Join-Path $root 'VoIPSDK_x86\VoIPSDK_NativeLib_x86.dll'
$x64NativePath = Join-Path $root 'VoIPSDK_x64\VoIPSDK_NativeLib_x64.dll'
$rootManagedPath = Join-Path $root 'VoIPSDK.dll'

$required = @($appPath, $x86ManagedPath, $x64ManagedPath, $x86NativePath, $x64NativePath)
foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required SDK compatibility file is missing: $path"
    }
}

$appAssembly = [System.Reflection.Assembly]::ReflectionOnlyLoadFrom($appPath)
$voipReferences = @($appAssembly.GetReferencedAssemblies() | Where-Object { $_.Name -eq 'VoIPSDK' })
if ($voipReferences.Count -ne 1) {
    throw "Expected exactly one VoIPSDK assembly reference in BroadcastLite.exe; found $($voipReferences.Count)."
}

$expectedTokenBytes = $voipReferences[0].GetPublicKeyToken()
$expectedToken = if ($null -eq $expectedTokenBytes -or $expectedTokenBytes.Length -eq 0) {
    ''
}
else {
    ([System.BitConverter]::ToString($expectedTokenBytes)).Replace('-', '').ToLowerInvariant()
}

$expected = [pscustomobject]@{
    Name = $voipReferences[0].Name
    Version = [string]$voipReferences[0].Version
    Culture = if ([string]::IsNullOrWhiteSpace($voipReferences[0].CultureName)) { 'neutral' } else { $voipReferences[0].CultureName }
    PublicKeyToken = $expectedToken
}

$x86Managed = Get-AssemblyIdentity -Path $x86ManagedPath
$x64Managed = Get-AssemblyIdentity -Path $x64ManagedPath

Assert-IdentityMatch -Expected $expected -Actual $x86Managed -Label 'x86 managed wrapper'
Assert-IdentityMatch -Expected $expected -Actual $x64Managed -Label 'x64 managed wrapper'

$appClr = Get-ClrExecutionTarget -Path $appPath
$x86ManagedClr = Get-ClrExecutionTarget -Path $x86ManagedPath
$x64ManagedClr = Get-ClrExecutionTarget -Path $x64ManagedPath

if ($appClr.Target -ne 'IL-only, 32-bit required') {
    throw "BroadcastLite.exe execution target changed unexpectedly: $($appClr.Target)"
}
if ($x86ManagedClr.Target -ne 'IL-only, AnyCPU-compatible') {
    throw "The x86-folder managed wrapper has an unexpected CLR target: $($x86ManagedClr.Target)"
}
if ($x64ManagedClr.Target -ne 'IL-only, AnyCPU-compatible') {
    throw "The x64-folder managed wrapper has an unexpected CLR target: $($x64ManagedClr.Target)"
}

$x86Machine = Get-PeMachine -Path $x86NativePath
$x64Machine = Get-PeMachine -Path $x64NativePath
if ($x86Machine -ne 'x86') {
    throw "The x86 native library has the wrong architecture: $x86Machine"
}
if ($x64Machine -ne 'x64') {
    throw "The x64 native library has the wrong architecture: $x64Machine"
}

Write-Host ("PASS: BroadcastLite requires {0}, Version={1}, PublicKeyToken={2}" -f $expected.Name, $expected.Version, $expected.PublicKeyToken)
Write-Host ("PASS: BroadcastLite CLR target: {0} ({1})" -f $appClr.Target, $appClr.Flags)
Write-Host ("PASS: x86 managed wrapper CLR target: {0} ({1})" -f $x86ManagedClr.Target, $x86ManagedClr.Flags)
Write-Host ("PASS: x64 managed wrapper CLR target: {0} ({1})" -f $x64ManagedClr.Target, $x64ManagedClr.Flags)
Write-Host ("PASS: x86 managed wrapper identity matches: {0}, Version={1}" -f $x86Managed.Name, $x86Managed.Version)
Write-Host ("PASS: x64 managed wrapper identity matches: {0}, Version={1}" -f $x64Managed.Name, $x64Managed.Version)
Write-Host ("PASS: x86 native library machine type: {0}" -f $x86Machine)
Write-Host ("PASS: x64 native library machine type: {0}" -f $x64Machine)
Write-Host 'PASS: the 32-bit BroadcastLite process must use the x86 native SDK library.'

if (Test-Path -LiteralPath $rootManagedPath -PathType Leaf) {
    try {
        $rootAssembly = Get-AssemblyIdentity -Path $rootManagedPath
        Write-Host ("Root VoIPSDK.dll assembly identity: {0}, Version={1}" -f $rootAssembly.Name, $rootAssembly.Version)
    }
    catch {
        $rootSize = (Get-Item -LiteralPath $rootManagedPath).Length
        Write-Warning "Root VoIPSDK.dll is not a readable managed assembly (size: $rootSize bytes). This test does not replace it."
    }
}
else {
    Write-Warning 'Root VoIPSDK.dll is absent. This test does not create or replace it.'
}

Write-Warning 'This verifies assembly identity and PE machine types only. It does not verify third-party licensing, runtime dependency resolution, native loading, SIP registration or call quality.'
