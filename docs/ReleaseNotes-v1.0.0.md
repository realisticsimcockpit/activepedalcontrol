# Active Pedal Control v1.0.0

First public release of Active Pedal Control for SimHub.

## Included Assets

- `ActivePedalControlSetup.exe`: installer for the dashboard and the bridge
  plugin.
- `Active Pedal Control Basic V1.0.zip`: dashboard package for manual SimHub
  import.
- `ActivePedalBridge.dll`: companion SimHub plugin for manual installation.

## Highlights

- 1920x1080 dashboard layout.
- Touch-friendly controls for clutch, brake and throttle.
- Config preset page with per-pedal apply actions.
- Up to five visible presets from the SimHub plugin order.
- Per-pedal `ACTIVE` and `STARTUP` config states.
- Vertical input gauge on each pedal page.
- Effect toggles for `ABS`, `RPM`, `Gforce`, `WheelSlip` and `RoadImpact`.
- No direct pedal bypass: all reads and writes go through the loaded SimHub
  pedal plugin.

## Installation

Close SimHub before running the installer or copying the plugin manually.

Recommended:

```text
ActivePedalControlSetup.exe
```

Manual install:

1. Copy `ActivePedalBridge.dll` to `C:\Program Files (x86)\SimHub`.
2. Extract `Active Pedal Control Basic V1.0.zip` into
   `C:\Program Files (x86)\SimHub\DashTemplates`.
3. Restart SimHub.
