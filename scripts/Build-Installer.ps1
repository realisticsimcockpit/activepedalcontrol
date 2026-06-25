param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$src = Join-Path $root "src\Installer\ActivePedalControlInstaller.cs"
$manifest = Join-Path $root "src\Installer\app.manifest"
$outDir = Join-Path $root "dist"
$out = Join-Path $outDir "ActivePedalControlSetup.exe"

$plugin = Join-Path $outDir "ActivePedalBridge.dll"
$basicZip = Join-Path $outDir "Active Pedal Control Basic V1.0.zip"

foreach ($required in @($src, $manifest, $plugin, $basicZip)) {
    if (!(Test-Path -LiteralPath $required)) {
        throw "Required file missing: $required"
    }
}

$csc = "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if (!(Test-Path -LiteralPath $csc)) {
    throw "csc.exe not found: $csc"
}

& $csc /nologo /target:exe /platform:anycpu /optimize+ /warn:4 /win32manifest:$manifest /out:$out `
    /resource:"$plugin,ActivePedalBridge.dll" `
    /resource:"$basicZip,BasicDashboard.zip" `
    $src

if ($LASTEXITCODE -ne 0) {
    throw "Installer compilation failed."
}

Write-Host "OK: $out"
