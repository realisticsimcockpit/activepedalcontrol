param(
    [string]$OutputDir = "",
    [string]$VariantSuffix = "Basic V1.0"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$dashboardBaseName = "Active Pedal Control"
$dashboardName = $dashboardBaseName
if (![string]::IsNullOrWhiteSpace($VariantSuffix)) {
    $dashboardName = "$dashboardBaseName $VariantSuffix"
}
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path (Join-Path $root "dist") $dashboardName
}

$djsonPath = Join-Path $OutputDir "$dashboardName.djson"
$metadataPath = Join-Path $OutputDir "$dashboardName.djson.metadata"
$previewPath = Join-Path $OutputDir "$dashboardName.djson.png"
$screenPreviewPath0 = Join-Path $OutputDir "$dashboardName.djson.00.png"
$screenPreviewPath1 = Join-Path $OutputDir "$dashboardName.djson.01.png"
$screenPreviewPath2 = Join-Path $OutputDir "$dashboardName.djson.02.png"
$screenPreviewPath3 = Join-Path $OutputDir "$dashboardName.djson.03.png"
$carClassesPath = Join-Path $OutputDir "$dashboardName.djson.carclasses"
$zipPath = Join-Path (Split-Path -Parent $OutputDir) "$dashboardName.zip"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$script:fontFamily = "Segoe UI"

if (Test-Path -LiteralPath $OutputDir) {
    Remove-Item -LiteralPath $OutputDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $OutputDir "JavascriptExtensions") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $OutputDir "Videos") | Out-Null

$script:sid = 1

function Next-Sid {
    $value = $script:sid
    $script:sid = $script:sid + 1
    return $value
}

function Border([int]$radius, [string]$color = "#FF27303B", [int]$size = 1) {
    [ordered]@{
        BorderColor = $color
        BorderTop = $size
        BorderBottom = $size
        BorderLeft = $size
        BorderRight = $size
        RadiusTopLeft = $radius
        RadiusTopRight = $radius
        RadiusBottomLeft = $radius
        RadiusBottomRight = $radius
    }
}

function Bind-Text([string]$expression) {
    [ordered]@{
        Text = [ordered]@{
            Formula = [ordered]@{ Expression = $expression }
            Mode = 2
            TargetPropertyName = "Text"
        }
    }
}

function Bind-TextJs([string]$expression) {
    [ordered]@{
        Text = [ordered]@{
            Formula = [ordered]@{
                Interpreter = 1
                Expression = $expression
            }
            Mode = 2
            TargetPropertyName = "Text"
        }
    }
}

function Bind-NumberJs([string]$property, [string]$expression) {
    [ordered]@{
        $property = [ordered]@{
            Formula = [ordered]@{
                Interpreter = 1
                Expression = $expression
            }
            Mode = 2
            TargetPropertyName = $property
        }
    }
}

function Bind-GaugeFill([string]$pedal, [double]$top, [double]$height) {
    $prop = "ActivePedalBridge.$pedal.Input"
    [ordered]@{
        Height = [ordered]@{
            Formula = [ordered]@{
                Interpreter = 1
                Expression = "var v = Number(`$prop('$prop')) || 0; v = Math.max(0, Math.min(100, v)); return $height * v / 100;"
            }
            Mode = 2
            TargetPropertyName = "Height"
        }
        Top = [ordered]@{
            Formula = [ordered]@{
                Interpreter = 1
                Expression = "var v = Number(`$prop('$prop')) || 0; v = Math.max(0, Math.min(100, v)); return $top + $height - ($height * v / 100);"
            }
            Mode = 2
            TargetPropertyName = "Top"
        }
    }
}

function Bind-Visible([string]$expression) {
    [ordered]@{
        Visible = [ordered]@{
            Formula = [ordered]@{ Expression = $expression }
            Mode = 2
            TargetPropertyName = "Visible"
        }
    }
}

function Merge-Bindings([object[]]$bindings) {
    $merged = [ordered]@{}
    foreach ($binding in $bindings) {
        if ($null -eq $binding) { continue }
        foreach ($key in $binding.Keys) {
            $merged[$key] = $binding[$key]
        }
    }
    return $merged
}

