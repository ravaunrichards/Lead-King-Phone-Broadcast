[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Join-Path $PSScriptRoot '..')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Mono.Cecil 0.11.6 is used only for static metadata/CIL reading. It is not
# added to the BroadcastLite runtime and does not execute the target assembly.
$cecilVersion = '0.11.6'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('BroadcastLite-Cecil-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $tempRoot -Force

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $packagePath = Join-Path $tempRoot "mono.cecil.$cecilVersion.nupkg"
    $packageUrl = "https://api.nuget.org/v3-flatcontainer/mono.cecil/$cecilVersion/mono.cecil.$cecilVersion.nupkg"
    Invoke-WebRequest -Uri $packageUrl -OutFile $packagePath -UseBasicParsing

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $extractPath = Join-Path $tempRoot 'package'
    [System.IO.Compression.ZipFile]::ExtractToDirectory($packagePath, $extractPath)

    $cecilCandidates = @(
        (Join-Path $extractPath 'lib\net40\Mono.Cecil.dll'),
        (Join-Path $extractPath 'lib\netstandard2.0\Mono.Cecil.dll')
    )
    $cecilPath = $cecilCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($cecilPath)) {
        throw 'Pinned Mono.Cecil package did not contain a supported assembly.'
    }

    $cecilBytes = [System.IO.File]::ReadAllBytes($cecilPath)
    $null = [System.Reflection.Assembly]::Load($cecilBytes)

    $root = [System.IO.Path]::GetFullPath($RepositoryRoot)
    $applicationPath = Join-Path $root 'BroadcastLite.exe'
    if (-not (Test-Path -LiteralPath $applicationPath -PathType Leaf)) {
        throw "BroadcastLite executable not found: $applicationPath"
    }

    $readerParameters = New-Object Mono.Cecil.ReaderParameters
    $readerParameters.ReadSymbols = $false
    $assembly = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($applicationPath, $readerParameters)

    try {
        Write-Host ("Assembly: {0}" -f $assembly.Name.FullName)
        Write-Host ("Module: {0}" -f $assembly.MainModule.Name)

        $allTypes = New-Object 'System.Collections.Generic.List[object]'
        $pending = New-Object 'System.Collections.Generic.Stack[object]'
        foreach ($type in $assembly.MainModule.Types) {
            $pending.Push($type)
        }
        while ($pending.Count -gt 0) {
            $type = $pending.Pop()
            $allTypes.Add($type)
            foreach ($nested in $type.NestedTypes) {
                $pending.Push($nested)
            }
        }

        Write-Host 'License/registration-related fields:'
        foreach ($type in $allTypes) {
            foreach ($field in $type.Fields) {
                if ($field.Name -match '(?i)licen|registr|trial|unlicen|serial|volume') {
                    Write-Host ("FIELD {0}::{1} : {2}" -f $type.FullName, $field.Name, $field.FieldType.FullName)
                }
            }
        }

        $methods = New-Object 'System.Collections.Generic.List[object]'
        foreach ($type in $allTypes) {
            foreach ($method in $type.Methods) {
                $methods.Add($method)
            }
        }

        $candidateMethodList = New-Object 'System.Collections.Generic.List[object]'
        foreach ($method in $methods) {
            $includeMethod = ($method.Name -match '(?i)licen|registr|trial|unlicen|form_BroadcastLite_Load|StartBroadcast|StartSchedule|btn_Start_Click|btn_Stop_Click|timer_CallLength_Tick|timer_Inner_Tick|timer_Schedule_Tick|btn_LoginVOIPSettings_Click|RunPingTest|InitializeSoftPhone|Post')

            if (-not $includeMethod -and $method.HasBody) {
                foreach ($instruction in $method.Body.Instructions) {
                    if ($instruction.Operand -is [Mono.Cecil.FieldReference] -and
                        $instruction.Operand.Name -match '(?i)gbLicensed|giTrialVersionDialCount|licen|registr|trial|unlicen') {
                        $includeMethod = $true
                        break
                    }

                    if ($instruction.Operand -is [Mono.Cecil.MethodReference] -and
                        $instruction.Operand.Name -match '(?i)SetLicense|GetLicense|Register|Unlicense|License|Trial|StartBroadcast|Broadcast') {
                        $includeMethod = $true
                        break
                    }
                }
            }

            if ($includeMethod) {
                $candidateMethodList.Add($method)
            }
        }

        $candidateMethods = $candidateMethodList.ToArray()

        Write-Host ("Candidate methods: {0}" -f $candidateMethods.Count)
        foreach ($method in $candidateMethods) {
            Write-Host ''
            Write-Host ("METHOD {0}::{1} : {2}" -f $method.DeclaringType.FullName, $method.Name, $method.ReturnType.FullName)
            Write-Host ("TOKEN 0x{0:X8}; Public={1}; Static={2}; HasBody={3}" -f $method.MetadataToken.ToInt32(), $method.IsPublic, $method.IsStatic, $method.HasBody)

            if (-not $method.HasBody) {
                continue
            }

            foreach ($instruction in $method.Body.Instructions) {
                $opcode = $instruction.OpCode.Name
                $operandText = ''

                if ($null -ne $instruction.Operand) {
                    if ($instruction.Operand -is [Mono.Cecil.MethodReference]) {
                        $operandText = $instruction.Operand.FullName
                    }
                    elseif ($instruction.Operand -is [Mono.Cecil.FieldReference]) {
                        $operandText = $instruction.Operand.FullName
                    }
                    elseif ($instruction.Operand -is [string]) {
                        $literal = [string]$instruction.Operand
                        if ($literal -match '(?i)(password|passwd|secret|activation.?key|license.?key|serial.?key|token=|OZSDK|DYN\d)' -or
                            $literal.Length -ge 48 -or
                            $literal -match '^[A-Za-z0-9+/]{32,}={0,2}$') {
                            $operandText = '<sensitive or long literal redacted>'
                        }
                        else {
                            $operandText = '"' + ($literal -replace '[\r\n\t]', ' ') + '"'
                            if ($operandText.Length -gt 180) {
                                $operandText = $operandText.Substring(0, 177) + '..."'
                            }
                        }
                    }
                    else {
                        $operandText = [string]$instruction.Operand
                    }
                }

                if ($opcode -match '^(call|callvirt|newobj|ldfld|stfld|ldsfld|stsfld|ldstr|br|brtrue|brfalse|switch|ret|throw|ceq|cgt|clt)') {
                    Write-Host ("  IL_{0:X4}: {1,-12} {2}" -f $instruction.Offset, $opcode, $operandText)
                }
            }
        }

        Write-Host ''
        Write-Host 'Ozeki-related method references in candidate method bodies:'
        $ozekiRefs = New-Object 'System.Collections.Generic.HashSet[string]'
        foreach ($method in $candidateMethods) {
            if (-not $method.HasBody) { continue }
            foreach ($instruction in $method.Body.Instructions) {
                if (($instruction.Operand -is [Mono.Cecil.MethodReference]) -and
                    $instruction.Operand.DeclaringType.FullName -match '(?i)Ozeki|VoIPSDK|LicenseManager') {
                    $null = $ozekiRefs.Add($instruction.Operand.FullName)
                }
            }
        }
        foreach ($reference in $ozekiRefs) {
            Write-Host $reference
        }
        Write-Warning 'This is static IL inspection only. No method was invoked and BroadcastLite.exe was not launched.'
    }
    finally {
        $assembly.Dispose()
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        try {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction Stop
        }
        catch {
            Write-Warning "Temporary Cecil inspection files could not be removed by this process: $($_.Exception.GetType().Name). The runner workspace is ephemeral."
        }
    }
}
