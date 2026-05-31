Get-ChildItem -Path $PSScriptRoot -Recurse -Filter "*.ps*" | Where-Object { $_.FullName -ne $PSCommandPath } | ForEach-Object { Import-Module $_.FullName -DisableNameChecking }

# Aliases
'nrs', 'nrshc', 'genshc' | ForEach-Object { Set-Alias -Name $_ -Value 'New-RunShellcode' }
'cw', 'con', 'conwrite' | ForEach-Object { Set-Alias -Name $_ -Value 'Write-Console' }
'pb', 'pbytes', 'pretty-bytes' | ForEach-Object { Set-Alias -Name $_ -Value 'ConvertTo-PrettyBytes' }