function Bind-TextVisible([string]$textExpression, [string]$visibleExpression) {
    [ordered]@{
        Text = [ordered]@{
            Formula = [ordered]@{ Expression = $textExpression }
            Mode = 2
            TargetPropertyName = "Text"
        }
        Visible = [ordered]@{
            Formula = [ordered]@{ Expression = $visibleExpression }
            Mode = 2
            TargetPropertyName = "Visible"
        }
    }
}

function TextItem(
    [string]$name,
    [string]$text,
    [double]$left,
    [double]$top,
    [double]$width,
    [double]$height,
    [double]$fontSize,
    [string]$color = "#FFFFFFFF",
    [string]$background = "#00FFFFFF",
    [string]$weight = "Normal",
    [int]$horizontal = 0,
    [int]$vertical = 1,
    [object]$bindings = $null,
    [object]$border = $null
) {
    $item = [ordered]@{
        "`$type" = "SimHub.Plugins.OutputPlugins.GraphicalDash.Models.TextItem, SimHub.Plugins"
        IsTextItem = $true
        Font = $script:fontFamily
        FontWeight = $weight
        FontSize = $fontSize
        Text = $text
        TextColor = $color
        HorizontalAlignment = $horizontal
        VerticalAlignment = $vertical
        BackgroundColor = $background
        Height = $height
        Left = $left
        Top = $top
        Visible = $true
        Width = $width
        Name = $name
        Sid = (Next-Sid)
    }
    if ($null -ne $bindings) { $item.Bindings = $bindings }
    if ($null -ne $border) { $item.BorderStyle = $border }
    return $item
}

function RectangleItem(
    [string]$name,
    [double]$left,
    [double]$top,
    [double]$width,
    [double]$height,
    [string]$background,
    [object]$border = $null,
    [object]$bindings = $null
) {
    $item = [ordered]@{
        "`$type" = "SimHub.Plugins.OutputPlugins.GraphicalDash.Models.RectangleItem, SimHub.Plugins"
        IsRectangleItem = $true
        BackgroundColor = $background
        Height = $height
        Left = $left
        Top = $top
        Visible = $true
        Width = $width
        Name = $name
        Sid = (Next-Sid)
    }
    if ($null -ne $border) { $item.BorderStyle = $border }
    if ($null -ne $bindings) { $item.Bindings = $bindings }
    return $item
}

function EllipseItem(
    [string]$name,
    [double]$left,
    [double]$top,
    [double]$size,
    [string]$fill,
    [object]$bindings = $null
) {
    $item = [ordered]@{
        "`$type" = "SimHub.Plugins.OutputPlugins.GraphicalDash.Models.EllipseItem, SimHub.Plugins"
        FillColor = $fill
        EllipseColor = "#00FFFFFF"
        EllipseThickness = 0.0
        BackgroundColor = "#00FFFFFF"
        Height = $size
        Left = $left
        Top = $top
        Visible = $true
        Width = $size
        Name = $name
        Sid = (Next-Sid)
    }
    if ($null -ne $bindings) { $item.Bindings = $bindings }
    return $item
}

function ButtonItem(
    [string]$name,
    [double]$left,
    [double]$top,
    [double]$width,
    [double]$height,
    [string]$action,
    [object]$bindings = $null
) {
    $item = [ordered]@{
        "`$type" = "SimHub.Plugins.OutputPlugins.GraphicalDash.Models.ButtonItem, SimHub.Plugins"
        SimulatedKey = 0
        SimulatedKeyV2 = [ordered]@{
            Win = $false
            Ctrl = $false
            Alt = $false
            Shift = $false
        }
        SimulateKey = $false
        TriggerAction = $action
        TriggerSimHubInputName = $name
        AutoSize = $false
        BackgroundColor = "#01FFFFFF"
        Height = $height
        Left = $left
        Top = $top
        Visible = $true
        Width = $width
        Name = $name
        Sid = (Next-Sid)
    }
    if ($null -ne $bindings) { $item.Bindings = $bindings }
    return $item
}

