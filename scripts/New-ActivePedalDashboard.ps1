param(
    [string]$OutputDir = "",
    [ValidateSet("Basic", "GT1")]
    [string]$Theme = "Basic",
    [string]$VariantSuffix = ""
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$dashboardBaseName = "Active Pedal Control"
if ([string]::IsNullOrWhiteSpace($VariantSuffix)) {
    $VariantSuffix = if ($Theme -eq "GT1") { "GT1 V1.0" } else { "Basic V1.0" }
}
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
$script:isGt1 = $Theme -eq "GT1"
$script:fontFamily = if ($script:isGt1) { "Bahnschrift SemiCondensed" } else { "Segoe UI" }
$script:signature = "ACTIVE PEDAL CONTROL by REALISTIC SIMCOCKPIT"

if ($script:isGt1) {
    $script:colors = [ordered]@{
        Background = "#FF050607"
        Card = "#FF0A0C0D"
        Panel = "#FF111416"
        Value = "#FF080A0B"
        Border = "#FF65706D"
        Muted = "#FF8D9592"
        White = "#FFFFFFFF"
        Active = "#FFF2A000"
        Status = "#FF10C8E8"
        HeaderAccent = "#FFFF352D"
    }
    $script:radius = 3
    $script:borderSize = 2
} else {
    $script:colors = [ordered]@{
        Background = "#FF0B0E13"
        Card = "#FF141922"
        Panel = "#FF202734"
        Value = "#FF0E1219"
        Border = "#FF303946"
        Muted = "#FF9CA7B4"
        White = "#FFFFFFFF"
        Active = "#FFFF9D2E"
        Status = "#FF35C2FF"
        HeaderAccent = "#FFFF4D5E"
    }
    $script:radius = 8
    $script:borderSize = 1
}

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

function Add-HeaderBrand(
    [System.Collections.ArrayList]$items,
    [string]$pageTitle = ""
) {
    if ($script:isGt1) {
        [void]$items.Add((RectangleItem "header-left-accent" 40 12 6 42 $script:colors.HeaderAccent $null))
        [void]$items.Add((RectangleItem "header-right-accent" 1874 12 6 42 $script:colors.HeaderAccent $null))
        [void]$items.Add((RectangleItem "header-rule" 40 60 1840 2 $script:colors.Border $null))

        if (![string]::IsNullOrWhiteSpace($pageTitle)) {
            [void]$items.Add((TextItem "page-title" $pageTitle 70 8 360 48 34 $script:colors.HeaderAccent "#00FFFFFF" "Bold" 0 1))
        }

        [void]$items.Add((TextItem "dashboard-signature" $script:signature 760 8 1090 48 22 $script:colors.White "#00FFFFFF" "SemiBold" 2 1))
        return
    }

    if (![string]::IsNullOrWhiteSpace($pageTitle)) {
        [void]$items.Add((TextItem "page-title" $pageTitle 40 28 360 50 28 $script:colors.Muted "#00FFFFFF" "Bold" 0 1))
    }
    [void]$items.Add((TextItem "dashboard-signature" $script:signature 920 18 960 42 18 $script:colors.Muted "#00FFFFFF" "SemiBold" 2 1))
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
    $buttonColor = $script:colors.Panel
    $valueBg = $script:colors.Value
    $controlAccent = if ($script:isGt1) { $script:colors.Active } else { $accent }
    $valueSize = if ($script:isGt1) { 48 } else { 42 }
    $labelSize = if ($script:isGt1) { 28 } else { 30 }

    [void]$items.Add((TextItem "$pedal-$property-label" $label $left ($top + 28) 310 78 $labelSize $script:colors.Muted "#00FFFFFF" "SemiBold" 0 1))
    [void]$items.Add((TextItem "$pedal-$property-minus-face" "-" ($left + 330) $top 184 128 76 $script:colors.White $buttonColor "Bold" 1 1 $null (Border $script:radius $script:colors.Border $script:borderSize)))
    [void]$items.Add((ButtonItem "$pedal-$property-minus" ($left + 330) $top 184 128 "ActivePedalBridge.$pedal.$property.Down"))
    [void]$items.Add((TextItem "$pedal-$property-value" "--" ($left + 540) $top 260 128 $valueSize $script:colors.White $valueBg "Bold" 1 1 (Bind-Text "[ActivePedalBridge.$pedal.${property}Text]") (Border $script:radius $script:colors.Border $script:borderSize)))
    $plusBackground = if ($script:isGt1) { $buttonColor } else { $controlAccent }
    $plusText = if ($script:isGt1) { $controlAccent } else { $script:colors.Background }
    [void]$items.Add((TextItem "$pedal-$property-plus-face" "+" ($left + 826) $top 184 128 72 $plusText $plusBackground "Bold" 1 1 $null (Border $script:radius $controlAccent $script:borderSize)))
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

    if ($script:isGt1) {
        [void]$items.Add((RectangleItem "$pedal-$effectKey-face" $left $top 560 128 $script:colors.Panel (Border $script:radius $script:colors.Border $script:borderSize) (Bind-Visible "1-$state")))
        [void]$items.Add((TextItem "$pedal-$effectKey-label" $caption ($left + 32) $top 496 128 30 $script:colors.White "#00FFFFFF" "Bold" 0 1 (Bind-Visible "1-$state")))
        [void]$items.Add((RectangleItem "$pedal-$effectKey-active-face" $left $top 560 128 $script:colors.Active (Border $script:radius $script:colors.Active $script:borderSize) (Bind-Visible $state)))
        [void]$items.Add((TextItem "$pedal-$effectKey-active-label" $caption ($left + 32) $top 496 128 30 $script:colors.Background "#00FFFFFF" "Bold" 0 1 (Bind-Visible $state)))
    } else {
        [void]$items.Add((TextItem "$pedal-$effectKey-face" $caption $left $top 560 128 28 $script:colors.White $script:colors.Panel "Bold" 1 1 (Bind-Visible "1-$state") (Border $script:radius $script:colors.Border $script:borderSize)))
        [void]$items.Add((TextItem "$pedal-$effectKey-active-face" $caption $left $top 560 128 28 $script:colors.Background $script:colors.Active "Bold" 1 1 (Bind-Visible $state) (Border $script:radius $script:colors.Active $script:borderSize)))
    }
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

    [void]$items.Add((RectangleItem "$pedal-config-$slot-face" $left $top $width 150 $script:colors.Panel (Border $script:radius $script:colors.Border $script:borderSize) (Bind-Visible $inactiveVisible)))
    [void]$items.Add((RectangleItem "$pedal-config-$slot-active-face" $left $top $width 150 $script:colors.Active (Border $script:radius $script:colors.Active $script:borderSize) (Bind-Visible $activeVisible)))
    [void]$items.Add((TextItem "$pedal-config-$slot-name" "--" ($left + 28) ($top + 34) ($width - 250) 82 32 $script:colors.White "#00FFFFFF" "Bold" 0 1 (Bind-TextVisible "[ActivePedalBridge.$pedal.Config.$slot.Name]" $inactiveVisible)))
    [void]$items.Add((TextItem "$pedal-config-$slot-active-name" "--" ($left + 28) ($top + 34) ($width - 250) 82 32 $script:colors.Background "#00FFFFFF" "Bold" 0 1 (Bind-TextVisible "[ActivePedalBridge.$pedal.Config.$slot.Name]" $activeVisible)))

    if ($script:isGt1) {
        [void]$items.Add((TextItem "$pedal-config-$slot-active-badge" "ACTIVE" ($left + $width - 188) ($top + 20) 158 44 20 $script:colors.Active $script:colors.Value "Bold" 1 1 (Bind-Visible $activeVisible) (Border 2 $script:colors.Value 1)))
        [void]$items.Add((TextItem "$pedal-config-$slot-startup-badge" "STARTUP" ($left + $width - 188) ($top + 86) 158 44 20 $script:colors.Status $script:colors.Value "Bold" 1 1 (Bind-Visible $startupVisible) (Border 2 $script:colors.Status 1)))
    } else {
        [void]$items.Add((TextItem "$pedal-config-$slot-active-badge" "ACTIVE" ($left + $width - 188) ($top + 20) 158 44 20 $script:colors.Background $script:colors.White "Bold" 1 1 (Bind-Visible $activeVisible) (Border 6 "#00FFFFFF" 0)))
        [void]$items.Add((TextItem "$pedal-config-$slot-startup-badge" "STARTUP" ($left + $width - 188) ($top + 86) 158 44 20 $script:colors.White "#FF111720" "Bold" 1 1 (Bind-Visible $startupVisible) (Border 6 $accent 1)))
    }
    [void]$items.Add((ButtonItem "$pedal-config-$slot-apply" $left $top $width 150 "ActivePedalBridge.$pedal.Config.$slot.Apply" (Bind-Visible $visible)))
}

function Add-ConfigColumn(
    [System.Collections.ArrayList]$items,
    [string]$pedal,
    [string]$title,
    [double]$left,
    [string]$accent
) {
    $titleTop = if ($script:isGt1) { 72 } else { 62 }
    $accentTop = if ($script:isGt1) { 126 } else { 114 }
    [void]$items.Add((RectangleItem "$pedal-config-accent" $left $accentTop 560 6 $accent $null))
    [void]$items.Add((TextItem "$pedal-config-title" $title $left $titleTop 560 54 30 $script:colors.White "#00FFFFFF" "Bold" 0 1))

    for ($slot = 1; $slot -le 5; $slot++) {
        Add-ConfigRow $items $pedal $slot $left (150 + (($slot - 1) * 174)) 560 $accent
    }
}

function Add-ConfigPage(
    [System.Collections.ArrayList]$items
) {
    $pageTitle = if ($script:isGt1) { "PRESETS" } else { "CONFIG LIST" }
    Add-HeaderBrand $items $pageTitle
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

    Add-HeaderBrand $items
    [void]$items.Add((RectangleItem "$pedal-card" $left $top $w $h $script:colors.Card (Border $script:radius $script:colors.Border $script:borderSize)))
    [void]$items.Add((RectangleItem "$pedal-accent" $left $top $w 8 $accent $null))
    $titleColor = if ($script:isGt1) { $accent } else { $script:colors.White }
    [void]$items.Add((TextItem "$pedal-title" $title $innerLeft ($top + 28) 320 64 38 $titleColor "#00FFFFFF" "Bold" 0 1))
    [void]$items.Add((EllipseItem "$pedal-ready-dot" ($left + 1598) ($top + 52) 26 "#FF45D483" (Bind-Visible "[ActivePedalBridge.$pedal.ConnectionReady]")))
    [void]$items.Add((EllipseItem "$pedal-off-dot" ($left + 1598) ($top + 52) 26 "#FFFF4D5E" (Bind-Visible "1-[ActivePedalBridge.$pedal.ConnectionReady]")))
    if (!$script:isGt1) {
        [void]$items.Add((TextItem "$pedal-status" "--" ($left + 1644) ($top + 34) 150 60 26 $script:colors.White "#00FFFFFF" "Bold" 0 1 (Bind-Text "[ActivePedalBridge.$pedal.ConnectionStatus]")))
    }

    $gaugeTop = $top + 154
    $gaugeHeight = 600
    $gaugeLeft = $left + 1100
    $gaugeAccent = if ($script:isGt1) { $script:colors.Active } else { $accent }
    [void]$items.Add((RectangleItem "$pedal-input-track" $gaugeLeft $gaugeTop 112 $gaugeHeight $script:colors.Value (Border $script:radius $script:colors.Border $script:borderSize)))
    [void]$items.Add((RectangleItem "$pedal-input-fill" ($gaugeLeft + 10) ($gaugeTop + $gaugeHeight) 92 0 $gaugeAccent $null (Bind-GaugeFill $pedal $gaugeTop $gaugeHeight)))
    if ($script:isGt1) {
        [void]$items.Add((TextItem "$pedal-input-label" "PEDAL INPUT" ($gaugeLeft - 20) ($top + 94) 160 42 22 $script:colors.Muted "#00FFFFFF" "Bold" 1 1))
        for ($segment = 1; $segment -lt 16; $segment++) {
            $segmentTop = $gaugeTop + (($gaugeHeight / 16) * $segment) - 3
            [void]$items.Add((RectangleItem "$pedal-input-separator-$segment" ($gaugeLeft + 8) $segmentTop 96 6 $script:colors.Value $null))
        }
    }
    [void]$items.Add((TextItem "$pedal-input-value" "--" ($gaugeLeft - 2) ($gaugeTop + $gaugeHeight + 18) 116 54 28 $script:colors.White "#00FFFFFF" "Bold" 1 1 (Bind-Text "[ActivePedalBridge.$pedal.InputText]")))

    Add-ParameterRow $items $pedal "TRAVEL MIN" "TravelMin" $innerLeft ($top + 154) $accent
    Add-ParameterRow $items $pedal "TRAVEL MAX" "TravelMax" $innerLeft ($top + 310) $accent
    Add-ParameterRow $items $pedal "PRELOAD" "Preload" $innerLeft ($top + 466) $accent
    Add-ParameterRow $items $pedal "MAX FORCE" "MaxForce" $innerLeft ($top + 622) $accent

    [void]$items.Add((TextItem "$pedal-effects-label" "EFFECTS" ($left + 1280) ($top + 94) 220 42 24 $script:colors.Muted "#00FFFFFF" "Bold" 0 1))

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
    $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml($script:colors.Background))

    $fontTitle = New-Object System.Drawing.Font $script:fontFamily, 38, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $fontSmall = New-Object System.Drawing.Font $script:fontFamily, 26, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $fontLabel = New-Object System.Drawing.Font $script:fontFamily, $(if ($script:isGt1) { 28 } else { 30 }), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $fontChip = New-Object System.Drawing.Font $script:fontFamily, $(if ($script:isGt1) { 30 } else { 28 }), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $fontButton = New-Object System.Drawing.Font $script:fontFamily, 72, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $fontValue = New-Object System.Drawing.Font $script:fontFamily, $(if ($script:isGt1) { 48 } else { 42 }), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $fontBrand = New-Object System.Drawing.Font $script:fontFamily, $(if ($script:isGt1) { 22 } else { 18 }), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)

    $white = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($script:colors.White))
    $muted = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($script:colors.Muted))
    $card = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($script:colors.Card))
    $button = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($script:colors.Panel))
    $valueBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($script:colors.Value))
    $activeBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($script:colors.Active))
    $darkText = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($script:colors.Background))
    $headerAccent = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($script:colors.HeaderAccent))
    $borderPen = New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml($script:colors.Border)), $script:borderSize
    $activePen = New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml($script:colors.Active)), $script:borderSize

    $labels = @("TRAVEL MIN", "TRAVEL MAX", "PRELOAD", "MAX FORCE")
    $values = @("8 %", "92 %", "14 %", "68 KG")
    $effects = @("ABS", "RPM", "G-FORCE", "WHEEL SLIP", "ROAD IMPACT")
    $pageTop = 72

    if ($script:isGt1) {
        $graphics.FillRectangle($headerAccent, 40, 12, 6, 42)
        $graphics.FillRectangle($headerAccent, 1874, 12, 6, 42)
        $graphics.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($script:colors.Border))), 40, 60, 1840, 2)
    }
    $brandWidth = $graphics.MeasureString($script:signature, $fontBrand).Width
    $graphics.DrawString($script:signature, $fontBrand, $(if ($script:isGt1) { $white } else { $muted }), (1880 - $brandWidth), 18)

    foreach ($pedal in $pedals) {
        $left = [int]$pedal.Left
        $accent = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($pedal.Accent))
        $graphics.FillRectangle($card, $left, $pageTop, 1840, 984)
        $graphics.DrawRectangle($borderPen, $left, $pageTop, 1839, 983)
        $graphics.FillRectangle($accent, $left, $pageTop, 1840, 8)
        $graphics.DrawString($pedal.Name, $fontTitle, $(if ($script:isGt1) { $accent } else { $white }), ($left + 80), ($pageTop + 28))
        $connectionBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($(if ($script:isGt1) { $script:colors.Status } else { $pedal.Accent })))
        $graphics.FillEllipse($connectionBrush, ($left + 1598), ($pageTop + 52), 26, 26)
        if (!$script:isGt1) {
            $graphics.DrawString("USB", $fontSmall, $white, ($left + 1644), ($pageTop + 34))
        }

        $gaugeX = $left + 1100
        $gaugeY = $pageTop + 154
        $gaugeH = 600
        $fillH = 384
        $graphics.FillRectangle($valueBrush, $gaugeX, $gaugeY, 112, $gaugeH)
        $graphics.DrawRectangle($borderPen, $gaugeX, $gaugeY, 111, ($gaugeH - 1))
        $graphics.FillRectangle($(if ($script:isGt1) { $activeBrush } else { $accent }), ($gaugeX + 10), ($gaugeY + $gaugeH - $fillH), 92, $fillH)
        if ($script:isGt1) {
            $graphics.DrawString("PEDAL INPUT", $fontBrand, $muted, ($gaugeX - 8), ($pageTop + 101))
            for ($segment = 1; $segment -lt 16; $segment++) {
                $segmentY = $gaugeY + (($gaugeH / 16) * $segment) - 3
                $graphics.FillRectangle($valueBrush, ($gaugeX + 8), $segmentY, 96, 6)
            }
        }
        $graphics.DrawString("64%", $fontSmall, $white, ($gaugeX - 2), ($gaugeY + $gaugeH + 12))

        for ($i = 0; $i -lt $labels.Count; $i++) {
            $y = ($pageTop + 154) + ($i * 156)
            $graphics.DrawString($labels[$i], $fontLabel, $muted, ($left + 80), ($y + 28))
            $graphics.FillRectangle($button, ($left + 410), $y, 184, 128)
            $graphics.DrawRectangle($borderPen, ($left + 410), $y, 183, 127)
            $graphics.FillRectangle($valueBrush, ($left + 620), $y, 260, 128)
            $graphics.DrawRectangle($borderPen, ($left + 620), $y, 259, 127)
            $graphics.FillRectangle($(if ($script:isGt1) { $button } else { $accent }), ($left + 906), $y, 184, 128)
            $graphics.DrawRectangle($(if ($script:isGt1) { $activePen } else { $borderPen }), ($left + 906), $y, 183, 127)
            $graphics.DrawString("-", $fontButton, $white, ($left + 482), ($y + 14))
            $valueText = if ($script:isGt1) { $values[$i] } else { "--" }
            $valueWidth = $graphics.MeasureString($valueText, $fontValue).Width
            $graphics.DrawString($valueText, $fontValue, $white, ($left + 750 - ($valueWidth / 2)), ($y + 32))
            $graphics.DrawString("+", $fontButton, $(if ($script:isGt1) { $activeBrush } else { $darkText }), ($left + 970), ($y + 14))
        }

        $graphics.DrawString("EFFECTS", $fontLabel, $muted, ($left + 1280), ($pageTop + 94))
        for ($i = 0; $i -lt $effects.Count; $i++) {
            $x = $left + 1280
            $y = ($pageTop + 154) + ($i * 154)
            $isActive = $script:isGt1 -and $i -eq 0
            $graphics.FillRectangle($(if ($isActive) { $activeBrush } else { $button }), $x, $y, 560, 128)
            $graphics.DrawRectangle($(if ($isActive) { $activePen } else { $borderPen }), $x, $y, 559, 127)
            $graphics.DrawString($effects[$i], $fontChip, $(if ($isActive) { $darkText } else { $white }), ($x + 32), ($y + 43))
        }
        $connectionBrush.Dispose()
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
    $fontValue.Dispose()
    $fontBrand.Dispose()
    $white.Dispose()
    $muted.Dispose()
    $card.Dispose()
    $button.Dispose()
    $valueBrush.Dispose()
    $activeBrush.Dispose()
    $darkText.Dispose()
    $headerAccent.Dispose()
    $borderPen.Dispose()
    $activePen.Dispose()
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
    $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml($script:colors.Background))

    $fontTitle = New-Object System.Drawing.Font $script:fontFamily, $(if ($script:isGt1) { 34 } else { 28 }), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $fontColumn = New-Object System.Drawing.Font $script:fontFamily, 30, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $fontName = New-Object System.Drawing.Font $script:fontFamily, 32, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $fontBadge = New-Object System.Drawing.Font $script:fontFamily, 20, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $fontBrand = New-Object System.Drawing.Font $script:fontFamily, $(if ($script:isGt1) { 22 } else { 18 }), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)

    $white = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($script:colors.White))
    $dark = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($script:colors.Background))
    $muted = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($script:colors.Muted))
    $row = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($script:colors.Panel))
    $startup = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#FF111720"))
    $active = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($script:colors.Active))
    $status = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($script:colors.Status))
    $headerAccent = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($script:colors.HeaderAccent))
    $borderPen = New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml($script:colors.Border)), $script:borderSize
    $statusPen = New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml($script:colors.Status)), 2

    if ($script:isGt1) {
        $graphics.FillRectangle($headerAccent, 40, 12, 6, 42)
        $graphics.FillRectangle($headerAccent, 1874, 12, 6, 42)
        $graphics.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($script:colors.Border))), 40, 60, 1840, 2)
        $graphics.DrawString("PRESETS", $fontTitle, $headerAccent, 70, 8)
    } else {
        $graphics.DrawString("CONFIG LIST", $fontTitle, $muted, 40, 28)
    }
    $brandWidth = $graphics.MeasureString($script:signature, $fontBrand).Width
    $graphics.DrawString($script:signature, $fontBrand, $(if ($script:isGt1) { $white } else { $muted }), (1880 - $brandWidth), 18)

    $columns = @(
        @{Name="CLUTCH"; Left=40; Accent="#FF35C2FF"; ActiveIndex=1; StartupIndex=1},
        @{Name="BRAKE"; Left=680; Accent="#FFFF4D5E"; ActiveIndex=0; StartupIndex=2},
        @{Name="THROTTLE"; Left=1320; Accent="#FF45D483"; ActiveIndex=3; StartupIndex=3}
    )

    foreach ($column in $columns) {
        $left = [int]$column.Left
        $accent = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($column.Accent))
        $graphics.DrawString($column.Name, $fontColumn, $white, $left, $(if ($script:isGt1) { 72 } else { 62 }))
        $graphics.FillRectangle($accent, $left, $(if ($script:isGt1) { 126 } else { 114 }), 560, 6)

        for ($i = 0; $i -lt [Math]::Min(5, $configNames.Count); $i++) {
            $top = 150 + ($i * 174)
            $isActive = if ($script:isGt1) { $i -eq [int]$column.ActiveIndex } else { $i -eq 0 }
            $isStartup = if ($script:isGt1) { $i -eq [int]$column.StartupIndex } else { $i -eq 1 }
            if ($isActive) {
                $graphics.FillRectangle($active, $left, $top, 560, 150)
                $graphics.DrawString($configNames[$i], $fontName, $dark, ($left + 28), ($top + 48))
                if ($script:isGt1) {
                    $graphics.FillRectangle($startup, ($left + 372), ($top + 20), 158, 44)
                    $graphics.DrawString("ACTIVE", $fontBadge, $active, ($left + 415), ($top + 31))
                } else {
                    $graphics.FillRectangle($white, ($left + 372), ($top + 20), 158, 44)
                    $graphics.DrawString("ACTIVE", $fontBadge, $dark, ($left + 415), ($top + 31))
                }
            } else {
                $graphics.FillRectangle($row, $left, $top, 560, 150)
                $graphics.DrawString($configNames[$i], $fontName, $white, ($left + 28), ($top + 48))
            }
            $graphics.DrawRectangle($borderPen, $left, $top, 559, 149)

            if ($isStartup) {
                $graphics.FillRectangle($startup, ($left + 372), ($top + 86), 158, 44)
                if ($script:isGt1) {
                    $graphics.DrawRectangle($statusPen, ($left + 372), ($top + 86), 157, 43)
                    $graphics.DrawString("STARTUP", $fontBadge, $status, ($left + 401), ($top + 97))
                } else {
                    $graphics.DrawString("STARTUP", $fontBadge, $white, ($left + 401), ($top + 97))
                }
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
    $fontBrand.Dispose()
    $white.Dispose()
    $dark.Dispose()
    $muted.Dispose()
    $row.Dispose()
    $startup.Dispose()
    $active.Dispose()
    $status.Dispose()
    $headerAccent.Dispose()
    $borderPen.Dispose()
    $statusPen.Dispose()
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

$screenBackground = $script:colors.Background
$dashboardDescription = if ($script:isGt1) {
    "GT1 V1.0 motorsport touch control surface for active pedals through SimHub plugin data"
} else {
    "Basic V1.0 touch control surface for active pedals through SimHub plugin data"
}
$dashboardVersion = if ($script:isGt1) { "GT1 V1.0" } else { "Basic V1.0" }

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
