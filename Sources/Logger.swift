import Foundation

public func appLog(_ message: String) {
    let line = "[\(Date())] \(message)\n"
    print(line, terminator: "")
    if let data = line.data(using: .utf8) {
        if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/tmp/displaycontrol.log")) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            _ = try? handle.close()
        } else {
            try? data.write(to: URL(fileURLWithPath: "/tmp/displaycontrol.log"), options: .atomic)
        }
    }
}
