class Win32Builder {
    # Setup | Instance
    hidden [string]$InstanceId
    hidden [System.Reflection.Emit.TypeBuilder]$Builder
    hidden [System.Type]$Api
    hidden [String]$Conname

    # Methods | Contructors
    Win32Builder([System.Reflection.Emit.AssemblyBuilderAccess]$builderAccess) {
        $this.InstanceId = [guid]::NewGuid().Guid

        if ($null -ne $builderAccess) {
            $this.Init($builderAccess)
        } else {
            $this.Init([System.Reflection.Emit.AssemblyBuilderAccess]::RunAndCollect)
        }
    }

    hidden [void]Init([System.Reflection.Emit.AssemblyBuilderAccess]$builderAccess) {
        $modBuilder = [AppDomain]::CurrentDomain.DefineDynamicAssembly((New-Object System.Reflection.AssemblyName('Proxy')), [System.Reflection.Emit.AssemblyBuilderAccess]::Run).DefineDynamicModule('ProxyMod')
        $this.Builder = $modBuilder.DefineType("W32Api_$($this.InstanceId)", "Public,Class")
    }

    # Methods | Api
    [void]MapApi([string]$dll, [string]$name, [type]$retType, [type[]]$params, [System.Runtime.InteropServices.CharSet]$charSet) {
        $attr = [System.Reflection.MethodAttributes]"Public, Static, PinvokeImpl"
        $netConv = [System.Reflection.CallingConventions]::Standard
        $win32Conv = [System.Runtime.InteropServices.CallingConvention]::Winapi
        $mb = $this.Builder.DefinePInvokeMethod(
            $name,
            $dll,
            $attr,
            $netConv,
            $retType,
            $params,
            $win32Conv,
            $charSet
        )

        $implFlags = $mb.GetMethodImplementationFlags() -bor [System.Reflection.MethodImplAttributes]::PreserveSig
        $mb.SetImplementationFlags($implFlags)

        $dllImportCtor = [System.Runtime.InteropServices.DllImportAttribute].GetConstructor(@([string]))
        $dllImportField = @([System.Runtime.InteropServices.DllImportAttribute].GetField('SetLastError'))
        $cab = New-Object System.Reflection.Emit.CustomAttributeBuilder(
            $dllImportCtor,
            @($dll),
            @($dllImportField),
            @($true)
        )
        $mb.SetCustomAttribute($cab)
    }

    [void]MapApi([string]$dll, [string]$name, [type]$retType, [type[]]$params) {
        $this.MapApi($dll, $name, $retType, $params, [System.Runtime.InteropServices.CharSet]::Ansi)
    }

    [System.Type]CreateApi() {
        try {
            $this.Api = $this.Builder.CreateType()
        } catch {
            Write-Console -name $this.Conname -msg "Error initializing type:" -data "$($_)" -msgColor Red
        }

        return $this.Api
    }

    [System.Type]GetApi() {
        return $this.Api
    }

    [string]GetTypeName() {
        return $this.Builder.FullName
    }
}

function New-Win32Builder {
    return [Win32Builder]::new()
}

Export-ModuleMember -Function New-Win32Builder -Alias *