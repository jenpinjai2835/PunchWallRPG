param(
    [string]$Source = 'C:\Users\JENNAR~1\AppData\Local\Temp\codex-clipboard-bd92603a-d62a-4f52-b48e-46594fb538c8.png',
    [string]$Output = 'F:\Roblox\PuchWall\work\assets\generated\hero-city-pixel-ui'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path $Output | Out-Null
$sourceImage = [System.Drawing.Bitmap]::FromFile($Source)

function Export-DarkConnectedCrop {
    param([string]$Name, [int]$X, [int]$Y, [int]$Width, [int]$Height)

    $eligible = New-Object 'bool[]' ($Width * $Height)
    $selected = New-Object 'bool[]' ($Width * $Height)
    for ($py = 0; $py -lt $Height; $py++) {
        for ($px = 0; $px -lt $Width; $px++) {
            $color = $sourceImage.GetPixel($X + $px, $Y + $py)
            $luma = 0.2126 * $color.R + 0.7152 * $color.G + 0.0722 * $color.B
            $eligible[$py * $Width + $px] = $luma -lt 105
        }
    }

    $queue = [System.Collections.Generic.Queue[System.Drawing.Point]]::new()
    for ($px = 0; $px -lt $Width; $px++) {
        $index = ($Height - 1) * $Width + $px
        if ($eligible[$index]) {
            $selected[$index] = $true
            $queue.Enqueue([System.Drawing.Point]::new($px, $Height - 1))
        }
    }
    while ($queue.Count -gt 0) {
        $point = $queue.Dequeue()
        foreach ($step in @(@(-1,0),@(1,0),@(0,-1),@(0,1))) {
            $nx = $point.X + $step[0]
            $ny = $point.Y + $step[1]
            if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $Width -or $ny -ge $Height) { continue }
            $index = $ny * $Width + $nx
            if ($eligible[$index] -and -not $selected[$index]) {
                $selected[$index] = $true
                $queue.Enqueue([System.Drawing.Point]::new($nx, $ny))
            }
        }
    }

    $dilated = [bool[]]$selected.Clone()
    for ($py = 0; $py -lt $Height; $py++) {
        for ($px = 0; $px -lt $Width; $px++) {
            if (-not $selected[$py * $Width + $px]) { continue }
            for ($dy = -3; $dy -le 3; $dy++) {
                for ($dx = -3; $dx -le 3; $dx++) {
                    $nx = $px + $dx
                    $ny = $py + $dy
                    if ($nx -ge 0 -and $ny -ge 0 -and $nx -lt $Width -and $ny -lt $Height) {
                        $dilated[$ny * $Width + $nx] = $true
                    }
                }
            }
        }
    }

    $result = [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    for ($py = 0; $py -lt $Height; $py++) {
        for ($px = 0; $px -lt $Width; $px++) {
            $panelTop = if ($Name -eq 'bottom-shell-left') { 132 + 0.42 * $px } else { 148 - 0.12 * $px }
            $controlArea = if ($Name -eq 'bottom-shell-left') {
                (($px - 190) * ($px - 190) + ($py - 160) * ($py - 160)) -lt (164 * 164)
            } else {
                ((($px - 255) * ($px - 255) + ($py - 185) * ($py - 185)) -lt (158 * 158)) -or
                ((($px - 460) * ($px - 460) + ($py - 195) * ($py - 195)) -lt (140 * 140)) -or
                ($px -lt 150 -and $py -gt 125)
            }
            if (-not $controlArea -and $py -ge $panelTop -and $dilated[$py * $Width + $px]) {
                $result.SetPixel($px, $py, $sourceImage.GetPixel($X + $px, $Y + $py))
            } else {
                $result.SetPixel($px, $py, [System.Drawing.Color]::Transparent)
            }
        }
    }
    $target = Join-Path $Output ($Name + '.png')
    $result.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
    $result.Dispose()
    Get-Item -LiteralPath $target | Select-Object Name,Length
}

Export-DarkConnectedCrop -Name 'bottom-shell-left' -X 0 -Y 620 -Width 430 -Height 321
Export-DarkConnectedCrop -Name 'bottom-shell-right' -X 1080 -Y 620 -Width 592 -Height 321
$sourceImage.Dispose()