function Add-ParameterRow(
    [System.Collections.ArrayList]$items,
    [string]$pedal,
    [string]$label,
    [string]$property,
    [double]$left,
    [double]$top,
    [string]$accent
) {
    $buttonColor = "#FF202734"
    $valueBg = "#FF0E1219"

    [void]$items.Add((TextItem "$pedal-$property-label" $label $left ($top + 28) 310 78 30 "#FF9CA7B4" "#00FFFFFF" "SemiBold" 0 1))
    [void]$items.Add((TextItem "$pedal-$property-minus-face" "-" ($left + 330) $top 184 128 76 "#FFFFFFFF" $buttonColor "Bold" 1 1 $null (Border 8 "#FF303946" 1)))
    [void]$items.Add((ButtonItem "$pedal-$property-minus" ($left + 330) $top 184 128 "ActivePedalBridge.$pedal.$property.Down"))
    [void]$items.Add((TextItem "$pedal-$property-value" "--" ($left + 540) $top 260 128 42 "#FFFFFFFF" $valueBg "Bold" 1 1 (Bind-Text "[ActivePedalBridge.$pedal.${property}Text]") (Border 8 "#FF303946" 1)))
    [void]$items.Add((TextItem "$pedal-$property-plus-face" "+" ($left + 826) $top 184 128 72 "#FF0B0E13" $accent "Bold" 1 1 $null (Border 8 $accent 1)))
    [void]$items.Add((ButtonItem "$pedal-$property-plus" ($left + 826) $top 184 128 "ActivePedalBridge.$pedal.$property.Up"))
}

function Add-EffectChip(
    [System.Collections.ArrayList]$items,
    [string]$pedal,
    [string]$effectKey,
    [string]$caption,
    [double]$left,
    [double]$top
) {
    $state = "[ActivePedalBridge.$pedal.Effect.$effectKey]"

    [void]$items.Add((TextItem "$pedal-$effectKey-face" $caption $left $top 560 128 28 "#FFFFFFFF" "#FF202734" "Bold" 1 1 (Bind-Visible "1-$state") (Border 8 "#FF303946" 1)))
    [void]$items.Add((TextItem "$pedal-$effectKey-active-face" $caption $left $top 560 128 28 "#FF0B0E13" "#FFFF9D2E" "Bold" 1 1 (Bind-Visible $state) (Border 8 "#FFFF9D2E" 1)))
    [void]$items.Add((ButtonItem "$pedal-$effectKey-toggle" $left $top 560 128 "ActivePedalBridge.$pedal.Effect.$effectKey.Toggle"))
}

function Add-ConfigRow(
    [System.Collections.ArrayList]$items,
    [string]$pedal,
    [int]$slot,
    [double]$left,
    [double]$top,
    [double]$width,
    [string]$accent
) {
    $visible = "[ActivePedalBridge.$pedal.Config.$slot.Visible]"
    $active = "[ActivePedalBridge.$pedal.Config.$slot.Active]"
    $startup = "[ActivePedalBridge.$pedal.Config.$slot.Startup]"
    $inactiveVisible = "$visible*(1-$active)"
    $activeVisible = "$visible*$active"
    $startupVisible = "$visible*$startup"

    [void]$items.Add((RectangleItem "$pedal-config-$slot-face" $left $top $width 150 "#FF202734" (Border 8 "#FF303946" 1) (Bind-Visible $inactiveVisible)))
    [void]$items.Add((RectangleItem "$pedal-config-$slot-active-face" $left $top $width 150 "#FFFF9D2E" (Border 8 "#FFFF9D2E" 1) (Bind-Visible $activeVisible)))
    [void]$items.Add((TextItem "$pedal-config-$slot-name" "--" ($left + 28) ($top + 34) ($width - 250) 82 32 "#FFFFFFFF" "#00FFFFFF" "Bold" 0 1 (Bind-TextVisible "[ActivePedalBridge.$pedal.Config.$slot.Name]" $inactiveVisible)))
    [void]$items.Add((TextItem "$pedal-config-$slot-active-name" "--" ($left + 28) ($top + 34) ($width - 250) 82 32 "#FF0B0E13" "#00FFFFFF" "Bold" 0 1 (Bind-TextVisible "[ActivePedalBridge.$pedal.Config.$slot.Name]" $activeVisible)))

    [void]$items.Add((TextItem "$pedal-config-$slot-active-badge" "ACTIVE" ($left + $width - 188) ($top + 20) 158 44 20 "#FF0B0E13" "#FFFFFFFF" "Bold" 1 1 (Bind-Visible $activeVisible) (Border 6 "#00FFFFFF" 0)))
    [void]$items.Add((TextItem "$pedal-config-$slot-startup-badge" "STARTUP" ($left + $width - 188) ($top + 86) 158 44 20 "#FFFFFFFF" "#FF111720" "Bold" 1 1 (Bind-Visible $startupVisible) (Border 6 $accent 1)))
    [void]$items.Add((ButtonItem "$pedal-config-$slot-apply" $left $top $width 150 "ActivePedalBridge.$pedal.Config.$slot.Apply" (Bind-Visible $visible)))
}

