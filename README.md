# Active Pedal Control

SimHub 1920x1080 touch dashboard for DIY FFB active pedals.

The project ships two dashboard styles, `Active Pedal Control Basic V1.0` and
`Active Pedal Control GT1 V1.0`, plus a companion SimHub plugin named
`ActivePedalBridge`. The dashboards never bypass the pedal plugin: all reads
and all actions go through the loaded
`DiyFfbPedal.dll` or `DiyActivePedal.dll` plugin instance.

## Download

Installable files are published from the GitHub
[Releases](https://github.com/realisticsimcockpit/activepedalcontrol/releases)
page.

The release assets are:

- `ActivePedalControlSetup.exe`: one-click installer for both dashboards and
  the bridge plugin.
- `Active.Pedal.Control.Basic.V1.0.zip`: Basic dashboard package for manual
  SimHub import.
- `Active.Pedal.Control.GT1.V1.0.zip`: GT1 dashboard package for manual SimHub
  import.
- `ActivePedalBridge.dll`: companion SimHub plugin for manual installation.

## Dashboard

Both dashboard styles provide the same controls, plug-in bindings and touch
targets.

- `Basic V1.0`: clean, utility-focused presentation.
- `GT1 V1.0`: high-contrast motorsport presentation with technical borders,
  condensed typography and a segmented input gauge.

- `Configs` page with 3 columns: `Clutch`, `Brake`, `Throttle`.
- Individual pedal pages: `Brake`, `Throttle`, `Clutch`.
- Large touch-friendly buttons.
- Pedal pages are shifted slightly downward to improve top-edge click accuracy
  on small VoCore screens.
- Vertical input gauge on each pedal page.
- `ACTIVE PEDAL CONTROL by REALISTIC SIMCOCKPIT` signature on every page.

## Quick Install

1. Download `ActivePedalControlSetup.exe` from the latest release.
2. Close SimHub.
3. Run the installer as administrator.
4. Start SimHub.
5. Enable `ActivePedalBridge` if SimHub asks for plugin activation.
6. Open either `Active Pedal Control Basic V1.0` or
   `Active Pedal Control GT1 V1.0`.

The installer uses this default SimHub path:

```text
C:\Program Files (x86)\SimHub
```

For a custom SimHub path:

```powershell
ActivePedalControlSetup.exe /simhub "D:\Apps\SimHub"
```

Optional installer switch:

```text
/no-plugin
```

The installer refuses to run while `SimHubWPF.exe` is open, because Windows may
lock `ActivePedalBridge.dll`.

## Manual Install

1. Close SimHub.
2. Copy `ActivePedalBridge.dll` to:

```text
C:\Program Files (x86)\SimHub
```

3. Create the folder for each dashboard style you want to install:

```text
C:\Program Files (x86)\SimHub\DashTemplates\Active Pedal Control Basic V1.0
C:\Program Files (x86)\SimHub\DashTemplates\Active Pedal Control GT1 V1.0
```

4. Extract the contents of each dashboard ZIP into its matching folder. The ZIP
   files contain the dashboard files directly and do not include the outer
   dashboard folder.

5. Restart SimHub.

## How It Works

`ActivePedalBridge` searches for the loaded pedal plugin inside SimHub. Once it
finds it, it reads live values from the plugin and sends changes back through
the plugin's own objects and methods.

Numeric setting changes are forwarded through the plugin path used for live
configuration updates, including `SendConfigWithoutSaveToEEPROM`.

Configuration presets use the plugin's `ConfigService.ConfigList`, then apply
the selected preset to the selected pedal through the plugin. The dashboard does
not use JSON files as a direct command channel. JSON config files remain plugin
preset data, and the plugin remains the required route to the pedal.

## Configs Page

The `Configs` page shows up to five presets in the order provided by the SimHub
plugin.

Presets are shared files, but each column targets one pedal:

- click in `Clutch`: apply the preset to clutch only
- click in `Brake`: apply the preset to brake only
- click in `Throttle`: apply the preset to throttle only

Per-pedal state indicators:

- `ACTIVE`
- `STARTUP`

## Pedal Pages

Each pedal page exposes:

- `TRAVEL MIN`
- `TRAVEL MAX`
- `PRELOAD`
- `MAX FORCE`
- effects: `ABS`, `RPM`, `Gforce`, `WheelSlip`, `RoadImpact`
- connection status
- vertical input gauge

An active effect is shown in orange. An inactive effect keeps its native style.
Custom effects `CV1`, `CV2`, `CV3`, `CV4` are intentionally not shown.

## Build From Source

Build the bridge plugin:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-ActivePedalBridge.ps1
```

Generate both dashboard styles:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\New-ActivePedalDashboard.ps1 -Theme Basic
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\New-ActivePedalDashboard.ps1 -Theme GT1
```

Build the installer:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-Installer.ps1
```

## Generated Build Outputs

- `dist/ActivePedalBridge.dll`
- `dist/ActivePedalControlSetup.exe`
- `dist/Active Pedal Control Basic V1.0`
- `dist/Active Pedal Control Basic V1.0.zip`
- `dist/Active Pedal Control GT1 V1.0`
- `dist/Active Pedal Control GT1 V1.0.zip`

## Exposed Properties

SimHub prefix: `ActivePedalBridge`.

For each pedal `Clutch`, `Brake`, `Throttle`:

- `<Pedal>.TravelMinText`, `<Pedal>.TravelMaxText`
- `<Pedal>.PreloadText`, `<Pedal>.MaxForceText`
- `<Pedal>.ConnectionStatus`, `<Pedal>.ConnectionReady`
- `<Pedal>.Input`, `<Pedal>.InputText`
- `<Pedal>.Effect.<Effect>Text`
- `<Pedal>.Config.1..5.Name`
- `<Pedal>.Config.1..5.StatusText`
- `<Pedal>.Config.1..5.Visible`
- `<Pedal>.Config.1..5.Active`
- `<Pedal>.Config.1..5.Startup`

Exposed effects:

- `ABS`
- `RPM`
- `Gforce`
- `WheelSlip`
- `RoadImpact`

## Exposed Actions

For each pedal:

- `<Pedal>.TravelMin.Up` / `<Pedal>.TravelMin.Down`
- `<Pedal>.TravelMax.Up` / `<Pedal>.TravelMax.Down`
- `<Pedal>.Preload.Up` / `<Pedal>.Preload.Down`
- `<Pedal>.MaxForce.Up` / `<Pedal>.MaxForce.Down`
- `<Pedal>.Effect.<Effect>.Toggle`
- `<Pedal>.Effect.<Effect>.On`
- `<Pedal>.Effect.<Effect>.Off`
- `<Pedal>.Config.1..5.Apply`

## Author

Realistic Simcockpit
