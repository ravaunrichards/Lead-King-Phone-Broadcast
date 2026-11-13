[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Join-Path $PSScriptRoot '..')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PeMetadata {
    param([Parameter(Mandatory = $true)][string]$Path)

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $reader = New-Object System.IO.BinaryReader($stream)
        if ($stream.Length -lt 64) {
            return [pscustomobject]@{ Path = $Path; IsPE = $false; Reason = 'File is too small for a PE header' }
        }

        $dos = $reader.ReadBytes(2)
        if ([System.Text.Encoding]::ASCII.GetString($dos) -ne 'MZ') {
            return [pscustomobject]@{ Path = $Path; IsPE = $false; Reason = 'Missing MZ signature' }
        }

        $stream.Position = 0x3C
        $peOffset = $reader.ReadUInt32()
        if ($peOffset -gt ($stream.Length - 26)) {
            return [pscustomobject]@{ Path = $Path; IsPE = $false; Reason = 'PE header offset is outside the file' }
        }

        $stream.Position = $peOffset
        $signature = [System.Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
        if ($signature -ne ('PE' + [char]0 + [char]0)) {
            return [pscustomobject]@{ Path = $Path; IsPE = $false; Reason = 'Missing PE signature' }
        }

        $machine = $reader.ReadUInt16()
        $sectionCount = $reader.ReadUInt16()
        $null = $reader.ReadUInt32()
        $null = $reader.ReadUInt32()
        $null = $reader.ReadUInt32()
        $optionalHeaderSize = $reader.ReadUInt16()
        $null = $reader.ReadUInt16()
        $optionalHeaderStart = [long]$peOffset + 24
        $optionalMagic = 0
        if ($optionalHeaderSize -ge 2) {
            $stream.Position = $optionalHeaderStart
            $optionalMagic = $reader.ReadUInt16()
        }

        $architecture = switch ($machine) {
            0x014C { 'x86' }
            0x8664 { 'x64' }
            0xAA64 { 'ARM64' }
            default { 'Unknown (0x{0:X4})' -f $machine }
        }

        $format = switch ($optionalMagic) {
            0x010B { 'PE32' }
            0x020B { 'PE32+' }
            default { 'Unknown (0x{0:X4})' -f $optionalMagic }
        }

        $isManaged = $false
        $clrFlags = $null
        $managedTarget = 'No CLR header'

        if ($optionalMagic -eq 0x010B -or $optionalMagic -eq 0x020B) {
            $numberOfDirectoriesOffset = if ($optionalMagic -eq 0x010B) { 92 } else { 108 }
            $directoriesStart = if ($optionalMagic -eq 0x010B) { 96 } else { 112 }

            if ($optionalHeaderSize -ge ($directoriesStart + (15 * 8))) {
                $stream.Position = $optionalHeaderStart + $numberOfDirectoriesOffset
                $numberOfDirectories = $reader.ReadUInt32()

                if ($numberOfDirectories -gt 14) {
                    $stream.Position = $optionalHeaderStart + $directoriesStart + (14 * 8)
                    $cliRva = $reader.ReadUInt32()
                    $cliSize = $reader.ReadUInt32()

                    if ($cliRva -gt 0 -and $cliSize -ge 20) {
                        $sectionHeaderStart = $optionalHeaderStart + $optionalHeaderSize
                        $cliFileOffset = $null

                        for ($sectionIndex = 0; $sectionIndex -lt $sectionCount; $sectionIndex++) {
                            $stream.Position = $sectionHeaderStart + ($sectionIndex * 40)
                            $null = $reader.ReadBytes(8)
                            $virtualSize = $reader.ReadUInt32()
                            $virtualAddress = $reader.ReadUInt32()
                            $rawSize = $reader.ReadUInt32()
                            $rawPointer = $reader.ReadUInt32()
                            $null = $reader.ReadBytes(16)

                            $mappedSize = [Math]::Max([long]$virtualSize, [long]$rawSize)
                            if ([long]$cliRva -ge [long]$virtualAddress -and
                                [long]$cliRva -lt ([long]$virtualAddress + $mappedSize)) {
                                $cliFileOffset = [long]$rawPointer + ([long]$cliRva - [long]$virtualAddress)
                                break
                            }
                        }

                        if ($null -ne $cliFileOffset -and $cliFileOffset + 20 -le $stream.Length) {
                            $stream.Position = $cliFileOffset + 16
                            $clrFlags = $reader.ReadUInt32()
                            $isManaged = $true

                            $ilOnly = (($clrFlags -band 0x00000001) -ne 0)
                            $requires32Bit = (($clrFlags -band 0x00000002) -ne 0)
                            $prefers32Bit = (($clrFlags -band 0x00020000) -ne 0)

                            if (-not $ilOnly) {
                                $managedTarget = 'Mixed-mode or native CLR image'
                            }
                            elseif ($requires32Bit) {
                                $managedTarget = 'IL-only, 32-bit required'
                            }
                            elseif ($prefers32Bit) {
                                $managedTarget = 'IL-only, prefers 32-bit'
                            }
                            else {
                                $managedTarget = 'IL-only, AnyCPU-compatible'
                            }
                        }
                    }
                }
            }
        }

        return [pscustomobject]@{
            Path = $Path
            IsPE = $true
            Architecture = $architecture
            OptionalHeader = $format
            SectionCount = $sectionCount
            IsManagedAssembly = $isManaged
            CLRFlags = if ($null -ne $clrFlags) { '0x{0:X8}' -f $clrFlags } else { '' }
            ManagedTarget = $managedTarget
            SizeBytes = $stream.Length
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Get-AssemblyMetadata {
    param([Parameter(Mandatory = $true)][string]$Path)

    try {
        $name = [System.Reflection.AssemblyName]::GetAssemblyName($Path)
        $tokenBytes = $name.GetPublicKeyToken()
        $token = if ($null -eq $tokenBytes -or $tokenBytes.Length -eq 0) {
            'none'
        }
        else {
            ([System.BitConverter]::ToString($tokenBytes)).Replace('-', '').ToLowerInvariant()
        }

        $references = @()
        try {
            # ReflectionOnlyLoadFrom reads managed metadata and references only.
            # It does not invoke the assembly entry point or execute its code.
            $assembly = [System.Reflection.Assembly]::ReflectionOnlyLoadFrom($Path)
            $references = @($assembly.GetReferencedAssemblies() | ForEach-Object { $_.FullName })
        }
        catch {
            $references = @("Reference metadata unavailable: $($_.Exception.GetType().Name)")
        }

        return [pscustomobject]@{
            IsManagedAssembly = $true
            AssemblyName = $name.Name
            AssemblyVersion = [string]$name.Version
            Culture = if ([string]::IsNullOrWhiteSpace($name.CultureName)) { 'neutral' } else { $name.CultureName }
            PublicKeyToken = $token
            References = ($references -join '; ')
        }
    }
    catch {
        return [pscustomobject]@{
            IsManagedAssembly = $false
            AssemblyName = ''
            AssemblyVersion = ''
            Culture = ''
            PublicKeyToken = ''
            References = ''
        }
    }
}

function Get-WavMetadata {
    param([Parameter(Mandatory = $true)][string]$Path)

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $reader = New-Object System.IO.BinaryReader($stream)
        if ($stream.Length -lt 12) {
            return [pscustomobject]@{ Path = $Path; Valid = $false; Reason = 'File is too small for a RIFF/WAVE header' }
        }

        $riff = [System.Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
        $riffSize = $reader.ReadUInt32()
        $wave = [System.Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))

        if ($riff -ne 'RIFF' -or $wave -ne 'WAVE') {
            return [pscustomobject]@{ Path = $Path; Valid = $false; Reason = 'Missing RIFF/WAVE signature' }
        }

        $formatCode = $null
        $channels = $null
        $sampleRate = $null
        $bitsPerSample = $null
        $byteRate = $null
        $dataSize = $null

        while ($stream.Position + 8 -le $stream.Length) {
            $chunkId = [System.Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
            $chunkSize = $reader.ReadUInt32()
            $chunkStart = $stream.Position
            $chunkEnd = $chunkStart + $chunkSize

            if ($chunkEnd -gt $stream.Length) {
                return [pscustomobject]@{ Path = $Path; Valid = $false; Reason = "Chunk $chunkId extends beyond the file" }
            }

            if ($chunkId -eq 'fmt ' -and $chunkSize -ge 16) {
                $formatCode = $reader.ReadUInt16()
                $channels = $reader.ReadUInt16()
                $sampleRate = $reader.ReadUInt32()
                $byteRate = $reader.ReadUInt32()
                $null = $reader.ReadUInt16()
                $bitsPerSample = $reader.ReadUInt16()
            }
            elseif ($chunkId -eq 'data') {
                $dataSize = $chunkSize
            }

            $stream.Position = $chunkEnd + ($chunkSize % 2)
        }

        if ($null -eq $formatCode -or $null -eq $dataSize -or $null -eq $byteRate) {
            return [pscustomobject]@{ Path = $Path; Valid = $false; Reason = 'Missing fmt or data chunk' }
        }

        $duration = if ($byteRate -gt 0) { [Math]::Round(($dataSize / $byteRate), 3) } else { $null }

        return [pscustomobject]@{
            Path = $Path
            Valid = ($formatCode -eq 1 -and $riffSize + 8 -eq $stream.Length)
            Format = if ($formatCode -eq 1) { 'PCM' } else { "Format $formatCode" }
            Channels = $channels
            SampleRateHz = $sampleRate
            BitsPerSample = $bitsPerSample
            DurationSeconds = $duration
            DeclaredLengthMatches = ($riffSize + 8 -eq $stream.Length)
        }
    }
    finally {
        $stream.Dispose()
    }
}

$root = [System.IO.Path]::GetFullPath($RepositoryRoot)
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    throw "Repository root not found: $root"
}

$binaryPaths = @(
    'BroadcastLite.exe',
    'Setup.exe',
    'VoIPSDK.dll',
    'VoIPSDK_x64\Bridge_x64_x86.exe',
    'VoIPSDK_x64\VoIPSDK_64bit.dll',
    'VoIPSDK_x64\VoIPSDK_NativeLib_x64.dll',
    'VoIPSDK_x64\lame_enc_64.dll',
    'VoIPSDK_x64\vcomp100_x64.dll',
    'VoIPSDK_x86\VoIPSDK_32bit.dll',
    'VoIPSDK_x86\VoIPSDK_NativeLib_x86.dll',
    'VoIPSDK_x86\lame_enc_32.dll',
    'VoIPSDK_x86\vcomp100_x86.dll'
)

$binaryResults = foreach ($relative in $binaryPaths) {
    $full = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        [pscustomobject]@{ Path = $relative; Exists = $false; IsPE = $false; Reason = 'Missing' }
        continue
    }

    $item = Get-Item -LiteralPath $full
    if ($item.Length -lt 64) {
        [pscustomobject]@{ Path = $relative; Exists = $true; IsPE = $false; SizeBytes = $item.Length; Reason = 'Too small to contain a valid PE image' }
        continue
    }

    $metadata = Get-PeMetadata -Path $full
    $metadata | Add-Member -NotePropertyName Exists -NotePropertyValue $true
    $metadata | Add-Member -NotePropertyName RelativePath -NotePropertyValue $relative
    $metadata
}

$binaryDetailResults = foreach ($relative in $binaryPaths) {
    $full = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        continue
    }

    $item = Get-Item -LiteralPath $full
    $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($full)
    $signatureStatus = 'NotChecked'
    $signer = ''

    if ($item.Length -ge 64) {
        try {
            $signature = Get-AuthenticodeSignature -FilePath $full
            $signatureStatus = [string]$signature.Status
            if ($null -ne $signature.SignerCertificate) {
                $signer = $signature.SignerCertificate.Subject
            }
        }
        catch {
            $signatureStatus = "InspectionError:$($_.Exception.GetType().Name)"
        }
    }

    $assembly = Get-AssemblyMetadata -Path $full
    $hash = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash

    [pscustomobject]@{
        Path = $relative
        SizeBytes = $item.Length
        SHA256 = $hash
        FileVersion = $versionInfo.FileVersion
        ProductVersion = $versionInfo.ProductVersion
        SignatureStatus = $signatureStatus
        Signer = $signer
        IsManagedAssembly = $assembly.IsManagedAssembly
        AssemblyName = $assembly.AssemblyName
        AssemblyVersion = $assembly.AssemblyVersion
        Culture = $assembly.Culture
        PublicKeyToken = $assembly.PublicKeyToken
        AssemblyReferences = $assembly.References
    }
}

