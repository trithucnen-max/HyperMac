# Engineering Patterns, Conventions & Gotchas

This document captures the critical low-level macOS patterns, concurrency conventions, and known technical debt in HyperMac that every contributor or AI agent must follow before modifying the codebase.

---

## 1. Critical Memory & Concurrency Patterns

### 1.1 `Unmanaged.passUnretained(event)` in `CGEventTap` (DO NOT CHANGE)
In [`KeyInterceptor.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/KeyInterceptor.swift), the C callback `eventTapCallback` returns `Unmanaged<CGEvent>?`.
- **Rule**: Always return `Unmanaged.passUnretained(event)` when passing an event through, and `nil` when consuming it.
- **Why**: Quartz Event Services does **not** release the returned `CGEvent` reference when it matches the incoming event pointer. Using `Unmanaged.passRetained(event)` increments the retain count on every single keystroke, modifier change, and mouse movement (`NSMouseMoved`), leaking tens of thousands of `CGEvent` and `IOHIDEvent` objects per hour (fixed in v1.9.4).

### 1.2 Lock-Free Global Flags for EventTap Fast Path
Because `eventTapCallback` runs synchronously on the thread hosting the `CFRunLoop` for every input event on macOS:
- Never call `MainActor.assumeIsolated` or query `ObservableObject` properties on the hot path of every keystroke/mouse move.
- Instead, mirror active overlay states in file-scope booleans (`gIsAltTabVisible`, `gIsClipboardVisible`, `gIsScreenshotActive`, `gIsMenuBarDrawerVisible`, `gIsFinderCutActive`, `gIsWindowSnapEnabled`, `gIsBrightnessKeyEnabled`, `gIsSynthesizingEvent`) and only dispatch via `Task { @MainActor in ... }` after a shortcut or active overlay key is matched.

### 1.3 Recursion Guard (`gIsSynthesizingEvent`)
Whenever HyperMac synthesizes keyboard shortcuts via `CGEvent(keyboardEventSource: nil, virtualKey: ..., keyDown: ...)` (`⌘V` in [`ClipboardManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/ClipboardManager.swift), `⌘C` and `⌥⌘V` in [`FinderCutPasteManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/FinderCutPasteManager.swift)):
- Set `gIsSynthesizingEvent = true` immediately before `.post(tap: .cghidEventTap)` and reset `gIsSynthesizingEvent = false` after posting (or after a `50ms` delay).
- This prevents `KeyInterceptor`'s own `.cgSessionEventTap` from intercepting the synthetic `⌘V` or `⌘C` in an infinite loop.

### 1.4 CommandLineTools SwiftUI Macro Workaround
To allow building with standard macOS CommandLineTools (`swift build -c release`) without requiring a full 30GB Xcode.app installation:
- Avoid complex Swift 5.9 macros (`@Observable`) or deeply nested `@State` inside secondary view files when `@ObservedObject` on a `@MainActor final class ...: ObservableObject` singleton suffices.
- For example, [`CleanerTabView.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/CleanerTabView.swift) stores its UI tab/sheet state (`activeSubTab`, `searchQuery`, `selectedCategoryForDetail`) as `@Published` properties on `SystemCleanerManager.shared` rather than local `@State`.

---

## 2. Hardware & OS Quirk Workarounds

### 2.1 Electron / Chrome 3-Phase Window Snap Settlement
In [`WindowSnapManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/WindowSnapManager.swift):
- Setting `kAXPositionAttribute` and `kAXSizeAttribute` once often fails when moving a window across monitors with different backing scale factors or inside Electron/Chrome apps.
- Always apply `Size → Position → Size` at `0ms`, repeat at `30ms`, and verify/correct at `75ms` if `abs(actualPos - targetPos) > 10px`.

### 2.2 Filtering APFS Containers in `IOBlockStorageDriver`
In [`DiskSpeedManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/DiskSpeedManager.swift):
- macOS IORegistry attaches `IOBlockStorageDriver` nodes to **both** the physical NVMe/USB drive (`AppleANS3NVMeController` / `IOBlockStorageDevice`) AND the virtual `AppleAPFSContainerScheme` sitting on top of it.
- Always walk 2 levels up via `IORegistryEntryGetParentEntry` and skip any driver whose parent is `AppleAPFSContainerScheme`, or disk read/write speeds will be **double-counted (2×)**! Also skip `Protocol Characteristics == "Virtual Interface"` to ignore mounted `.dmg` disk images.

