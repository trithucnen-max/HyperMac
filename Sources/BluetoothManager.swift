import Foundation
import AppKit

// MARK: - Bluetooth Manager (Native IOBluetooth Dynamic Bridge)

public final class BluetoothManager {
    public static let shared = BluetoothManager()

    private typealias GetPowerStateFunc = @convention(c) () -> Int32
    private typealias SetPowerStateFunc = @convention(c) (Int32) -> Int32

    private var getPowerState: GetPowerStateFunc?
    private var setPowerState: SetPowerStateFunc?
    private var isLoaded: Bool = false

    private init() {
        loadFramework()
    }

    private func loadFramework() {
        guard let handle = dlopen("/System/Library/Frameworks/IOBluetooth.framework/IOBluetooth", RTLD_LAZY) else {
            return
        }
        if let symGet = dlsym(handle, "IOBluetoothPreferenceGetControllerPowerState") {
            getPowerState = unsafeBitCast(symGet, to: GetPowerStateFunc.self)
        }
        if let symSet = dlsym(handle, "IOBluetoothPreferenceSetControllerPowerState") {
            setPowerState = unsafeBitCast(symSet, to: SetPowerStateFunc.self)
        }
        isLoaded = (getPowerState != nil && setPowerState != nil)
    }

    public var isAvailable: Bool {
        guard isLoaded else { return false }
        // Crucial TCC privacy guard: Never call IOBluetooth if the bundle lacks NSBluetoothAlwaysUsageDescription!
        // Without this key in Info.plist, macOS TCC kernel daemon instantly aborts the app with SIGABRT!
        guard Bundle.main.object(forInfoDictionaryKey: "NSBluetoothAlwaysUsageDescription") != nil else {
            return false
        }
        return true
    }

    public var isPowerOn: Bool {
        get {
            guard isAvailable, let getPower = getPowerState else { return true }
            return getPower() != 0
        }
        set {
            guard isAvailable, let setPower = setPowerState else { return }
            _ = setPower(newValue ? 1 : 0)
        }
    }
}
