# System & Inter-Process Communication (IPC)

Although HyperMac is a single-process macOS application without a traditional REST backend, it communicates intensively with the macOS WindowServer, Accessibility subsystem, IOKit kernel drivers, private system frameworks, and a privileged root CLI helper across five distinct IPC channels.

---

## 1. Channel Overview

| IPC Channel | Counterpart Process / Subsystem | Transport Mechanism | Primary Files |
| :--- | :--- | :--- | :--- |
| **1. Session Event Tap** | `WindowServer` / HID Event System | `CGEvent.tapCreate(tap: .cgSessionEventTap)` + `CFMachPort` | [`KeyInterceptor.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/KeyInterceptor.swift) |
| **2. Accessibility IPC** | Target macOS Apps (`Finder`, `Chrome`, etc.) & `SystemUIServer` | `AXUIElement` Mach IPC + `_AXUIElementGetWindow` | [`WindowManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/WindowManager.swift), [`WindowSnapManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/WindowSnapManager.swift), [`MenuBarHiderManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/MenuBarHiderManager.swift) |
| **3. Root Helper CLI Protocol** | `/usr/local/bin/displaycontrol-power` & `displaycontrol-smc` | `Process` (`/usr/bin/sudo -n`) via `ShellHelper.runCommand` | [`BatteryManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/BatteryManager.swift), [`FanManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/FanManager.swift), [`Resources/displaycontrol-power`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Resources/displaycontrol-power) |
| **4. Dynamic Private Framework XPC** | `powerd`, `WindowServer`, `bluetoothd` | `dlopen` / `dlsym` Objective-C & C symbols | [`BatteryManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/BatteryManager.swift), [`DisplayManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/DisplayManager.swift), [`BluetoothManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/BluetoothManager.swift), [`IOKitBridge.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/IOKitBridge.swift) |
| **5. AppleScript & OS Process Bridges** | `Finder.app`, `SecurityAgent`, `GitHub API` | `NSAppleScript`, `/usr/bin/osascript`, `URLSession` | [`SystemCleanerManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/SystemCleanerManager.swift), [`UpdateManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/UpdateManager.swift) |

---

## 2. Root Helper CLI Protocol (`displaycontrol-power` v2)

[`ShellHelper.runCommand`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/ShellHelper.swift) executes `/usr/bin/sudo -n /usr/local/bin/displaycontrol-power <subcommand> [args]` with a configurable timeout (default `5.0s`) and non-blocking `FileHandle.readDataToEndOfFile()` pipes before `waitUntilExit()` to prevent pipe-buffer deadlocks.

### Supported Commands & SMC Key Mapping

| Command | Arguments | SMC Keys / System Action | Output Contract |
| :--- | :--- | :--- | :--- |
| `version` | — | Returns helper version integer | `2` |
| `charge` | `disable` | Writes `bfF0=01`, `bfD0=01`, `bfE0=01` (M3/M4), `CHTE=01000000` (M2+), `CH0B=02`, `CH0C=02` (M1), `BCLM=50` (Intel) | `disabled:<keys>` or `unsupported` (exit 2) |
| `charge` | `enable` | Writes `bfF0=00`, `bfD0=00`, `bfE0=00`, `CHTE=00000000`, `CH0B=00`, `CH0C=00`, `BCLM=64` | `enabled:<keys>` |
| `charge` | `status` | Reads `CHTE`, `bfF0`, `CH0B`, `BCLM` via `displaycontrol-smc -k <key> -r` | `enabled`, `disabled`, or `unknown` |
| `charge` | `capabilities` | Probes which SMC keys exist on current Mac model | Space-separated key list (e.g. `CHTE bfF0`) |
| `limit` | `<50..100>` | Writes hex limit to `BCLM` on Intel Macs | `<limit>` |
| `adapter` | `off` \| `on` \| `status` | Writes `CH0I=01`/`CH0J=01` (`off`, forces battery discharge on AC) or `00` (`on`) | `off`, `on`, or `unsupported` |
| `fan` | `auto` | Iterates `FNum` fans (`0..N-1`) and writes `F%dMd = 00` | `auto` |
| `fan` | `set <idx> <rpm>` | Writes `F<idx>Md = 01` and IEEE-754 float32 LE hex to `F<idx>Tg` | `set:<idx>:<rpm>` |
| `hibernatemode` | `0` \| `3` \| `25` | Runs `/usr/bin/pmset -a hibernatemode <val>` | Empty stdout, exit 0 |
| `standby` / `powernap` / `tcpkeepalive` / `womp` | `0` \| `1` | Runs `/usr/bin/pmset -a <setting> <0|1>` | Empty stdout, exit 0 |

---

## 3. Accessibility (`AXUIElement`) IPC Operations

HyperMac interacts with external application processes via `AXUIElementCreateApplication(pid)`:

1. **Window Enumeration & Activation ([`WindowManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/WindowManager.swift))**:
   - Reads `kAXWindowsAttribute`, `kAXTitleAttribute`, `kAXRoleAttribute` (`kAXWindowRole`), `kAXSubroleAttribute` (`kAXStandardWindowSubrole`, `kAXDialogSubrole`), `kAXMinimizedAttribute`, `kAXPositionAttribute`, `kAXSizeAttribute`.
   - Raises windows via `AXUIElementSetAttributeValue(axWin, kAXMinimizedAttribute, kCFBooleanFalse)`, `AXUIElementPerformAction(axWin, kAXRaiseAction)`, `AXUIElementSetAttributeValue(axWin, kAXMainAttribute, kCFBooleanTrue)`, and `NSRunningApplication.activate(options: [.activateIgnoringOtherApps])`.
   - Closes windows remotely from AltTab (`W` or `Delete` key) by reading `kAXCloseButtonAttribute` and invoking `AXUIElementPerformAction(closeBtn, kAXPressAction)`.

2. **Window Frame Snapping ([`WindowSnapManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/WindowSnapManager.swift))**:
   - Reads `kAXFocusedWindowAttribute` (with fallback to `kAXMainWindowAttribute` or first standard window in `kAXWindowsAttribute`).
   - Packs `CGPoint` and `CGSize` into `AXValueCreate(.cgPoint / .cgSize)` and writes `kAXSizeAttribute` → `kAXPositionAttribute` → `kAXSizeAttribute`.

3. **Menu Bar Status Item Proxy ([`MenuBarHiderManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/MenuBarHiderManager.swift))**:
   - Queries `kAXExtrasMenuBarAttribute` on every running `NSRunningApplication`.
   - Reads each child item's `kAXPositionAttribute`, `kAXSizeAttribute`, `kAXTitleAttribute`, `kAXDescriptionAttribute`, and `kAXIdentifierAttribute`.
   - When the user clicks an icon in HyperMac's Menu Bar Drawer, HyperMac hides the drawer and after `60ms` sends `AXUIElementPerformAction(axElement, kAXPressAction)` (fallback `kAXShowMenuAction`) directly to the target app's status item—even if the item is off-screen behind the MacBook notch.

---

## 4. External HTTP Endpoints

HyperMac makes outbound HTTPS requests only for application update checks:

| Manager | Endpoint | Method | Payload / Response |
| :--- | :--- | :--- | :--- |
| [`UpdateManager.swift`](file:///Users/kimtrungduong/Downloads/HyperMac-main/Sources/UpdateManager.swift) | `https://raw.githubusercontent.com/khacdaikon/HyperMac/main/version.json` | `GET` | JSON `{ "version": "1.9.4", "download_url": "...", "release_notes": "...", "sha256": "..." }` |