### 2.3 Popover-Scoped & Screen-Sleep Adaptive Zero-Polling
1. **Popover-Scoped Disk I/O**: [`DiskSpeedManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/DiskSpeedManager.swift) uses `NSPopoverDelegate` in [`AppMain.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/AppMain.swift) so disk and NAS `sysctl`/`proc_pid_rusage` polling runs **only** while the `NSPopover` is visibly open.
2. **Screen-Sleep Zero-Polling**: [`AppMain.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/AppMain.swift) listens to `NSWorkspace.screensDidSleepNotification` / `screensDidWakeNotification` and `sessionDidResignActiveNotification` / `sessionDidBecomeActiveNotification`, calling `setSystemSleepState(_:)` to completely pause `ClipboardManager` (`0.35s`), `PermissionsManager` (`1.5s`), and `ThermalManager` / `FanManager` (`2.5s`, unless `FanManager.shared.mode != .system`, in which case thermal/fan polling stays active to enforce the `90°C` hardware safety fuse).
3. **Pure Swift Float32 Hex & Fan Crash Watchdog**: [`FanManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/FanManager.swift) encodes target RPM into IEEE-754 float32 little-endian hex in pure Swift (`FanManager.rpmToFloat32LEHex(_:)`) and spawns a lightweight PID watchdog (`kill -0 <appPID>`) that automatically resets SMC fans to `fan-auto` (`F0Md=00`) if HyperMac is force-killed (`kill -9`).

---

## 3. Resolved Technical Debt & Future Opportunities

| Area | Location | Status / Observation | Solution / Next Step |
| :--- | :--- | :--- | :--- |
| **Modular UI Architecture** | [`Sources/Views.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/Views.swift) (`438L`), [`ModalsView.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/ModalsView.swift) (`672L`), [`DisplaysTabView.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/DisplaysTabView.swift) (`607L`), [`ShortcutsTabView.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/ShortcutsTabView.swift) (`667L`), [`HardwareCareTabView.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/HardwareCareTabView.swift) (`942L`), [`ThermalAndFanCardView.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/ThermalAndFanCardView.swift) (`317L`) | ✅ **Resolved**: Split from the original 3,630-line monolith into 6 focused view files (`Views.swift` reduced by 88% to 438 lines). | Keep new tabs/cards in dedicated `*View.swift` files. |
| **Dynamic Resource Lookup** | [`Sources/ActivationManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/ActivationManager.swift), [`Sources/FanManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/FanManager.swift), [`Resources/displaycontrol-power`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Resources/displaycontrol-power) | ✅ **Resolved**: Removed all hardcoded `/Users/khacdai24/...` paths in favor of dynamic binary-relative lookup. | — |
| **Pure Swift + POSIX Awk Fan Helper** | [`Sources/FanManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/FanManager.swift) & [`Resources/displaycontrol-power`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Resources/displaycontrol-power) | ✅ **Resolved**: Eliminated external `perl`/`python3` interpreter dependency; added backward-compatible hex + PID crash watchdog. | Optional v2.0 upgrade: migrate to `SMAppService.daemon` XPC service. |
| **Hardcoded Global Shortcuts** | [`Sources/KeyInterceptor.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/KeyInterceptor.swift) | Shortcuts (`⌘⇧V`, `⌘⇧1`/`F4`, `⌥⌘B`, `⌃⌥Arrows`) are matched by virtual keyCode in `KeyInterceptor`. | Option C roadmap: introduce a `ShortcutManager` with customizable key recorder bindings. |

