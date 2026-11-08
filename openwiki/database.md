# Local Persistence & State Storage

HyperMac does not use SQLite or CoreData. All configuration, history, and telemetry caches are stored locally via `UserDefaults.standard`, JSON/PNG files in `~/Library/Application Support/HyperMac/`, and hidden marker files.

---

## 1. File System Storage Locations

| Path | Format | Owner Manager | Purpose |
| :--- | :--- | :--- | :--- |
| `~/Library/Application Support/HyperMac/clipboard.json` | JSON (`[ClipboardItem]`) | [`ClipboardManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/ClipboardManager.swift) | Stores clipboard history metadata (UUID, `ClipboardItemType`, text content, timestamp, `isPinned`, `sourceAppBundleID`, `imageWidth`/`imageHeight`). |
| `~/Library/Application Support/HyperMac/ClipboardImages/<UUID>.png` | Lossless PNG | [`ClipboardManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/ClipboardManager.swift) | Stores full-resolution original copied images on disk; pruned automatically when items are deleted or expire via retention policy. |
| `~/Library/Application Support/HyperMac/.license_v1` *(Deprecated)* | Plaintext | `AppMain.swift` | Đã xoá bỏ hoàn toàn. Ứng dụng tự động dọn dẹp file này khi khởi động. |
| `~/.hypermac_activated` *(Deprecated)* | Plaintext | `AppMain.swift` | Đã xoá bỏ hoàn toàn. Ứng dụng tự động dọn dẹp file này khi khởi động. |
| `~/Library/LaunchAgents/com.displaycontrol.app.plist` | XML PropertyList | [`LaunchAtLoginManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/LaunchAtLoginManager.swift) | Legacy LaunchAgent plist synced alongside `SMAppService.mainApp`. |
| `/usr/local/bin/displaycontrol-power` & `displaycontrol-smc` | Root Bash + Mach-O Binary | [`BatteryManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/BatteryManager.swift) | Installed privileged helper scripts (`root:wheel`, `0755`). |
| `/etc/sudoers.d/displaycontrol_power` | Sudoers rule (`0440`) | `install-helper.sh` | Grants passwordless execution of `/usr/local/bin/displaycontrol-power` to the installing user. |
| `/tmp/displaycontrol.log` | Plaintext Log | [`Logger.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/Logger.swift) | Append-only ISO-8601 runtime diagnostic log (`log(_ message: String)`). |

---

## 2. Complete `UserDefaults` Key Catalog

| Domain / Manager | `UserDefaults` Key | Type | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Localization** ([`LanguageManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/LanguageManager.swift)) | `appLanguage` | `String` (`AppLanguage`) | `"vi"` | Active UI language (`"en"` or `"vi"`). |
| **TCC Recovery** ([`AccessibilityRecovery`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/AccessibilityRecovery.swift)) | `lastAccessibilityAutoResetVersion` | `String` | `nil` | Tracks last `CFBundleShortVersionString` for which `tccutil reset Accessibility` was auto-executed. |
| **Displays** ([`DisplayManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/DisplayManager.swift)) | `brightness_<CGDirectDisplayID>` | `Float` | `1.0` | Saved brightness ratio (`0.01–1.0`) per display ID. |
| **Displays** ([`DisplayManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/DisplayManager.swift)) | `brightnessKeysEnabled` | `Bool` | `true` | Whether `KeyInterceptor` intercepts `F1`/`F2` brightness keys. |
| **Displays** ([`DisplayManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/DisplayManager.swift)) | `disconnectedDisplayIDs` | `[Int]` | `[]` | Array of `CGDirectDisplayID`s soft-disconnected via `SkyLight`. |
| **AltTab** ([`WindowManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/WindowManager.swift)) | `altTabEnabled` | `Bool` | `true` | Enables `⌥Tab` / `⌥\`` window switcher interception. |
| **Window Snap** ([`WindowSnapManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/WindowSnapManager.swift)) | `windowSnapEnabled` | `Bool` | `true` | Enables `⌃⌥` keyboard window snapping and `⌥⌘←/→` display transfer. |
| **Clipboard** ([`ClipboardManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/ClipboardManager.swift)) | `clipboardEnabled` | `Bool` | `true` | Enables `0.35s` pasteboard monitoring and `⌘⇧V` overlay. |
| **Clipboard** ([`ClipboardManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/ClipboardManager.swift)) | `clipboardMaxItems` | `Int` | `50` | Maximum unpinned history items retained (`20–200`). |
| **Clipboard** ([`ClipboardManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/ClipboardManager.swift)) | `clipboardRetentionDays` | `Int` | `0` | Auto-expiry age in days (`0` = forever, `7`, `30`, `90`). |
| **Finder Cut/Paste** ([`FinderCutPasteManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/FinderCutPasteManager.swift)) | `finderCutPasteEnabled` | `Bool` | `true` | Enables `⌘X` → `⌘V` (`⌥⌘V` move) synthesis inside Finder. |
| **Screenshot** ([`ScreenshotManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/ScreenshotManager.swift)) | `screenshotEnabled` | `Bool` | `true` | Enables `⌘⇧1` / `F4` LightShot screenshot overlay. |
| **Menu Bar Drawer** ([`MenuBarDrawerPreferences`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/MenuBarDrawerPreferences.swift)) | `menuBarHiderEnabled` | `Bool` | `false` | Enables secondary `NSStatusItem` and `⌥⌘B` Menu Bar Drawer. |
| **Menu Bar Drawer** ([`MenuBarDrawerPreferences`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/MenuBarDrawerPreferences.swift)) | `menuBarDrawerShortcutEnabled` | `Bool` | `true` | Allows `⌥⌘B` keyboard shortcut to toggle the Menu Bar Drawer. |
| **Battery & SMC** ([`BatteryManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/BatteryManager.swift)) | `batteryChargeLimit` | `Int` | `100` | Target battery charge ceiling (`50–100`, snapped to 5% increments). |
| **Battery & SMC** ([`BatteryManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/BatteryManager.swift)) | `preventSleepDrain` | `Bool` | `false` | Enables Sleep Guard (`willSleepNotification` Bluetooth/SMC hooks). |
| **Battery & SMC** ([`BatteryManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/BatteryManager.swift)) | `disableBluetoothOnSleep` | `Bool` | `false` | Toggles Bluetooth off during system sleep and restores on wake. |
| **Battery & SMC** ([`BatteryManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/BatteryManager.swift)) | `calibrationLastDate` | `Double` | `0` | Unix timestamp (`TimeInterval`) of last completed battery calibration. |
| **CPU Freezer** ([`ProcessEnergyManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/ProcessEnergyManager.swift)) | `appFreezerEnabled` | `Bool` | `false` | Enables 5-second background CPU consumer monitoring. |
| **Disk & NAS Speed** ([`DiskSpeedManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/DiskSpeedManager.swift)) | `diskSpeedMonitorEnabled` | `Bool` | `true` | Enables IOKit/NAS speed sampling when popover or menu bar speed is active. |
| **Disk & NAS Speed** ([`DiskSpeedManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/DiskSpeedManager.swift)) | `showDiskSpeedInMenuBar` | `Bool` | `false` | Renders live `R/W MB/s` next to the menu bar icon (`2.0s` background interval). |
| **Auto-Update** ([`UpdateManager`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/UpdateManager.swift)) | `autoCheckUpdates` | `Bool` | `true` | Automatically checks GitHub `version.json` on launch and every 4 hours. |

---

## 3. Data Models (`Codable` Schemas)

### `ClipboardItem` ([`ClipboardManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/ClipboardManager.swift))
```swift
struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let type: ClipboardItemType // .text | .image | .url | .filePath
    let content: String         // Text/URL/Path or image dimensions label
    let preview: String         // Truncated 200-char single-line preview
    let timestamp: Date
    var isPinned: Bool
    let appName: String?        // Frontmost app localizedName at copy time
    let appBundleID: String?    // Frontmost app bundleIdentifier
    var imageFileName: String?  // "<UUID>.png" inside ClipboardImages/
    var imageWidth: Int?
    var imageHeight: Int?
}
```

### `VersionInfo` ([`UpdateManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/UpdateManager.swift) / [`version.json`](file:///Users/kimtrungduong/Downloads/HyperMac-main/version.json))
```swift
struct VersionInfo: Codable {
    let version: String
    let build: Int
    let download_url: String
    let release_notes: String
    let min_macos: String?
    let sha256: String?
}
```

