Get-ChildItem -Path $PSScriptRoot -Recurse -Filter "*.ps*" | ? { $_.FullName -ne $PSCommandPath } | % { Import-Module $_.FullName -DisableNameChecking }

# Aliases
'nrs', 'nrshc', 'genshc' | % { Set-Alias -Name $_ -Value 'New-RunShellcode' }
'cw', 'con', 'conwrite' | % { Set-Alias -Name $_ -Value 'Write-Console' }
'pb', 'pbytes', 'pretty-bytes' | % { Set-Alias -Name $_ -Value 'ConvertTo-PrettyBytes' }