function Add-ConfigColumn(
    [System.Collections.ArrayList]$items,
    [string]$pedal,
    [string]$title,
    [double]$left,
    [string]$accent
) {
    [void]$items.Add((RectangleItem "$pedal-config-accent" $left 114 560 6 $accent $null))
    [void]$items.Add((TextItem "$pedal-config-title" $title $left 62 560 54 30 "#FFFFFFFF" "#00FFFFFF" "Bold" 0 1))

    for ($slot = 1; $slot -le 5; $slot++) {
        Add-ConfigRow $items $pedal $slot $left (150 + (($slot - 1) * 174)) 560 $accent
    }
}

function Add-ConfigPage(
    [System.Collections.ArrayList]$items
) {
    [void]$items.Add((TextItem "configs-page-title" "CONFIG LIST" 40 28 320 50 28 "#FF9CA7B4" "#00FFFFFF" "Bold" 0 1))
    Add-ConfigColumn $items "Clutch" "CLUTCH" 40 "#FF35C2FF"
    Add-ConfigColumn $items "Brake" "BRAKE" 680 "#FFFF4D5E"
    Add-ConfigColumn $items "Throttle" "THROTTLE" 1320 "#FF45D483"
}

function Add-PedalCard(
    [System.Collections.ArrayList]$items,
    [string]$pedal,
    [string]$title,
    [double]$left,
    [string]$accent
) {
    $top = 72
    $w = 1840
    $h = 984
    $innerLeft = $left + 80

    [void]$items.Add((RectangleItem "$pedal-card" $left $top $w $h "#FF141922" (Border 8 "#FF27303B" 1)))
    [void]$items.Add((RectangleItem "$pedal-accent" $left $top $w 8 $accent $null))
    [void]$items.Add((TextItem "$pedal-title" $title $innerLeft ($top + 28) 320 64 38 "#FFFFFFFF" "#00FFFFFF" "Bold" 0 1))
    [void]$items.Add((EllipseItem "$pedal-ready-dot" ($left + 1598) ($top + 52) 26 "#FF45D483" (Bind-Visible "[ActivePedalBridge.$pedal.ConnectionReady]")))
    [void]$items.Add((EllipseItem "$pedal-off-dot" ($left + 1598) ($top + 52) 26 "#FFFF4D5E" (Bind-Visible "1-[ActivePedalBridge.$pedal.ConnectionReady]")))
    [void]$items.Add((TextItem "$pedal-status" "--" ($left + 1644) ($top + 34) 150 60 26 "#FFFFFFFF" "#00FFFFFF" "Bold" 0 1 (Bind-Text "[ActivePedalBridge.$pedal.ConnectionStatus]")))

    $gaugeTop = $top + 154
    $gaugeHeight = 600
    $gaugeLeft = $left + 1100
    [void]$items.Add((RectangleItem "$pedal-input-track" $gaugeLeft $gaugeTop 112 $gaugeHeight "#FF0E1219" (Border 8 "#FF303946" 1)))
    [void]$items.Add((RectangleItem "$pedal-input-fill" ($gaugeLeft + 10) ($gaugeTop + $gaugeHeight) 92 0 $accent $null (Bind-GaugeFill $pedal $gaugeTop $gaugeHeight)))
    [void]$items.Add((TextItem "$pedal-input-value" "--" ($gaugeLeft - 2) ($gaugeTop + $gaugeHeight + 18) 116 54 28 "#FFFFFFFF" "#00FFFFFF" "Bold" 1 1 (Bind-Text "[ActivePedalBridge.$pedal.InputText]")))

    Add-ParameterRow $items $pedal "TRAVEL MIN" "TravelMin" $innerLeft ($top + 154) $accent
    Add-ParameterRow $items $pedal "TRAVEL MAX" "TravelMax" $innerLeft ($top + 310) $accent
    Add-ParameterRow $items $pedal "PRELOAD" "Preload" $innerLeft ($top + 466) $accent
    Add-ParameterRow $items $pedal "MAX FORCE" "MaxForce" $innerLeft ($top + 622) $accent

    [void]$items.Add((TextItem "$pedal-effects-label" "EFFECTS" ($left + 1280) ($top + 94) 220 42 24 "#FF9CA7B4" "#00FFFFFF" "Bold" 0 1))

    $effects = @(
        @("ABS", "ABS"),
        @("RPM", "RPM"),
        @("Gforce", "G-FORCE"),
        @("WheelSlip", "WHEEL SLIP"),
        @("RoadImpact", "ROAD IMPACT")
    )

    $effectTop = $top + 154
    for ($i = 0; $i -lt $effects.Count; $i++) {
        Add-EffectChip $items $pedal $effects[$i][0] $effects[$i][1] ($left + 1280) ($effectTop + $i * 154)
    }
}

