Get-ChildItem -Path $PSScriptRoot -Recurse -Filter "*.ps*" | Where-Object { $_.FullName -ne $PSCommandPath } | ForEach-Object { Import-Module $_.FullName -DisableNameChecking }

# Aliases
'cw', 'con', 'conwrite' | ForEach-Object { Set-Alias -Name $_ -Value 'Write-Console' -Force }
'pb', 'pbytes', 'pretty-bytes' | ForEach-Object { Set-Alias -Name $_ -Value 'ConvertTo-PrettyBytes' -Force }
'nrs', 'nrshc', 'genshc' | ForEach-Object { Set-Alias -Name $_ -Value 'New-RunShellcode' -Force }