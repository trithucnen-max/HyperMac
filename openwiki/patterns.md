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

### 2.3 Popover-Scoped Polling for Zero Idle CPU
[`DiskSpeedManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/DiskSpeedManager.swift) uses `PopoverVisibilityDelegate` in [`AppMain.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/AppMain.swift):
- When `showInMenuBar == false`, disk and NAS `sysctl`/`proc_pid_rusage` polling runs **only** while the `NSPopover` is visibly open (`popoverWillShow` → `setPopoverVisible(true)`, `popoverDidClose` → `setPopoverVisible(false)`).
- When `showInMenuBar == true` and the popover is closed, the polling interval automatically throttles from `1.0s` to `2.0s` and skips expensive `proc_pid_rusage` per-PID scans.

---

## 3. Known Technical Debt & Improvement Opportunities

| Area | Location | Observation / Debt | Recommended Remedy |
| :--- | :--- | :--- | :--- |
| **Monolithic UI File** | [`Sources/Views.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/Views.swift) (3,630 lines) | Contains `ContentView` plus Displays, Windows, Battery, Sleep Guard, Auto-Calibration, CPU Freezer, Disk Speed, and Settings views in a single file. | Split into modular tab files (`DisplaysTabView.swift`, `WindowsTabView.swift`, `SystemTabView.swift`, `BatteryCardView.swift`, `DiskSpeedCardView.swift`) matching `CleanerTabView.swift`. |
| **Hardcoded Author Paths in Fallbacks** | [`Sources/ActivationManager.swift#L132-L133`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/ActivationManager.swift#L132-L133) & [`Resources/displaycontrol-power#L11-L12`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Resources/displaycontrol-power#L11-L12) | Contains fallback paths referencing `/Users/khacdai24/Desktop/HyperMac/...` when bundled resources are missing during local `swift run`. | Replace with dynamic `FileManager.default.currentDirectoryPath` or `#filePath`-relative lookup. |
| **Sudoers NOPASSWD Root Helper** | [`Resources/install-helper.sh`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Resources/install-helper.sh) & [`Resources/displaycontrol-power`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Resources/displaycontrol-power) | Spawns `sudo -n /usr/local/bin/displaycontrol-power` shells and invokes `python3` for float32 hex conversion on fan RPM writes. | Migrate to a signed `SMAppService.daemon` XPC privileged helper in Swift (eliminating `/etc/sudoers.d` and `python3` shell overhead). |
| **Hardcoded Global Shortcuts** | [`Sources/KeyInterceptor.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/KeyInterceptor.swift) | Shortcuts (`⌘⇧V`, `⌘⇧1`/`F4`, `⌥⌘B`, `⌃⌥Arrows`) are hardcoded by virtual keyCode in `KeyInterceptor`. | Introduce a `ShortcutManager` with customizable key recorder bindings stored in `UserDefaults`. |
| **Legacy Naming Artifacts** | `AppMain.swift` (`DisplayControlApp`), `Logger.swift` (`/tmp/displaycontrol.log`), `LaunchAtLoginManager.swift` (`com.displaycontrol.app`) | Retains pre-rebrand `displaycontrol` identifiers alongside `com.opensource.hypermac`. | Keep `displaycontrol-power` for backward compatibility or provide a seamless migration script when bumping major version v2.0. |

