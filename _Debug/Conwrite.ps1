function Conwrite {
    [CmdletBinding()] 
    param(
        [bool]$do = $true,
        [string]$name = "---",
        [string]$msg,
        [string]$data,
        [ConsoleColor]$nameColor = 'Yellow',
        [ConsoleColor]$msgColor = 'White',
        [ConsoleColor]$dataColor = 'Gray'
    )

    if (-not $do) {return}

    $hasData = -not [string]::IsNullOrWhiteSpace($data)

    Write-Host "(" -fore $dataColor -NoNewline
    Write-Host "$($name.ToUpper())" -fore $nameColor -NoNewline
    Write-Host ") " -fore $dataColor

    Write-Host "| Msg: " -fore $dataColor -NoNewline
    Write-Host "$msg" -fore $msgColor

    if ($hasData) {
        Write-Host "{ " -fore $dataColor
        Write-Host "$data" -fore $dataColor
        Write-Host "}" -fore $dataColor    
    }
}