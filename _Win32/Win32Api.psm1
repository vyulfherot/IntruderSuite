class Win32Api {
    # Setup | Instance
    hidden [string]$InstanceId
    hidden [System.Reflection.Emit.TypeBuilder]$Builder
    hidden [System.Type]$Api
    hidden [String]$Conname

    # Methods | Contructors
    Win32Api() {
        $this.InstanceId = [guid]::NewGuid().Guid
        $this.Init()
    }

    hidden [void]Init() {
        $modBuilder = [AppDomain]::CurrentDomain.DefineDynamicAssembly((New-Object System.Reflection.AssemblyName('Proxy')), [System.Reflection.Emit.AssemblyBuilderAccess]::RunAndCollect).DefineDynamicModule('ProxyMod')
        $this.Builder = $modBuilder.DefineType("W32Api_$($this.InstanceId)", "Public,Class")
    }

    # Methods | Api
    [void]MapApi([string]$dll, [string]$name, [type]$retType, [type[]]$params) {
        $attr = [System.Reflection.MethodAttributes]"Public, Static, PinvokeImpl"
        $netConv = [System.Reflection.CallingConventions]::Standard
        $win32Conv = [System.Runtime.InteropServices.CallingConvention]::Winapi
        $cset = [System.Runtime.InteropServices.CharSet]::Ansi
        $mb = $this.Builder.DefinePInvokeMethod($name, $dll, $attr, $netConv, $retType, $params, $win32Conv, $cset)
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

    [System.Reflection.Emit.TypeBuilder]CreateApi() {
        try {
            $this.Api = $this.Builder.CreateType()
        } catch {
            Conwrite -name $this.Conname -msg "Error initializing type:" -data "$($_)" -msgColor Red
        }

        return $this.Api
    }

    [string]GetTypeName() {
        return $this.Builder.FullName
    }
}