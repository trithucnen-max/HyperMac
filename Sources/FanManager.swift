import Foundation
import AppKit

/// Điều khiển tốc độ quạt (Apple Silicon) theo kiểu iStat Menus:
/// System Controlled / Medium / High / thanh trượt thủ công.
/// Đọc qua `smc` đi kèm (không cần root); ghi qua helper `displaycontrol-power` (sudo NOPASSWD).
@MainActor
public final class FanManager: ObservableObject {
    public static let shared = FanManager()

    public enum Mode: Equatable {
        case system
        case medium
        case high
        case manual
    }

    private nonisolated static let requiredHelperVersion = 2
    private nonisolated static let helperPath = "/usr/local/bin/displaycontrol-power"
    private nonisolated static let safetyTempOn = 90.0
    private nonisolated static let safetyTempOff = 80.0

    @Published public private(set) var fanCount: Int = 0
    @Published public private(set) var minRPM: Double = 0
    @Published public private(set) var maxRPM: Double = 0
    @Published public private(set) var currentRPM: Double = 0
    @Published public private(set) var mode: Mode = .system
    /// Tốc độ đích đang áp dụng (RPM) khi không ở System.
    @Published public private(set) var targetRPM: Double = 0
    @Published public private(set) var isHelperReady: Bool = false
    @Published public private(set) var isBusy: Bool = false
    @Published public private(set) var errorMessage: String? = nil
    @Published public private(set) var safetyTripped: Bool = false

    // UI View State (Stored here to prevent CommandLineTools SwiftUIMacros @State crash)
    @Published public var sliderPercent: Double = 50
    @Published public var isDragging: Bool = false

    public var isAvailable: Bool { fanCount > 0 && maxRPM > 0 }

    private var pollTimer: Timer?
    private var smcPath: String?
    private var pendingApply: DispatchWorkItem?
    private var crashWatchdogProcess: Process?
    private var isScreenAsleep: Bool = false

    private init() {
        smcPath = FanManager.locateSMC()
        refreshStatic()
        refreshRPM()
        checkHelper()
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        nc.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        startPolling()
        // Khởi động luôn ở System: nếu bản trước crash giữa chừng, trả quạt về auto.
        if isAvailable { runHelper(["fan-auto", "0"]) { _ in } }
    }

    // MARK: - Percent <-> RPM

    public func percent(forRPM rpm: Double) -> Int {
        guard maxRPM > 0 else { return 0 }
        return Int((rpm / maxRPM * 100).rounded())
    }

    public var minPercent: Int { percent(forRPM: minRPM) }

    public func rpm(forPercent pct: Double) -> Double {
        let raw = maxRPM * pct / 100
        return min(max(raw, minRPM), maxRPM)
    }

    public var mediumRPM: Double { rpm(forPercent: 50) }
    public var highRPM: Double { rpm(forPercent: 80) }

    // MARK: - Public actions

    public func selectSystem() {
        pendingApply?.cancel()
        stopClientCrashWatchdog()
        mode = .system
        targetRPM = 0
        errorMessage = nil
        runHelper(["fan-auto", "0"]) { _ in }
        if isScreenAsleep {
            pollTimer?.invalidate()
            pollTimer = nil
            ThermalManager.shared.setSystemSleepState(true)
        }
    }

    public func selectMedium() { apply(rpm: mediumRPM, as: .medium) }
    public func selectHigh() { apply(rpm: highRPM, as: .high) }

