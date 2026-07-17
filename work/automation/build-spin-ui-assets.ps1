param(
    [string]$SourceRoot = "C:\Users\Jennarong Pinjai\Downloads",
    [string]$OutputRoot = "F:\Roblox\PuchWall\work\assets\user-supplied\spin-ui"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

if (-not ("PunchWall.AlphaBackgroundCleaner" -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

namespace PunchWall {
    public static class AlphaBackgroundCleaner {
        private static bool IsBackground(byte[] pixels, int index) {
            int b = pixels[index];
            int g = pixels[index + 1];
            int r = pixels[index + 2];
            int min = Math.Min(r, Math.Min(g, b));
            int max = Math.Max(r, Math.Max(g, b));
            return min >= 202 && max - min <= 48;
        }

        public static void CleanAndCrop(string inputPath, string outputPath, int padding) {
            using (var source = new Bitmap(inputPath))
            using (var image = new Bitmap(source.Width, source.Height, PixelFormat.Format32bppArgb)) {
                using (var graphics = Graphics.FromImage(image)) {
                    graphics.DrawImageUnscaled(source, 0, 0);
                }

                int width = image.Width;
                int height = image.Height;
                var rect = new Rectangle(0, 0, width, height);
                var data = image.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
                int stride = Math.Abs(data.Stride);
                byte[] pixels = new byte[stride * height];
                Marshal.Copy(data.Scan0, pixels, 0, pixels.Length);

                bool[] outside = new bool[width * height];
                int[] queue = new int[width * height];
                int head = 0;
                int tail = 0;
                Action<int, int> enqueue = (x, y) => {
                    int flat = y * width + x;
                    if (outside[flat]) return;
                    int pixel = y * stride + x * 4;
                    if (!IsBackground(pixels, pixel)) return;
                    outside[flat] = true;
                    queue[tail++] = flat;
                };

                for (int x = 0; x < width; x++) {
                    enqueue(x, 0);
                    enqueue(x, height - 1);
                }
                for (int y = 0; y < height; y++) {
                    enqueue(0, y);
                    enqueue(width - 1, y);
                }

                while (head < tail) {
                    int flat = queue[head++];
                    int x = flat % width;
                    int y = flat / width;
                    if (x > 0) enqueue(x - 1, y);
                    if (x + 1 < width) enqueue(x + 1, y);
                    if (y > 0) enqueue(x, y - 1);
                    if (y + 1 < height) enqueue(x, y + 1);
                }

                for (int flat = 0; flat < outside.Length; flat++) {
                    if (!outside[flat]) continue;
                    int x = flat % width;
                    int y = flat / width;
                    pixels[y * stride + x * 4 + 3] = 0;
                }

                // Remove the light anti-alias fringe immediately touching the cleared area.
                for (int pass = 0; pass < 2; pass++) {
                    var fringe = new List<int>();
                    for (int y = 1; y < height - 1; y++) {
                        for (int x = 1; x < width - 1; x++) {
                            int flat = y * width + x;
                            if (outside[flat]) continue;
                            int pixel = y * stride + x * 4;
                            int b = pixels[pixel];
                            int g = pixels[pixel + 1];
                            int r = pixels[pixel + 2];
                            int min = Math.Min(r, Math.Min(g, b));
                            int max = Math.Max(r, Math.Max(g, b));
                            if (min < 225 || max - min > 42) continue;
                            if (outside[flat - 1] || outside[flat + 1] || outside[flat - width] || outside[flat + width]) {
                                fringe.Add(flat);
                            }
                        }
                    }
                    foreach (int flat in fringe) {
                        outside[flat] = true;
                        int x = flat % width;
                        int y = flat / width;
                        pixels[y * stride + x * 4 + 3] = 0;
                    }
                }

                Marshal.Copy(pixels, 0, data.Scan0, pixels.Length);
                image.UnlockBits(data);

                int minX = width;
                int minY = height;
                int maxX = -1;
                int maxY = -1;
                for (int y = 0; y < height; y++) {
                    for (int x = 0; x < width; x++) {
                        int pixel = y * stride + x * 4;
                        if (pixels[pixel + 3] <= 8) continue;
                        minX = Math.Min(minX, x);
                        minY = Math.Min(minY, y);
                        maxX = Math.Max(maxX, x);
                        maxY = Math.Max(maxY, y);
                    }
                }
                if (maxX < minX || maxY < minY) throw new InvalidOperationException("No foreground remained: " + inputPath);

                minX = Math.Max(0, minX - padding);
                minY = Math.Max(0, minY - padding);
                maxX = Math.Min(width - 1, maxX + padding);
                maxY = Math.Min(height - 1, maxY + padding);
                var cropRect = Rectangle.FromLTRB(minX, minY, maxX + 1, maxY + 1);
                using (var cropped = image.Clone(cropRect, PixelFormat.Format32bppArgb)) {
                    cropped.Save(outputPath, ImageFormat.Png);
                }
            }
        }
    }
}
'@
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$assets = [ordered]@{
    "panel.png" = "*07_05_43 (2).png"
    "header.png" = "*07_05_43 (3).png"
    "close.png" = "*07_05_43 (4).png"
    "center.png" = "*07_05_43 (6).png"
    "pointer.png" = "*07_05_44 (7).png"
    "free-spin-ready.png" = "*07_05_44 (8).png"
    "spin-now.png" = "*07_05_45 (9).png"
    "bonus-spins.png" = "*07_05_45 (10).png"
    "wheel.png" = "*07_06_38.png"
}

foreach ($entry in $assets.GetEnumerator()) {
    $match = @(Get-ChildItem -LiteralPath $SourceRoot -File -Filter $entry.Value)
    if ($match.Count -ne 1) {
        throw "Expected one supplied Spin UI asset matching $($entry.Value), found $($match.Count)"
    }
    $inputPath = $match[0].FullName
    $outputPath = Join-Path $OutputRoot $entry.Key
    [PunchWall.AlphaBackgroundCleaner]::CleanAndCrop($inputPath, $outputPath, 4)
}

$reference = @(Get-ChildItem -LiteralPath $SourceRoot -File -Filter "*07_05_42 (1).png")
if ($reference.Count -ne 1) {
    throw "Expected one Spin UI reference image, found $($reference.Count)"
}
Copy-Item -LiteralPath $reference[0].FullName -Destination (Join-Path $OutputRoot "reference.png") -Force

Get-ChildItem -LiteralPath $OutputRoot -Filter *.png |
    Select-Object Name, Length |
    Format-Table -AutoSize
