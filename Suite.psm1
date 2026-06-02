Get-ChildItem -Path $PSScriptRoot -Recurse -Filter "*.ps*" |
    Where-Object { $_.FullName -ne $PSCommandPath } |
    ForEach-Object { Import-Module $_.FullName -DisableNameChecking }