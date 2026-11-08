# HyperMac — OpenWiki Documentation

HyperMac is a native macOS 14+ 11-in-1 menu bar utility suite written in pure Swift 5.9 and Objective-C with zero external package dependencies, combining display control, virtual displays, window snapping, AltTab switcher, clipboard history, Finder Cut & Paste, LightShot screenshot annotation, menu bar drawer, SMC battery/thermal/fan management, disk/NAS speed monitoring, and system cleaning.

---

## 📚 Quick Navigation

| Document | One-Sentence Summary |
| :--- | :--- |
| [architecture.md](file:///Users/kimtrungduong/Downloads/HyperMac-main/openwiki/architecture.md) | High-level system architecture, SwiftPM targets (`HyperMac` + `VirtualDisplayBridge`), private Apple frameworks, root helper privilege model, and TCC code-signing lifecycle. |
| [services.md](file:///Users/kimtrungduong/Downloads/HyperMac-main/openwiki/services.md) | Complete index and technical reference for all 22 `@MainActor` singleton managers and utility services in `Sources/`. |
| [data-flow.md](file:///Users/kimtrungduong/Downloads/HyperMac-main/openwiki/data-flow.md) | End-to-end event and data pipelines: global `CGEventTap` routing, 0ms AltTab HUD + async thumbnail streaming, SMC battery/thermal loops, Finder Cut/Paste synthesis, and OTA update swap. |
| [ipc.md](file:///Users/kimtrungduong/Downloads/HyperMac-main/openwiki/ipc.md) | Inter-process and kernel communication layers: `CGEventTap`, Accessibility `AXUIElement`, `dlopen`/`dlsym` private frameworks, `sudo -n` SMC root helper CLI, and `NSAppleScript` bridges. |
| [ui.md](file:///Users/kimtrungduong/Downloads/HyperMac-main/openwiki/ui.md) | UI architecture covering the 380×570 4-tab `NSPopover`, 5 floating `NSPanel` HUDs, secondary `NSStatusItem` drawer, and `Theme.swift` design tokens. |
| [database.md](file:///Users/kimtrungduong/Downloads/HyperMac-main/openwiki/database.md) | Local persistence layer: complete `UserDefaults` key catalog, JSON/PNG clipboard storage in `~/Library/Application Support/HyperMac/`, license markers, and diagnostic logs. |
| [patterns.md](file:///Users/kimtrungduong/Downloads/HyperMac-main/openwiki/patterns.md) | Mandatory engineering conventions, `CGEventTap` memory management (`passUnretained`), recursion guards, CommandLineTools SwiftUI workarounds, and known technical debt. |

---

## 🛠️ Tech Stack & Build Summary

| Layer | Technology / Mechanism |
| :--- | :--- |
| **Language & Toolchain** | Swift 5.9 (`swift-tools-version: 5.9`) + Objective-C (`VirtualDisplayBridge`), compatible with macOS CommandLineTools |
| **Platform Target** | macOS 14.0+ (Sonoma & Sequoia; Apple Silicon M1/M2/M3/M4 & Intel) |
| **App Mode** | Menu Bar agent (`LSUIElement = true`, `.accessory` activation policy), Bundle ID `com.opensource.hypermac` |
| **UI Framework** | SwiftUI hosted inside AppKit `NSPopover` (380×570) and borderless non-activating `NSPanel` overlays |
| **System Frameworks** | `AppKit`, `SwiftUI`, `IOKit`, `CoreGraphics`, `ApplicationServices` (`AXUIElement`), `ServiceManagement` (`SMAppService`) |
| **Private Frameworks (`dlopen`)** | `DisplayServices.framework`, `SkyLight.framework`, `PowerUI.framework`, `IOBluetooth.framework`, `CoreGraphics` (`CGVirtualDisplay`), `IOKit` HID Temperature (`kIOHIDEventTypeTemperature = 15`), `_AXUIElementGetWindow` |
| **Privilege Escalation** | `/usr/local/bin/displaycontrol-power` + `/usr/local/bin/displaycontrol-smc` via `/etc/sudoers.d/displaycontrol_power` (`NOPASSWD`) |
| **External Dependencies** | **0** (100% pure native SDK + bundled `smc` binary) |

---

## 🧩 11-in-1 Feature Matrix & Entry Points

| # | Module | Primary Manager(s) | UI Surface(s) | Global Hotkey |
| :- | :--- | :--- | :--- | :--- |
| 1 | **Display Brightness & Disconnect** | `DisplayManager`, `IOKitBridge`, `OSDManager` | `ContentView` (Displays Tab), `OSDView` | `F1` / `F2` (Brightness keys) |
| 2 | **Virtual HiDPI Display & Blackout** | `VirtualDisplayManager`, `VirtualDisplayBridge` | `ContentView` (Displays Tab) | — |
| 3 | **Window Snapping** | `WindowSnapManager` | `ContentView` (Windows Tab) | `⌃⌥←/→/↑/↓/U/I/J/K/↩/C`, `⌥⌘←/→` |
| 4 | **AltTab Window Switcher** | `WindowManager` | `AltTabOverlayView` (`NSPanel`) | `⌥Tab`, `⌥⇧Tab`, `⌥\`` |
| 5 | **Clipboard History** | `ClipboardManager` | `ClipboardOverlayView` (`NSPanel`), `ContentView` | `⌘⇧V` |
| 6 | **Finder Cut & Paste (`⌘X`)** | `FinderCutPasteManager` | `FinderCutToastView` (`NSPanel`), `ContentView` | `⌘X` → `⌘V` / `⎋` (in Finder) |
| 7 | **LightShot Screenshot & Annotation** | `ScreenshotManager` | `ScreenshotOverlayView` (`NSPanel`), `ContentView` | `⌘⇧1` or `F4` (`kVK_F4 = 118`) |
| 8 | **Menu Bar Hider & Drawer** | `MenuBarHiderManager` | `MenuBarDrawerView`, `MenuBarAppTable` | `⌥⌘B` or tray `NSStatusItem` |
| 9 | **Battery, SMC Limiter, Sleep Guard & Freezer** | `BatteryManager`, `BluetoothManager`, `ProcessEnergyManager` | `ContentView` (System Tab) | — |
| 10 | **Thermal Sensors, Fan Control & Disk/NAS Speed** | `ThermalManager`, `FanManager`, `DiskSpeedManager` | `FanControlCardView`, `ContentView` (System Tab) | — |
| 11 | **System Cleaner & Smart App Uninstaller** | `SystemCleanerManager` | `CleanerTabView` (Cleaner Tab) | — |

---

## 🚀 Lifecycle Entry Point

- **[`AppMain.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/AppMain.swift)**: Defines `@main struct DisplayControlApp: App` and `AppDelegate`.
  1. Enforces single-instance execution via `NSRunningApplication.runningApplications(withBundleIdentifier:)`.
  2. Sets `.accessory` policy (`LSUIElement`) so no Dock icon appears.
  3. Initializes status bar item (`NSStatusBar.system.statusItem`), `NSPopover` (`380×570`, `.transient`), and binds `PopoverVisibilityDelegate` to start/stop `DiskSpeedManager` only while visible.
  4. Runs `AccessibilityRecovery.attemptAutomaticRecoveryIfNeeded()` once per app version if TCC trust is broken, then starts `PermissionsManager`, `KeyInterceptor`, `ClipboardManager`, `FinderCutPasteManager`, `ScreenshotManager`, `MenuBarHiderManager`, `CaffeinateManager`, and `UpdateManager`.
  5. Registers a 3-second watchdog timer that re-asserts `KeyInterceptor.shared.ensureRunning()` in case macOS temporarily disables the `CGEventTap`.

