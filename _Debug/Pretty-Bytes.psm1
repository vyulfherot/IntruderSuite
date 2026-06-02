function ConvertTo-PrettyBytes {
    [CmdletBinding()] 
    param(
        [byte[]]$bytes
    )

    return "0x$(($bytes | ForEach-Object { '{0:X2}' -f $_ }) -join ', 0x')"
}

# [Export]
# Aliases
'pb', 'pbytes', 'pretty-bytes' | ForEach-Object { Set-Alias -Name $_ -Value 'ConvertTo-PrettyBytes' }

# Functions
Export-ModuleMember -Function *