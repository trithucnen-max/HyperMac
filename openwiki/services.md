# Services & Singleton Managers Reference

All business logic, hardware polling, and window/event orchestration in HyperMac lives in `@MainActor` singleton classes (`static let shared`) inside `/Users/kimtrungduong/Downloads/HyperMac-main/Sources/`.

---

## 🗂️ Service Directory Index

| Service / File | Lines | Domain | Primary Responsibility |
| :--- | :--- | :--- | :--- |
| [`AppMain.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/AppMain.swift) | 238 | App Lifecycle | `@main` entry point, `AppDelegate`, status bar item, `NSPopover` lifecycle, 3s `KeyInterceptor` watchdog. |
| [`KeyInterceptor.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/KeyInterceptor.swift) | 730 | Input / Hotkeys | Session-level `CGEventTap` (`keyDown`, `keyUp`, `flagsChanged`, `NSMouseMoved`, `NX_SYSDEFINED` media keys). |
| [`DisplayManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/DisplayManager.swift) | 545 | Displays | Built-in nits, external gamma LUT dimming, `SkyLight` soft-disconnect, resolution & rotation switching. |
| [`IOKitBridge.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/IOKitBridge.swift) | 67 | Displays | `dlopen` wrapper for `DisplayServicesGetBrightness` / `DisplayServicesSetBrightness` + `IODisplayCreateInfoDictionary`. |
| [`VirtualDisplayManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/VirtualDisplayManager.swift) | 172 | Virtual Display | Creates/destroys `CGVirtualDisplay` instances and manages Primary Screen Blackout (`CGSetDisplayTransferByTable` + `NSPanel`). |
| [`OSDManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/OSDManager.swift) | 101 | HUD | macOS-native style floating Brightness/Volume OSD overlay (`NSPanel`). |
| [`CaffeinateManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/CaffeinateManager.swift) | 147 | Power | Spawns `/usr/bin/caffeinate -di [-t seconds]` subprocess with countdown timer and auto-cleanup on exit. |
| [`WindowManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/WindowManager.swift) | 742 | AltTab Switcher | True Z-Order MRU window discovery, `_AXUIElementGetWindow` matching, async 640px thumbnail capture, window activation/close. |
| [`WindowSnapManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/WindowSnapManager.swift) | 467 | Window Snapping | 10 snap zones (halves, quarters, maximize, center) + cross-display move (`⌥⌘←/→`) with 3-phase `AXUIElement` frame settlement. |
| [`ClipboardManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/ClipboardManager.swift) | 1031 | Clipboard | 0.35s pasteboard polling, password manager exclusion, PNG disk store, pin/reorder, retention cleanup, synthesized `⌘V`. |
| [`FinderCutPasteManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/FinderCutPasteManager.swift) | 367 | Finder Cut/Paste | Intercepts `⌘X` in Finder (with `AXTextField` rename guard), synthesizes `⌘C`, transforms `⌘V` into `⌥⌘V` (Move), renders floating toast. |
| [`ScreenshotManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/ScreenshotManager.swift) | 532 | Screenshot | Captures full frozen screen via `CGWindowListCreateImage`, hosts annotation overlay, renders high-DPI composite to clipboard/disk. |
| [`MenuBarHiderManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/MenuBarHiderManager.swift) | 282 | Menu Bar Drawer | Scans `kAXExtrasMenuBarAttribute` across running apps, renders grouped drawer panel, triggers `kAXPressAction`/`kAXShowMenuAction`. |
| [`BatteryManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/BatteryManager.swift) | 982 | Battery & SMC | IORegistry `AppleSmartBattery` telemetry, dual-layer charge limiter (`PowerUI` + SMC root helper), Sleep Guard, 3-step Auto-Calibration. |
| [`BluetoothManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/BluetoothManager.swift) | 53 | Bluetooth | Private `IOBluetoothPreference*` wrapper used by `BatteryManager` Sleep Guard to disable Bluetooth during sleep. |
| [`ThermalManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/ThermalManager.swift) | 284 | Thermals | Reads 30+ Apple Silicon PMU die/battery/NAND temperature sensors via `IOHIDEventSystemClient` (`kIOHIDEventTypeTemperature = 15`). |
| [`FanManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/FanManager.swift) | 262 | Fans | Polls SMC fan telemetry (`FNum`, `F0Ac`, `F0Mn`, `F0Mx`), sets manual RPM presets via root helper, enforces 90°C hardware safety trip. |
| [`ProcessEnergyManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/ProcessEnergyManager.swift) | 201 | CPU Freezer | Samples top CPU processes (`ps -Aceo pid,%cpu,comm`), throttles background hogs via `SIGSTOP`/`SIGCONT` + `setpriority(PRIO_PROCESS, 20)`. |
| [`DiskSpeedManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/DiskSpeedManager.swift) | 595 | Disk & NAS I/O | Reads `IOBlockStorageDriver` physical disk bytes/s, resolves NAS interface `sysctl` counters, identifies top disk I/O PID via `proc_pid_rusage`. |
| [`SystemCleanerManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/SystemCleanerManager.swift) | 728 | System Cleaner | Concurrent `du -sk` scanner for Caches/Logs/Xcode/Trash, Smart App Uninstaller (`~/Library` leftover scanner), Large Files finder. |
| [`PermissionsManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/PermissionsManager.swift) | 156 | TCC Permissions | Polls `AXIsProcessTrusted()` and `CGPreflightScreenCaptureAccess()` every 2s, provides deep-links to System Settings panes. |
| [`UpdateManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/UpdateManager.swift) | 517 | Auto-Update | Checks GitHub `version.json` every 4h, downloads ZIP with progress, verifies SHA-256 & code signature, performs atomic swap & relaunch. |
| [`ActivationManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/ActivationManager.swift) | 143 | Licensing | Hardware UUID binding (`IOPlatformUUID`), online license activation (`POST /activate`), dual hidden marker files (`.license_v1`, `~/.hypermac_activated`). |
| [`LaunchAtLoginManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/LaunchAtLoginManager.swift) | 134 | Startup | Manages `SMAppService.mainApp` registration with fallback to `~/Library/LaunchAgents/com.displaycontrol.app.plist`. |
| [`LanguageManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/LanguageManager.swift) | 82 | Localization | Instant EN / VI reactive string dictionary (`L("en", "vi")`) persisted in `UserDefaults("appLanguage")`. |

---

## 🔍 Deep-Dive into Core Services

### 1. [`KeyInterceptor`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/KeyInterceptor.swift)
- **Role**: Single global `CGEventTap` at `.cgSessionEventTap` (`.headInsertEventTap`) listening to `keyDown`, `keyUp`, `flagsChanged`, `mouseMoved`, and `NX_SYSDEFINED` (`type 14` media/brightness keys).
- **Lock-Free Fast Path**: Uses global file-scope booleans (`gIsAltTabVisible`, `gIsClipboardVisible`, `gIsScreenshotActive`, `gIsMenuBarDrawerVisible`, `gIsFinderCutActive`, `gIsWindowSnapEnabled`, `gIsBrightnessKeyEnabled`, `gIsSynthesizingEvent`) so the C callback never blocks on `@MainActor` lock acquisition for ordinary typing.
- **Critical Memory Rule**: Always returns `Unmanaged.passUnretained(event)` for pass-through events. Using `passRetained` in a `CGEventTap` callback leaks every keyboard/mouse `CGEvent` and `IOHIDEvent` in WindowServer.

### 2. [`DisplayManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/DisplayManager.swift) & [`VirtualDisplayManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/VirtualDisplayManager.swift)
- **Display Classification**: Inspects `CGDisplayIsBuiltin(id)` and `VirtualDisplayBridge` (`vendorID == 0x1234 && productID == 0x5678`) to categorize screens into Built-in, External, or Virtual.
- **Brightness Engine**:
  - Built-in displays: Calls `IOKitBridge.setBuiltinBrightness(id, value:)` (`DisplayServicesSetBrightness`).
  - External/Virtual displays: Applies software gamma table dimming (`CGSetDisplayTransferByTable`) scaled down to a minimum floor of `0.15` to prevent total blackouts.
- **Monitor Disconnect**: Uses `SkyLight` `SLSConfigureDisplayEnabled(cid, displayID, false)` to power down a display in WindowServer and tracks disconnected IDs in `UserDefaults("disconnectedDisplayIDs")` so they can be reconnected even across app restarts.
- **Primary Screen Blackout**: `VirtualDisplayManager.togglePrimaryBlackout()` dims the built-in display to `0.001` gamma and overlays a level `.screenSaver + 1` black `NSPanel` while keeping external/virtual displays active (automatically restores if < 2 displays remain).

### 3. [`WindowManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/WindowManager.swift) & [`WindowSnapManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/WindowSnapManager.swift)
- **Z-Order Window Discovery (`WindowManager`)**:
  - Combines `CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID)` (which returns windows in exact WindowServer front-to-back Z-Order) with per-app `AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute)` and private `_AXUIElementGetWindow(axWin, &wid)` to pair every `AXUIElement` with its true `CGWindowID`.
  - Maintains `mruWindowOrder: [CGWindowID]` updated via `NSWorkspace.didActivateApplicationNotification`.
  - **0ms HUD + Async Downsampled Thumbnails**: Opens the AltTab `NSPanel` immediately using cached app icons, then dispatches `CGWindowListCreateImage(.null, .optionIncludingWindow, wid, [.boundsIgnoreFraming, .nominalResolution])` on a background queue, downsampling to max `640px` width (~200KB vs 33MB 5K raw bitmap) and purging all `NSImage` buffers on HUD close.
- **3-Phase Snap Engine (`WindowSnapManager`)**:
  - Calculates target `CGRect` in Quartz global top-left coordinates from `NSScreen.visibleFrame`.
  - Applies `kAXSizeAttribute` → `kAXPositionAttribute` → `kAXSizeAttribute` at `0ms`, repeats at `30ms` (for cross-display transitions), and verifies/corrects at `75ms` to defeat Electron/Chromium asynchronous resize bounce.

### 4. [`BatteryManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/BatteryManager.swift), [`ThermalManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/ThermalManager.swift) & [`FanManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/FanManager.swift)
- **Dual-Layer Charge Limiter (`BatteryManager`)**:
  1. **System Layer (`PowerUI`)**: On macOS 15+, calls `PowerUISmartChargeClient.setMCLLimit:error:` for limits ≥ 80%.
  2. **Hardware SMC Layer (`displaycontrol-power`)**: Polls `AppleSmartBattery` every 15s; when `currentCapacity >= chargeLimit`, invokes `sudo -n /usr/local/bin/displaycontrol-power charge disable` (`bfF0=01` / `CHTE=01000000` / `CH0B=02` / `BCLM`). Features hysteresis (`chargeLimit - 3%`) before re-enabling charging.
- **Sleep Guard**: Subscribes to `NSWorkspace.willSleepNotification`; disables charging, turns off Bluetooth (`BluetoothManager`), and optionally sets `hibernatemode 25` / disables `tcpkeepalive` & `powernap`. Restores user states on `didWakeNotification`.
- **Auto-Calibration State Machine**: Steps through `.dischargingTo20` (`adapter off` until 20%) → `.chargingTo100` (`adapter on`, `charge enable` until 100%) → `.restingAt100` (15-minute soak timer) → `.completed` (restores previous charge limit).
- **Thermal & Fan Safety**: `ThermalManager` polls Apple Silicon HID temperature sensors (`PMU tdie*`, `PMU tdev*`, `gas gauge battery`, `NAND`) every 5s. `FanManager` polls SMC fan keys every 3s and enforces a mandatory **90°C thermal safety trip**: if `ThermalManager.shared.cpuTemp >= 90°C` while in manual fan mode, it immediately resets SMC fans to `auto` until CPU drops below `80°C`.

