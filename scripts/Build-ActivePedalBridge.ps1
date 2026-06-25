param(
    [string]$SimHubPath = "C:\Program Files (x86)\SimHub",
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$src = Join-Path $root "src\ActivePedalBridge\ActivePedalBridge.cs"
$outDir = Join-Path $root "dist"
$out = Join-Path $outDir "ActivePedalBridge.dll"

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$csc = "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if (!(Test-Path $csc)) {
    throw "csc.exe not found: $csc"
}

$refs = @(
    "System.dll",
    "System.Core.dll",
    (Join-Path "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319" "System.Xaml.dll"),
    (Join-Path "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\WPF" "WindowsBase.dll"),
    (Join-Path "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\WPF" "PresentationCore.dll"),
    (Join-Path "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\WPF" "PresentationFramework.dll"),
    (Join-Path $SimHubPath "GameReaderCommon.dll"),
    (Join-Path $SimHubPath "SimHub.Plugins.dll")
)

foreach ($ref in $refs) {
    if ($ref -like "*.dll" -and $ref -match "^[A-Za-z]:\\" -and !(Test-Path $ref)) {
        throw "Missing reference: $ref"
    }
}

& $csc /nologo /target:library /platform:anycpu /optimize+ /warn:4 /out:$out ($refs | ForEach-Object { "/reference:$_" }) $src
if ($LASTEXITCODE -ne 0) {
    throw "Compilation failed."
}

Write-Host "OK: $out"
