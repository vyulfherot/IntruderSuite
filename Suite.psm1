Get-ChildItem -Path $PSScriptRoot -Recurse -Filter "*.ps*" | ? { $_.FullName -ne $PSCommandPath } | % { Import-Module $_.FullName -DisableNameChecking }

# Aliases
'nrs', 'nrshc', 'genshc' | % { Set-Alias -Name $_ -Value 'New-RunShellcode' }
'cw', 'con' | % { Set-Alias -Name $_ -Value 'Conwrite' }
'pb', 'pbytes' | % { Set-Alias -Name $_ -Value 'Pretty-Bytes' }
