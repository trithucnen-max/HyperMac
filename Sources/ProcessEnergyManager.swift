import Foundation
import Combine
import AppKit

// MARK: - Process Energy & Thermal Monitor

public struct HeavyProcess: Identifiable, Equatable {
    public var id: Int32 { pid }
    public let pid: Int32
    public let name: String
    public let cpu: Double
    public var isFrozen: Bool

    public static func == (lhs: HeavyProcess, rhs: HeavyProcess) -> Bool {
        lhs.pid == rhs.pid && lhs.cpu == rhs.cpu && lhs.isFrozen == rhs.isFrozen
    }
}

@MainActor
public class ProcessEnergyManager: ObservableObject {
    public static let shared = ProcessEnergyManager()

    @Published public var processes: [HeavyProcess] = []
    @Published public var frozenPIDs: Set<Int32> = []
    @Published public var isScanning: Bool = false
    @Published public var lastRefreshed: Date = Date()

    private var timer: Timer?

    private let ignoredNames: Set<String> = [
        "kernel_task", "launchd", "WindowServer", "sysmond", "HyperMac",
        "Activity Monitor", "coreaudiod", "loginwindow", "fseventsd",
        "distnoted", "powerd", "opendirectoryd", "trustd", "UserEventAgent",
        "sandboxd", "diskarbitrationd", "mds", "mds_stores", "mdworker",
        "notifyd", "cfprefsd", "logd", "symptomsd", "containermanagerd",
        "Finder", "Dock", "SystemUIServer", "ControlCenter", "NotificationCenter", "Spotlight"
    ]

    private init() {
        refreshProcesses()
    }

    public func startAutoRefresh() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshProcesses()
            }
        }
    }

    public func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }

    public func refreshProcesses() {
        guard !isScanning else { return }
        isScanning = true

        let currentFrozen = self.frozenPIDs
        let ignored = self.ignoredNames

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            let pipe = Pipe()
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/ps")
            task.arguments = ["-Aceo", "%cpu,pid,comm", "-r"]
            task.standardOutput = pipe

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let text = String(data: data, encoding: .utf8) ?? ""
                let lines = text.components(separatedBy: .newlines)

                var found: [HeavyProcess] = []

                for line in lines.dropFirst() {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { continue }
                    let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
                    guard parts.count == 3,
                          let cpu = Double(parts[0]),
                          let pid = Int32(parts[1]) else { continue }

                    let rawName = String(parts[2])
                    let shortName = (rawName as NSString).lastPathComponent

                    if !ignored.contains(shortName) && !ignored.contains(rawName) {
                        // Check if frozen
                        let isFrozen = ProcessEnergyManager.isPIDStopped(pid) || currentFrozen.contains(pid)
                        found.append(HeavyProcess(pid: pid, name: shortName, cpu: cpu, isFrozen: isFrozen))
                    }

                    if found.count >= 6 { break }
                }

                DispatchQueue.main.async {
                    self.processes = found
                    self.isScanning = false
                    self.lastRefreshed = Date()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isScanning = false
                }
            }
        }
    }

    nonisolated private static func isPIDStopped(_ pid: Int32) -> Bool {
        let pipe = Pipe()
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-o", "state=", "-p", "\(pid)"]
        ps.standardOutput = pipe
        do {
            try ps.run()
            ps.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return out.hasPrefix("T")
        } catch {
            return false
        }
    }

    // MARK: - Actions: Safe Throttle & Safe Freeze

    public func freezeProcess(pid: Int32, autoResumeAfter: TimeInterval? = 15.0) {
        // SAFETY GUARD: NEVER freeze the user's active frontmost application (e.g. Chrome, Safari, Word)
        if let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier, frontPID == pid {
            // Lower priority instead of freezing active app
            setpriority(PRIO_PROCESS, id_t(pid), 20)
            return
        }

        kill(pid, SIGSTOP)
        frozenPIDs.insert(pid)
        updateLocalState(pid: pid, isFrozen: true)

        // Safety Auto-Resume: Automatically resume after timeout so app never hangs indefinitely
        if let timeout = autoResumeAfter, timeout > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                if self?.frozenPIDs.contains(pid) == true {
                    self?.resumeProcess(pid: pid)
                }
            }
        }
    }

    public func resumeProcess(pid: Int32) {
        kill(pid, SIGCONT)
        setpriority(PRIO_PROCESS, id_t(pid), 0)
        frozenPIDs.remove(pid)
        updateLocalState(pid: pid, isFrozen: false)
    }

    public func terminateProcess(pid: Int32) {
        kill(pid, SIGTERM)
        frozenPIDs.remove(pid)
        processes.removeAll { $0.pid == pid }
    }

    // SAFE Software Cooling for Fanless Macs:
    // Throttles background processes using renice +20 (idle priority) and pauses only background tasks with auto-resume.
    // NEVER freezes the frontmost active app!
    public func optimizeBackgroundConsumers() {
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        for p in processes {
            // Never touch the frontmost app the user is actively viewing
            if p.pid == frontPID { continue }

            // Set priority to lowest (idle cycles only) to immediately stop CPU burning
            setpriority(PRIO_PROCESS, id_t(p.pid), 20)
        }

        // For top background processes, temporarily pause for 8 seconds to drop chip temperature, then auto-resume
        let backgroundCandidates = processes.filter { $0.pid != frontPID && !$0.isFrozen }
        for p in backgroundCandidates.prefix(2) {
            freezeProcess(pid: p.pid, autoResumeAfter: 8.0)
        }
    }

    public func freezeTopConsumers() {
        optimizeBackgroundConsumers()
    }

    private func updateLocalState(pid: Int32, isFrozen: Bool) {
        if let idx = processes.firstIndex(where: { $0.pid == pid }) {
            let p = processes[idx]
            processes[idx] = HeavyProcess(pid: p.pid, name: p.name, cpu: isFrozen ? 0.0 : p.cpu, isFrozen: isFrozen)
        }
    }
}
