using module "..\_Win32\Win32Builder.psm1"

class Progenitor {
    # Setup | Win32 - Api
    hidden static [System.Type]$K32Proc
    hidden static [System.Type]$K32Mem
    hidden static [System.Type]$W32DLL
    hidden static [System.Type]$W32PE

    # Setup | Win32 - Constants
    hidden static [uint32]$VM_OP = 0x0008
    hidden static [uint32]$VM_WRITE = 0x0020
    hidden static [uint32]$VM_READ = 0x0010
    hidden static [uint32]$CREATE_THREAD = 0x0002
    hidden static [uint32]$QUERY_INFO = 0x0400

    # Setup | Target process
    hidden static [uint32]$targetPID
    hidden static [intptr]$targetHandle

    # Methods | Initialization
    hidden static [void]InitK32Proc() {
        # Check | Initialized
        $cls = [Progenitor]
        if ($null -ne $cls::K32Proc) {return}

        # Assign
        $api = [Win32Builder]::New()

        # Map
        $api.MapApi("kernel32.dll", "OpenProcess", ([intptr]), @([uint32], [bool], [uint32]))

        # Init
        $cls::K32Proc = $api.CreateApi()
    }

    hidden static [void]InitK32Mem() {
        # Check | Initialized
        $cls = [Progenitor]
        if ($null -ne $cls::K32Mem) {return}

        # Assign
        $api = [Win32Builder]::New()

        # Map
        $api.MapApi("kernel32.dll", "VirtualAllocEx", ([intptr]), @([intptr], [intptr], [uintptr], [uint32], [uint32]))
        $api.MapApi("kernel32.dll", "WriteProcessMemory", ([bool]), @([intptr], [intptr], [Byte[]], [uintptr], [uintptr]))
        $api.MapApi("kernel32.dll", "CreateRemoteThread", ([intptr]), @([intptr], [intptr], [uintptr], [intptr], [intptr], [uint32], [intptr]))

        # Init
        $cls::K32Mem = $api.CreateApi()
    }

    hidden static [void]InitW32DLL() {
        # Check | Initialized
        $cls = [Progenitor]
        if ($null -ne $cls::W32DLL) {return}

        # Assign
        $api = [Win32Builder]::New()

        # Map
        $api.MapApi("kernel32.dll", "GetModuleHandle", ([intptr]), @([string]))
        $api.MapApi("kernel32.dll", "GetProcAddress", ([intptr]), @([intptr], [string]))
        $api.MapApi("psapi.dll", "EnumProcessModules", ([bool]), @([intptr], [intptr[]], [uint32], [uint32]))
        $api.MapApi("psapi.dll", "GetModuleFileNameExA", ([uint32]), @([intptr], [intptr], [System.Text.StringBuilder], [uint32]))

        # Init
        $cls::W32DLL = $api.CreateApi()
    }

    hidden static [void]InitW32PE() {
        # Check | Initialized
        #$cls = [Progenitor]
        #if ($null -ne $cls::W32PE) {return}

        # Assign
        #$api = [Win32Builder]::New()

        # Map

        # Init
        #$cls::W32PE = $api.CreateApi()
    }

    # Methods | Injection
    static [void]TargetProcess([uint32]$tPID) {
        # Setup | Class
        $cls = [Progenitor]

        # Setup | Win32
        $cls::InitK32Proc()

        $w32 = [Progenitor]::K32Proc
        [uint32]$dwAccess = $cls::VM_OP -bor $cls::VM_WRITE -bor $cls::VM_READ -bor $cls::CREATE_THREAD -bor $cls::QUERY_INFO

        # Open | Handle on targetted process
        $cls::targetHandle = $w32::OpenProcess($dwAccess, $false, $tPID)
    }

    static [bool]InjectShc([byte[]]$shellcode) {
        # Setup | Class & Debug
        $cls = [Progenitor]
        $conname = "InjectSHC"

        # Setup | Win32
        $cls::InitK32Mem()

        $W32 = $cls::K32Mem

        # Setup | Process
        $hProc = $cls::targetHandle
        $tPID = $cls::targetPID

        # Check | Process handle
        if ($hProc -eq [IntPtr]::Zero -or $hProc -eq 0) {
            $err = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
            Conwrite -name $conname -msg "Failed to get handle on PID: $tPID. Err: $err" -msgColor Red
            return $false
        } else {
            Conwrite -name $conname -msg "Got handle on PID: $tPID as $hProc"
        }

        # Shellcode | Patch
        $shellcode += 0xC3 # Append ret to handle thread exit
        $shcLength = [uintptr][uint64]$shellcode.Length

        # Shellcode | Allocate, write, thread
        [intptr]$pRemoteMem = $W32::VirtualAllocEx($hProc, [intptr]::Zero, $shcLength, [uint32]0x3000, [uint32]0x40)

        $W32::WriteProcessMemory($hProc, $pRemoteMem, $shellcode, $shcLength, [uintptr]::Zero)

        $hThread = $W32::CreateRemoteThread($hProc, [intptr]::Zero, [UIntPtr]::Zero, $pRemoteMem, [intptr]::Zero, [uint32]0, [intptr]::Zero)

        # Output
        Conwrite -name $conname -msg "Injected shellcode at [$($pRemoteMem.ToString("X"))] in thread [$hThread](PID: $tPID)" -msgColor Green
        return $true
    }

    static [void]InjectDLL([string]$dllPath) {
        # Setup | Class & Debug
        $cls = [Progenitor]
        $conname = "InjectDLL"

        # Setup | Win32
        $cls::InitK32DLL()

        $W32 = $cls::K32DLL

        # Setup | Process
        $hProc = $cls::targetHandle
        $tPID = $cls::targetPID

        # Map | Remote Kernel32 API
        $localBase = $W32::GetModuleHandle("kernel32.dll")
        $localLL   = $W32::GetProcAddress($localBase, "LoadLibraryA")
        $llOffset  = $localLL.ToInt64() - $localBase.ToInt64()

        # Enumerate remote modules
        $modBuf   = New-Object IntPtr[] 256
        $cbNeeded = [uint32]0
        $W32::EnumProcessModules($hProc, $modBuf, (256 * [IntPtr]::Size), $cbNeeded) | Out-Null

        $remoteKernel32Base = [IntPtr]::Zero
        $sb = New-Object System.Text.StringBuilder 260

        foreach ($hMod in $modBuf) {
            if ($hMod -eq [IntPtr]::Zero) { continue }
            $sb.Clear() | Out-Null
            $W32::GetModuleFileNameExA($hProc, $hMod, $sb, 260) | Out-Null
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

        $allocAddr = $W32::VirtualAllocEx($hProc, [IntPtr]::Zero, $dllPLength, ($MEM_COMMIT -bor $MEM_RESERVE), $PAGE_RW)
        $W32::WriteProcessMemory($hProc, $allocAddr, $dllBytes, $dllPLength, [uintptr]::Zero) | Out-Null

        # Create | Remote thread at LoadLibraryA and pass allocated DLL path
        $hThread = $W32::CreateRemoteThread($hProc, [IntPtr]::Zero, [uintptr]::Zero, $remoteLL, $allocAddr, 0, [IntPtr]::Zero)

        # Console
        Conwrite -name $conname -msg "Injected [$dllPath] into [$tPID] at [$($allocAddr.ToString('X'))](Thread: $hThread)"
    }

    static [void]InjectPE([string]$pePath) {
        
    }
}