$audioCandidates = @(
    (Join-Path $root '3_Intro Message.wav'),
    (Join-Path $root '4_Leave Your Message.wav')
)

$audioFolder = Join-Path $root 'Audio'
if (Test-Path -LiteralPath $audioFolder -PathType Container) {
    $audioCandidates += @(Get-ChildItem -LiteralPath $audioFolder -Filter '*.wav' -File -Recurse | ForEach-Object { $_.FullName })
}

$audioResults = foreach ($path in ($audioCandidates | Select-Object -Unique)) {
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        Get-WavMetadata -Path $path
    }
}

Write-Host 'Binary header inspection (files are read only; no program is launched):'
$binaryResults | Format-Table -AutoSize
Write-Host 'Binary version, hash, signature and managed-assembly metadata (read-only; managed DLLs are reflection-only inspected):'
$binaryDetailResults | Format-Table -AutoSize -Wrap
Write-Host 'Authenticode signature status:'
$binaryDetailResults | Select-Object Path, SignatureStatus, Signer | Format-List
Write-Host 'Managed assembly identities and referenced assemblies:'
foreach ($managed in ($binaryDetailResults | Where-Object { $_.IsManagedAssembly })) {
    Write-Host ("File: " + $managed.Path)
    Write-Host ("Assembly: " + $managed.AssemblyName)
    Write-Host ("Assembly version: " + $managed.AssemblyVersion)
    Write-Host ("Culture: " + $managed.Culture)
    Write-Host ("Public key token: " + $managed.PublicKeyToken)
    Write-Host ("References: " + $managed.AssemblyReferences)
}
Write-Host 'WAV inspection:'
$audioResults | Format-Table -AutoSize
Write-Warning 'This is static metadata inspection only. A valid signature or managed assembly identity does not establish SDK licensing, runtime compatibility, successful loading, or actual call quality.'
