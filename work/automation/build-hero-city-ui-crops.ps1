param(
    [string]$Source = 'C:\Users\JENNAR~1\AppData\Local\Temp\codex-clipboard-bd92603a-d62a-4f52-b48e-46594fb538c8.png',
    [string]$Output = 'F:\Roblox\PuchWall\work\assets\generated\hero-city-pixel-ui'
)

Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path $Output | Out-Null

$sourceImage = [System.Drawing.Bitmap]::FromFile($Source)
$widgets = @(
    @{ Name='power'; Rect=@(415,23,279,103); Points=@(@(20,2),@(250,2),@(275,24),@(269,78),@(249,99),@(20,99),@(3,78),@(3,25)) },
    @{ Name='coins'; Rect=@(702,22,330,104); Points=@(@(18,2),@(299,2),@(318,22),@(313,78),@(299,95),@(20,95),@(3,79),@(3,25)) },
    @{ Name='wall'; Rect=@(1041,23,252,103); Points=@(@(20,2),@(222,2),@(247,23),@(241,79),@(224,98),@(21,98),@(3,78),@(3,25)) },
    @{ Name='daily'; Rect=@(16,201,82,111); Points=@(@(13,5),@(69,5),@(78,14),@(78,96),@(67,104),@(14,104),@(3,96),@(3,14)) },
    @{ Name='spin'; Rect=@(16,316,82,111); Points=@(@(13,3),@(70,3),@(80,13),@(80,98),@(69,107),@(13,107),@(2,98),@(2,13)) },
    @{ Name='rebirth'; Rect=@(16,429,82,111); Points=@(@(16,10),@(66,10),@(75,18),@(75,80),@(66,86),@(16,86),@(7,80),@(7,18)) },
    @{ Name='shop'; Rect=@(1570,296,87,111); Points=@(@(15,4),@(72,4),@(80,14),@(80,74),@(72,82),@(15,82),@(7,74),@(7,14)) },
    @{ Name='pets'; Rect=@(1570,410,87,104); Points=@(@(15,3),@(72,3),@(81,13),@(81,69),@(72,77),@(15,77),@(7,69),@(7,13)) },
    @{ Name='quests'; Rect=@(1570,515,87,103); Points=@(@(17,3),@(70,3),@(79,13),@(79,63),@(70,72),@(17,72),@(9,63),@(9,13)) },
    @{ Name='quest-card'; Rect=@(1368,117,294,134); Points=@(@(16,0),@(278,0),@(293,16),@(293,118),@(278,133),@(16,133),@(0,118),@(0,16)) },
    @{ Name='punch'; Rect=@(1211,669,250,250); Ellipse=@(0,0,234,249) },
    @{ Name='jump'; Rect=@(1460,694,211,211); Ellipse=@(0,0,190,210) },
    @{ Name='next-world'; Rect=@(1020,778,194,145); Points=@(@(12,0),@(181,0),@(193,12),@(193,133),@(181,144),@(12,144),@(0,133),@(0,12)) },
    @{ Name='joystick'; Rect=@(57,640,270,270); Ellipse=@(2,2,253,265) },
    @{ Name='top-tools'; Rect=@(1464,23,199,62); Points=@(@(12,0),@(187,0),@(198,12),@(198,50),@(187,61),@(12,61),@(0,50),@(0,12)) },
    @{ Name='sound-tool'; Rect=@(1465,22,60,64); Points=@(@(14,0),@(48,0),@(59,12),@(59,51),@(48,63),@(13,63),@(0,50),@(0,13)) },
    @{ Name='settings-tool'; Rect=@(1526,22,60,64); Points=@(@(14,0),@(48,0),@(59,12),@(59,51),@(48,63),@(13,63),@(0,50),@(0,13)) },
    @{ Name='more-tool'; Rect=@(1587,22,64,64); Points=@(@(14,0),@(51,0),@(63,12),@(63,51),@(51,63),@(13,63),@(0,50),@(0,13)) },
    @{ Name='smash-billboard'; Rect=@(143,184,266,148); Points=@(@(21,0),@(265,11),@(253,137),@(16,147),@(0,128),@(5,18)) }
)

foreach ($widget in $widgets) {
    $x,$y,$w,$h = $widget.Rect
    $crop = [System.Drawing.Bitmap]::new($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($crop)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.DrawImage($sourceImage, (New-Object System.Drawing.Rectangle 0,0,$w,$h), $x,$y,$w,$h, [System.Drawing.GraphicsUnit]::Pixel)
    $graphics.Dispose()

    $maskScale = 4
    $maskLarge = [System.Drawing.Bitmap]::new($w * $maskScale, $h * $maskScale, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $maskGraphics = [System.Drawing.Graphics]::FromImage($maskLarge)
    $maskGraphics.Clear([System.Drawing.Color]::Transparent)
    $maskGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    if ($widget.Ellipse) {
        $ellipseX,$ellipseY,$ellipseW,$ellipseH = $widget.Ellipse
        $path.AddEllipse($ellipseX * $maskScale, $ellipseY * $maskScale, $ellipseW * $maskScale, $ellipseH * $maskScale)
    } else {
        $points = foreach ($point in $widget.Points) { New-Object System.Drawing.PointF ([single]($point[0] * $maskScale)),([single]($point[1] * $maskScale)) }
        $path.AddPolygon([System.Drawing.PointF[]]$points)
    }
    $maskGraphics.FillPath([System.Drawing.Brushes]::White, $path)
    $maskGraphics.Dispose()
    $path.Dispose()

    $mask = [System.Drawing.Bitmap]::new($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $maskDownsample = [System.Drawing.Graphics]::FromImage($mask)
    $maskDownsample.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $maskDownsample.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $maskDownsample.DrawImage($maskLarge, 0, 0, $w, $h)
    $maskDownsample.Dispose()
    $maskLarge.Dispose()
    for ($pixelY = 0; $pixelY -lt $h; $pixelY++) {
        for ($pixelX = 0; $pixelX -lt $w; $pixelX++) {
            $sourcePixel = $crop.GetPixel($pixelX, $pixelY)
            $maskAlpha = $mask.GetPixel($pixelX, $pixelY).A
            $alpha = [int][math]::Round($sourcePixel.A * $maskAlpha / 255)
            $crop.SetPixel($pixelX, $pixelY, [System.Drawing.Color]::FromArgb($alpha, $sourcePixel.R, $sourcePixel.G, $sourcePixel.B))
        }
    }
    $mask.Dispose()
    $target = Join-Path $Output ($widget.Name + '.png')
    $crop.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
    $crop.Dispose()
}

$sourceImage.Dispose()
Get-ChildItem -LiteralPath $Output -Filter '*.png' | Select-Object Name,Length
