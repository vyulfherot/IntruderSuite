class Cavediver {
    static [int]GetCaveVolume([string]$pePath) {
        # Load bytes
        $bytes = [System.IO.File]::ReadAllBytes($pePath)

        # Calc free space
        $e_lfanew = [BitConverter]::ToUInt32($bytes, 0x3C)
        $sizeOfOptionalHeader = [BitConverter]::ToUInt16($bytes, $e_lfanew + 0x14)
        $sectionTableOffset = $e_lfanew + 0x18 + $sizeOfOptionalHeader

        $textHeaderOffset = $sectionTableOffset
        $textVSize = [BitConverter]::ToUInt32($bytes, $textHeaderOffset + 0x08)
        $textRawSize = [BitConverter]::ToUInt32($bytes, $textHeaderOffset + 0x10)

        $volume = $textRawSize - $textVSize

        return $volume
    }

    static [string]FilterCaveVolume([string]$path, [int]$lowerLimit, [bool]$toClipboard) {
        # Setup | Report string
        $reportBuilder = New-Object System.Text.StringBuilder

        # Measure | Directory or file
        if ([System.IO.Directory]::Exists($path)) {
            foreach ($file in Get-ChildItem -Path $path -Filter *.exe) {
                # Get | Codecave volume
                $caveVolume = [Cavediver]::GetCaveVolume($file.Fullname)

                # Build | Line
                $line = "[$($file.FullName)]: Free .text bytes: $caveVolume"

                # Check | Lower limit
                if ($caveVolume -lt $lowerLimit) {continue}
                
                # Append | Line
                [void]$reportBuilder.AppendLine($line)
            }
        } elseif ([System.IO.File]::Exists($path)) {
                # Get | Codecave volume
                $caveVolume = [Cavediver]::GetCaveVolume($path)

                # Build | Line
                $line = "[$path]: Free .text bytes: $caveVolume"

                # Check | Lower limit
                if ($caveVolume -lt $lowerLimit) {return ""}

                # Append | Line
                [void]$reportBuilder.AppendLine($line)
        }

        if ($reportBuilder.Length -gt 0) {
            # Fetch | Report string
            $report = $reportBuilder.ToString()

            # Clipboard
            if ($toClipboard) {
                $report | Set-Clipboard
            }

            # Return
            return $report
        }

        # Neither
        return "[$path] is not a valid directory or file."
    }

    static [string]FilterCaveVolume([string]$path, [int]$lowerLimit) {
        return [Cavediver]::FilterCaveVolume($path, $lowerLimit, $false)
    }

    static [string]FilterCaveVolume([string]$path, [bool]$toClipboard) {
        return [Cavediver]::FilterCaveVolume($path, 0, $toClipboard)
    }

    static [string]FilterCaveVolume([string]$path) {
        return [Cavediver]::FilterCaveVolume($path, 0, $false)
    }
}