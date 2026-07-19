# Active Pedal Control v1.1.0

This release adds the GT1 dashboard style while keeping the original Basic
dashboard available.

## Included Assets

- `ActivePedalControlSetup.exe`: installer for both dashboards and the bridge
  plugin.
- `Active.Pedal.Control.Basic.V1.0.zip`: Basic dashboard package for manual
  SimHub import.
- `Active.Pedal.Control.GT1.V1.0.zip`: GT1 dashboard package for manual SimHub
  import.
- `ActivePedalBridge.dll`: companion SimHub plugin for manual installation.

## Highlights

- New GT1 motorsport dashboard style.
- Original Basic dashboard retained with the same controls and layout.
- Both styles use identical SimHub actions and plug-in data bindings.
- Shared branding added to every page.
- GT1 preset page with orange active states and cyan startup states.
- GT1 pedal pages with condensed typography, technical borders and segmented
  vertical input gauges.
- Installer now deploys both dashboard styles.
- All pedal reads and writes still pass through the loaded SimHub pedal plugin.

## Installation

Close SimHub before running the installer or copying the plugin manually.

Recommended:

```text
ActivePedalControlSetup.exe
```

Manual installation:

1. Copy `ActivePedalBridge.dll` to `C:\Program Files (x86)\SimHub`.
2. Extract either or both dashboard ZIP files into
   `C:\Program Files (x86)\SimHub\DashTemplates`.
3. Restart SimHub.

The two dashboard names shown in SimHub are:

```text
Active Pedal Control Basic V1.0
Active Pedal Control GT1 V1.0
```