    /// Gọi liên tục khi kéo thanh trượt; debounce để không gọi sudo mỗi pixel.
    public func setManual(rpm: Double) {
        let clamped = min(max(rpm.rounded(), minRPM), maxRPM)
        mode = .manual
        targetRPM = clamped
        pendingApply?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.apply(rpm: clamped, as: .manual) }
        }
        pendingApply = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    public func installHelperIfNeeded() {
        guard !isHelperReady else { return }
        BatteryManager.shared.installHelper { [weak self] _ in
            Task { @MainActor in self?.checkHelper() }
        }
    }

    /// Gọi khi thoát app (đồng bộ).
    public func restoreSystemSync() {
        stopClientCrashWatchdog()
        guard isAvailable else { return }
        _ = shell("sudo -n \(FanManager.helperPath) fan-auto 0 2>/dev/null")
        mode = .system
        targetRPM = 0
    }

    /// Tạm dừng hoặc tiếp tục quét RPM khi màn hình tắt/bật (vẫn giữ quét nếu đang chạy quạt Manual để bảo vệ ngưỡng 90°C).
    public func setSystemSleepState(_ asleep: Bool) {
        isScreenAsleep = asleep
        if asleep {
            if mode == .system {
                pollTimer?.invalidate()
                pollTimer = nil
            }
        } else {
            refreshRPM()
            if pollTimer == nil {
                startPolling()
            }
        }
    }

    // MARK: - Internals

    private func apply(rpm: Double, as newMode: Mode) {
        guard isAvailable else { return }
        guard !safetyTripped else {
            errorMessage = tr("Máy đang quá nóng, quạt do hệ thống điều khiển.",
                              "Mac is too hot; fan stays under system control.")
            return
        }
        guard isHelperReady else {
            errorMessage = tr("Cần cài helper (hỏi mật khẩu quản trị một lần).",
                              "Helper install needed (one admin password prompt).")
            mode = .system
            return
        }
        pendingApply?.cancel()
        mode = newMode
        targetRPM = rpm
        errorMessage = nil
        isBusy = true
        // Đảm bảo bộ đếm nhiệt & quạt luôn chạy khi ở chế độ Manual để cầu chì 90°C hoạt động
        if pollTimer == nil { startPolling() }
        ThermalManager.shared.ensurePollingForManualFan()
        let value = Int(rpm.rounded())
        let hexValue = FanManager.rpmToFloat32LEHex(value)
        let pidStr = "\(ProcessInfo.processInfo.processIdentifier)"
        // Tương thích ngược: truyền thêm hexValue ($4) và pid ($5). Helper v2 cũ sẽ bỏ qua $4/$5, helper mới dùng trực tiếp.
        runHelper(["fan-set", "0", "\(value)", hexValue, pidStr]) { [weak self] ok in
            guard let self = self else { return }
            self.isBusy = false
            if !ok {
                self.stopClientCrashWatchdog()
                self.mode = .system
                self.targetRPM = 0
                self.errorMessage = tr("Không đặt được tốc độ quạt trên máy này.",
                                       "Could not set fan speed on this Mac.")
                return
            }
            self.startClientCrashWatchdogIfNeeded()
            // Ghi SMC có độ trễ: đọc lại sau ~1.5s rồi kiểm chứng.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.verifyTarget(expected: Double(value))
            }
        }
    }

    /// Watchdog phía client: tự trả quạt về Auto nếu tiến trình HyperMac bị Force Quit (kill -9), tương thích ngược với cả helper v2 cũ.
    private func startClientCrashWatchdogIfNeeded() {
        guard crashWatchdogProcess == nil || !(crashWatchdogProcess?.isRunning ?? false) else { return }
        let appPID = ProcessInfo.processInfo.processIdentifier
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = [
            "-c",
            "while kill -0 \(appPID) 2>/dev/null; do sleep 3; done; sudo -n \(FanManager.helperPath) fan-auto 0 >/dev/null 2>&1"
        ]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            crashWatchdogProcess = proc
        } catch {
            appLog("⚠️ Could not start fan crash watchdog: \(error)")
        }
    }

    private func stopClientCrashWatchdog() {
        if let proc = crashWatchdogProcess, proc.isRunning {
            proc.terminate()
        }
        crashWatchdogProcess = nil
    }

    private func verifyTarget(expected: Double) {
        guard mode != .system, let smc = smcPath else { return }
        DispatchQueue.global(qos: .utility).async {
            let (out, _) = shell("'\(smc)' -k F0Tg -r 2>/dev/null")
            let tg = FanManager.parseFloat(out)
            DispatchQueue.main.async {
                guard self.mode != .system else { return }
                if abs(tg - expected) > 2 {
                    self.mode = .system
                    self.targetRPM = 0
                    self.errorMessage = tr("macOS không giữ tốc độ quạt (đã trả về Tự động).",
                                           "macOS did not keep the fan speed (returned to Auto).")
                    self.runHelper(["fan-auto", "0"]) { _ in }
                }
            }
        }
    }

    private func runHelper(_ args: [String], completion: @escaping @MainActor (Bool) -> Void) {
        let cmd = "sudo -n \(FanManager.helperPath) " + args.joined(separator: " ") + " 2>&1"
        DispatchQueue.global(qos: .userInitiated).async {
            let (out, code) = shell(cmd)
            let ok = code == 0 && (out.contains("FAN_SET_OK") || out.contains("FAN_AUTO_OK"))
            if !ok { appLog("⚠️ Fan helper \(args.joined(separator: " ")): code=\(code) \(out)") }
            DispatchQueue.main.async { Task { @MainActor in completion(ok) } }
        }
    }

    public func checkHelper() {
        DispatchQueue.global(qos: .utility).async {
            let (out, code) = shell("sudo -n \(FanManager.helperPath) version 2>/dev/null")
            var ver = 0
            if code == 0, let r = out.range(of: "HELPER_VERSION:") {
                ver = Int(out[r.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines).prefix(while: { $0.isNumber })) ?? 0
            }
            DispatchQueue.main.async {
                self.isHelperReady = ver >= FanManager.requiredHelperVersion
            }
        }
    }

    private func refreshStatic() {
        guard let smc = smcPath else { return }
        let (n, _) = shell("'\(smc)' -k FNum -r 2>/dev/null")
        fanCount = Int(FanManager.parseFloat(n))
        guard fanCount > 0 else { return }
        minRPM = FanManager.parseFloat(shell("'\(smc)' -k F0Mn -r 2>/dev/null").0)
        maxRPM = FanManager.parseFloat(shell("'\(smc)' -k F0Mx -r 2>/dev/null").0)
    }

    private func refreshRPM() {
        guard let smc = smcPath, fanCount > 0 else { return }
        DispatchQueue.global(qos: .utility).async {
            let rpm = FanManager.parseFloat(shell("'\(smc)' -k F0Ac -r 2>/dev/null").0)
            DispatchQueue.main.async { self.currentRPM = rpm }
        }
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        refreshRPM()
        enforceSafety()
    }

    /// Ngưỡng an toàn: CPU/GPU >= 90°C thì ép về System, mở lại khi < 80°C.
    private func enforceSafety() {
        let t = ThermalManager.shared
        let hottest = max(t.cpuPeakTemp, t.gpuAvgTemp, t.hotspotTemp)
        if !safetyTripped, hottest >= FanManager.safetyTempOn {
            safetyTripped = true
            if mode != .system {
                selectSystem()
                errorMessage = tr("Quá nóng (≥90°C): đã trả quạt về hệ thống.",
                                  "Too hot (≥90°C): fan returned to system control.")
            }
        } else if safetyTripped, hottest < FanManager.safetyTempOff {
            safetyTripped = false
            errorMessage = nil
        }
    }

    @objc private func willSleep() { if mode != .system { selectSystem() } }
    @objc private func didWake() { checkHelper(); refreshRPM() }

    // MARK: - Helpers

    private static func locateSMC() -> String? {
        let execDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().path
        let candidates = [
            Bundle.main.path(forResource: "smc", ofType: nil),
            "/usr/local/bin/displaycontrol-smc",
            FileManager.default.currentDirectoryPath + "/Resources/smc",
            execDir + "/Resources/smc",
            execDir + "/../Resources/smc"
        ].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Chuyển đổi số nguyên RPM sang chuỗi hex IEEE-754 float32 little-endian (ví dụ: 3000 -> "00803b45") thuần Swift.
    public nonisolated static func rpmToFloat32LEHex(_ rpm: Int) -> String {
        let bits = Float(rpm).bitPattern.littleEndian
        return withUnsafeBytes(of: bits) { bytes in
            bytes.map { String(format: "%02x", $0) }.joined()
        }
    }

    /// Phân tích dòng `  F0Ac  [flt ]  2985 (bytes ...)` hoặc `[ui8 ]  1 (...)` → số.
    nonisolated static func parseFloat(_ s: String) -> Double {
        guard let close = s.range(of: "]") else { return 0 }
        let rest = s[close.upperBound...].trimmingCharacters(in: .whitespaces)
        let token = rest.split(separator: " ").first.map(String.init) ?? ""
        return Double(token) ?? 0
    }
}
