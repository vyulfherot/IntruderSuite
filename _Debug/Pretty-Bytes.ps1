function Pretty-Bytes {
    [CmdletBinding()] 
    param(
        [byte[]]$bytes
    )

    return "0x$(($bytes | ForEach-Object { '{0:X2}' -f $_ }) -join ', 0x')"
}