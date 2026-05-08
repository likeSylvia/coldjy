# Generate a 1024x1024 AppIcon using System.Drawing on Windows.
# Output: ColdTools/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png

Add-Type -AssemblyName System.Drawing

$size = 1024
$out = Join-Path $PSScriptRoot "..\ColdTools\Assets.xcassets\AppIcon.appiconset\AppIcon-1024.png"
$out = [System.IO.Path]::GetFullPath($out)

$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

# Gradient background (cold navy)
$rect = New-Object System.Drawing.Rectangle 0, 0, $size, $size
$topColor = [System.Drawing.Color]::FromArgb(255, 30, 60, 90)
$bottomColor = [System.Drawing.Color]::FromArgb(255, 12, 24, 42)
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
  $rect, $topColor, $bottomColor, 90)
$g.FillRectangle($grad, $rect)

# Soft glow ellipse
$glowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(55, 120, 190, 255))
$g.FillEllipse($glowBrush, [int]($size * 0.1), [int](-$size * 0.15), [int]($size * 0.8), [int]($size * 0.7))

# Outer ring
$ringPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(220, 180, 220, 255)), 10
$cx = $size / 2
$cy = $size / 2
$r = [int]($size * 0.30)
$g.DrawEllipse($ringPen, $cx - $r, $cy - $r, $r * 2, $r * 2)

# Snowflake
$snowPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(240, 240, 250, 255)), 18
$snowPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$snowPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

$arms = 6
$armLen = $size * 0.22
for ($i = 0; $i -lt $arms; $i++) {
    $angle = [Math]::PI * 2 / $arms * $i
    $ex = $cx + [Math]::Cos($angle) * $armLen
    $ey = $cy + [Math]::Sin($angle) * $armLen
    $g.DrawLine($snowPen, [float]$cx, [float]$cy, [float]$ex, [float]$ey)

    # Two side branches
    foreach ($sign in @(-1, 1)) {
        $ba = $angle + $sign * ([Math]::PI / 180 * 35)
        $bx1 = $cx + [Math]::Cos($angle) * $armLen * 0.55
        $by1 = $cy + [Math]::Sin($angle) * $armLen * 0.55
        $bx2 = $bx1 + [Math]::Cos($ba) * $armLen * 0.22
        $by2 = $by1 + [Math]::Sin($ba) * $armLen * 0.22
        $sideBranchPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(240, 240, 250, 255)), 12
        $sideBranchPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $sideBranchPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $g.DrawLine($sideBranchPen, [float]$bx1, [float]$by1, [float]$bx2, [float]$by2)
        $sideBranchPen.Dispose()
    }
}

# Center dot
$dotBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$dotR = [int]($size * 0.04)
$g.FillEllipse($dotBrush, $cx - $dotR, $cy - $dotR, $dotR * 2, $dotR * 2)

# Save
$dir = [System.IO.Path]::GetDirectoryName($out)
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)

$grad.Dispose()
$glowBrush.Dispose()
$ringPen.Dispose()
$snowPen.Dispose()
$dotBrush.Dispose()
$g.Dispose()
$bmp.Dispose()

Write-Host "Generated: $out"