function New-DashboardPreview([string]$path, [object[]]$pedals) {
    Add-Type -AssemblyName System.Drawing

    $bitmap = New-Object System.Drawing.Bitmap 1920, 1080
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml("#0B0E13"))

    $fontTitle = New-Object System.Drawing.Font $script:fontFamily, 38, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $fontSmall = New-Object System.Drawing.Font $script:fontFamily, 26, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $fontLabel = New-Object System.Drawing.Font $script:fontFamily, 30, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $fontChip = New-Object System.Drawing.Font $script:fontFamily, 28, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $fontButton = New-Object System.Drawing.Font $script:fontFamily, 72, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)

    $white = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#FFFFFFFF"))
    $muted = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#FF9CA7B4"))
    $card = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#FF141922"))
    $button = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#FF202734"))

    $labels = @("TRAVEL MIN", "TRAVEL MAX", "PRELOAD", "MAX FORCE")
    $effects = @("ABS", "RPM", "G-FORCE", "WHEEL SLIP", "ROAD IMPACT")
    $pageTop = 72

    foreach ($pedal in $pedals) {
        $left = [int]$pedal.Left
        $accent = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($pedal.Accent))
        $graphics.FillRectangle($card, $left, $pageTop, 1840, 984)
        $graphics.FillRectangle($accent, $left, $pageTop, 1840, 8)
        $graphics.DrawString($pedal.Name, $fontTitle, $white, ($left + 80), ($pageTop + 28))
        $graphics.FillEllipse($accent, ($left + 1598), ($pageTop + 52), 26, 26)
        $graphics.DrawString("USB", $fontSmall, $white, ($left + 1644), ($pageTop + 34))

        $gaugeX = $left + 1100
        $gaugeY = $pageTop + 154
        $gaugeH = 600
        $fillH = 384
        $graphics.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#FF0E1219"))), $gaugeX, $gaugeY, 112, $gaugeH)
        $graphics.FillRectangle($accent, ($gaugeX + 10), ($gaugeY + $gaugeH - $fillH), 92, $fillH)
        $graphics.DrawString("64%", $fontSmall, $white, ($gaugeX - 2), ($gaugeY + $gaugeH + 12))

        for ($i = 0; $i -lt $labels.Count; $i++) {
            $y = ($pageTop + 154) + ($i * 156)
            $graphics.DrawString($labels[$i], $fontLabel, $muted, ($left + 80), ($y + 28))
            $graphics.FillRectangle($button, ($left + 410), $y, 184, 128)
            $graphics.FillRectangle($button, ($left + 620), $y, 260, 128)
            $graphics.FillRectangle($accent, ($left + 906), $y, 184, 128)
            $graphics.DrawString("-", $fontButton, $white, ($left + 482), ($y + 14))
            $graphics.DrawString("--", $fontSmall, $white, ($left + 734), ($y + 45))
            $graphics.DrawString("+", $fontButton, (New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#0B0E13"))), ($left + 970), ($y + 14))
        }

        $graphics.DrawString("EFFECTS", $fontLabel, $muted, ($left + 1280), ($pageTop + 94))
        for ($i = 0; $i -lt $effects.Count; $i++) {
            $x = $left + 1280
            $y = ($pageTop + 154) + ($i * 154)
            $graphics.FillRectangle($button, $x, $y, 560, 128)
            $graphics.DrawString($effects[$i], $fontChip, $white, ($x + 28), ($y + 48))
        }
        $accent.Dispose()
    }

    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
    $fontTitle.Dispose()
    $fontSmall.Dispose()
    $fontLabel.Dispose()
    $fontChip.Dispose()
    $fontButton.Dispose()
    $white.Dispose()
    $muted.Dispose()
    $card.Dispose()
    $button.Dispose()
}

