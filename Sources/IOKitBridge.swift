import Foundation
import CoreGraphics
import IOKit

public typealias CGDisplayConfigRef = OpaquePointer

@_silgen_name("CGBeginDisplayConfiguration")
public func CGBeginDisplayConfiguration(_ config: UnsafeMutablePointer<CGDisplayConfigRef?>) -> CGError

@_silgen_name("CGCompleteDisplayConfiguration")
public func CGCompleteDisplayConfiguration(_ config: CGDisplayConfigRef?, _ option: CGConfigureOption) -> CGError

@_silgen_name("CGCancelDisplayConfiguration")
public func CGCancelDisplayConfiguration(_ config: CGDisplayConfigRef?) -> CGError

@_silgen_name("CGRestorePermanentDisplayConfiguration")
public func CGRestorePermanentDisplayConfiguration()

// MARK: - Dynamic SkyLight Private Framework Bindings

public typealias SLSConfigureDisplayEnabledFunc = @convention(c) (CGDisplayConfigRef?, CGDirectDisplayID, Bool) -> CGError
public typealias SLSGetDisplayListFunc = @convention(c) (UInt32, UnsafeMutablePointer<CGDirectDisplayID>?, UnsafeMutablePointer<UInt32>?) -> CGError

private let skyLightHandle: UnsafeMutableRawPointer? = {
    dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)
}()

private let slsConfigureDisplayEnabledFn: SLSConfigureDisplayEnabledFunc? = {
    guard let handle = skyLightHandle, let sym = dlsym(handle, "SLSConfigureDisplayEnabled") else {
        return nil
    }
    return unsafeBitCast(sym, to: SLSConfigureDisplayEnabledFunc.self)
}()

private let slsGetDisplayListFn: SLSGetDisplayListFunc? = {
    guard let handle = skyLightHandle, let sym = dlsym(handle, "SLSGetDisplayList") else {
        return nil
    }
    return unsafeBitCast(sym, to: SLSGetDisplayListFunc.self)
}()

public func SLSConfigureDisplayEnabled(_ config: CGDisplayConfigRef?, _ display: CGDirectDisplayID, _ enabled: Bool) -> CGError {
    if let fn = slsConfigureDisplayEnabledFn {
        return fn(config, display, enabled)
    }
    return .failure
}

public func SLSGetDisplayList(_ maxDisplays: UInt32, _ displays: UnsafeMutablePointer<CGDirectDisplayID>?, _ count: UnsafeMutablePointer<UInt32>?) -> CGError {
    if let fn = slsGetDisplayListFn {
        return fn(maxDisplays, displays, count)
    }
    return CGGetOnlineDisplayList(maxDisplays, displays, count)
}

// MARK: - IOKit display name lookups
public let kIODisplayOnlyPreferredName: UInt32 = 0x00000200
public let kDisplayVendorIDKey = "DisplayVendorID"
public let kDisplayProductIDKey = "DisplayProductID"
public let kDisplayProductNameKey = "DisplayProductName"
public let kIOMainPort: mach_port_t = 0

@_silgen_name("IODisplayCreateInfoDictionary")
public func IODisplayCreateInfoDictionary(
    _ service: io_service_t,
    _ options: UInt32
) -> Unmanaged<CFDictionary>?