function Get-ConfigPreviewNames {
    $configPath = "C:\Program Files (x86)\SimHub\PluginsData\Common\DiyFfbPedal\configs"
    if (Test-Path -LiteralPath $configPath) {
        $names = @(Get-ChildItem -LiteralPath $configPath -Filter "*.json" -File | Select-Object -First 5 | ForEach-Object { $_.BaseName })
        if ($names.Count -gt 0) {
            return $names
        }
    }

    return @("Preset 1", "Preset 2", "Preset 3")
}

function New-ConfigPreview([string]$path, [string[]]$configNames) {
    Add-Type -AssemblyName System.Drawing

    $bitmap = New-Object System.Drawing.Bitmap 1920, 1080
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml("#0B0E13"))

    $fontTitle = New-Object System.Drawing.Font $script:fontFamily, 28, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $fontColumn = New-Object System.Drawing.Font $script:fontFamily, 30, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $fontName = New-Object System.Drawing.Font $script:fontFamily, 32, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $fontBadge = New-Object System.Drawing.Font $script:fontFamily, 20, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)

    $white = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#FFFFFFFF"))
    $dark = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#FF0B0E13"))
    $muted = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#FF9CA7B4"))
    $row = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#FF202734"))
    $startup = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#FF111720"))
    $active = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#FFFF9D2E"))

    $graphics.DrawString("CONFIG LIST", $fontTitle, $muted, 40, 28)

    $columns = @(
        @{Name="CLUTCH"; Left=40; Accent="#FF35C2FF"},
        @{Name="BRAKE"; Left=680; Accent="#FFFF4D5E"},
        @{Name="THROTTLE"; Left=1320; Accent="#FF45D483"}
    )

    foreach ($column in $columns) {
        $left = [int]$column.Left
        $accent = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($column.Accent))
        $graphics.DrawString($column.Name, $fontColumn, $white, $left, 62)
        $graphics.FillRectangle($accent, $left, 114, 560, 6)

        for ($i = 0; $i -lt [Math]::Min(5, $configNames.Count); $i++) {
            $top = 150 + ($i * 174)
            $isActive = $i -eq 0
            if ($isActive) {
                $graphics.FillRectangle($active, $left, $top, 560, 150)
                $graphics.DrawString($configNames[$i], $fontName, $dark, ($left + 28), ($top + 48))
                $graphics.FillRectangle($white, ($left + 372), ($top + 20), 158, 44)
                $graphics.DrawString("ACTIVE", $fontBadge, $dark, ($left + 415), ($top + 31))
            } else {
                $graphics.FillRectangle($row, $left, $top, 560, 150)
                $graphics.DrawString($configNames[$i], $fontName, $white, ($left + 28), ($top + 48))
            }

            if ($i -eq 1) {
                $graphics.FillRectangle($startup, ($left + 372), ($top + 86), 158, 44)
                $graphics.DrawString("STARTUP", $fontBadge, $white, ($left + 401), ($top + 97))
            }
        }

        $accent.Dispose()
    }

    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
    $fontTitle.Dispose()
    $fontColumn.Dispose()
    $fontName.Dispose()
    $fontBadge.Dispose()
    $white.Dispose()
    $dark.Dispose()
    $muted.Dispose()
    $row.Dispose()
    $startup.Dispose()
    $active.Dispose()
}

$itemsConfigs = New-Object System.Collections.ArrayList
Add-ConfigPage $itemsConfigs

$brakeAccent = "#FFFF4D5E"
$throttleAccent = "#FF45D483"
$clutchAccent = "#FF35C2FF"

$itemsBrake = New-Object System.Collections.ArrayList
Add-PedalCard $itemsBrake "Brake" "BRAKE" 40 $brakeAccent

$itemsThrottle = New-Object System.Collections.ArrayList
Add-PedalCard $itemsThrottle "Throttle" "THROTTLE" 40 $throttleAccent

$itemsClutch = New-Object System.Collections.ArrayList
Add-PedalCard $itemsClutch "Clutch" "CLUTCH" 40 $clutchAccent

$screenBackground = "#FF0B0E13"
$dashboardDescription = "Basic V1.0 touch control surface for active pedals through SimHub plugin data"
$dashboardVersion = "Basic V1.0"

$screenConfigs = [ordered]@{
    Name = "Configs"
    InGameScreen = $true
    IdleScreen = $true
    PitScreen = $true
    ScreenId = [guid]::NewGuid().ToString()
    IsForegroundLayer = $false
    IsBackgroundLayer = $false
    BackgroundColor = $screenBackground
    Background = "None"
    Items = $itemsConfigs
}

$screenBrake = [ordered]@{
    Name = "Brake"
    InGameScreen = $true
    IdleScreen = $true
    PitScreen = $true
    ScreenId = [guid]::NewGuid().ToString()
    IsForegroundLayer = $false
    IsBackgroundLayer = $false
    BackgroundColor = $screenBackground
    Background = "None"
    Items = $itemsBrake
}

$screenThrottle = [ordered]@{
    Name = "Throttle"
    InGameScreen = $true
    IdleScreen = $true
    PitScreen = $true
    ScreenId = [guid]::NewGuid().ToString()
    IsForegroundLayer = $false
    IsBackgroundLayer = $false
    BackgroundColor = $screenBackground
    Background = "None"
    Items = $itemsThrottle
}

$screenClutch = [ordered]@{
    Name = "Clutch"
    InGameScreen = $true
    IdleScreen = $true
    PitScreen = $true
    ScreenId = [guid]::NewGuid().ToString()
    IsForegroundLayer = $false
    IsBackgroundLayer = $false
    BackgroundColor = $screenBackground
    Background = "None"
    Items = $itemsClutch
}

$metadata = [ordered]@{
    Category = "Controls"
    Title = $dashboardName
    Description = $dashboardDescription
    Author = "Realistic Simcockpit"
    ScreenCount = 4.0
    InGameScreensIndexs = @(0, 1, 2, 3)
    IdleScreensIndexs = @(0, 1, 2, 3)
    MainPreviewIndex = 0
    IsOverlay = $false
    ShowInTaskBar = $true
    Width = 1920.0
    Height = 1080.0
    OverlaySizeWarning = $false
    MetadataVersion = 2.0
    EnableOnDashboardMessaging = $true
    PitScreensIndexs = @(0, 1, 2, 3)
    DashboardVersion = $dashboardVersion
}

$dashboard = [ordered]@{
    DashboardDebugManager = [ordered]@{ Maximized = $false }
    Version = 2
    Id = [guid]::NewGuid().ToString()
    BaseHeight = 1080
    BaseWidth = 1920
    BackgroundColor = $screenBackground
    Screens = @($screenConfigs, $screenBrake, $screenThrottle, $screenClutch)
    SnapToGrid = $false
    HideLabels = $false
    ShowForeground = $true
    ForegroundOpacity = 50.0
    ShowBackground = $true
    BackgroundOpacity = 50.0
    ShowBoundingRectangles = $false
    GridSize = 10
    Images = @()
    Metadata = $metadata
    ShowOnScreenControls = $true
    IsOverlay = $false
    EnableClickThroughOverlay = $true
    EnableOnDashboardMessaging = $true
}

$json = $dashboard | ConvertTo-Json -Depth 32 -Compress
[System.IO.File]::WriteAllText($djsonPath, $json, $utf8NoBom)
[System.IO.File]::WriteAllText($metadataPath, ($metadata | ConvertTo-Json -Depth 16), $utf8NoBom)
[System.IO.File]::WriteAllText($carClassesPath, "[]", $utf8NoBom)
$configPreviewNames = @(Get-ConfigPreviewNames)
New-ConfigPreview $previewPath $configPreviewNames
Copy-Item -LiteralPath $previewPath -Destination $screenPreviewPath0 -Force
New-DashboardPreview $screenPreviewPath1 @(
    @{Name="BRAKE"; Left=40; Accent="#FF4D5E"}
)
New-DashboardPreview $screenPreviewPath2 @(
    @{Name="THROTTLE"; Left=40; Accent="#45D483"}
)
New-DashboardPreview $screenPreviewPath3 @(
    @{Name="CLUTCH"; Left=40; Accent="#35C2FF"}
)

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($OutputDir, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)

Write-Host "OK: $OutputDir"
Write-Host "OK: $zipPath"
