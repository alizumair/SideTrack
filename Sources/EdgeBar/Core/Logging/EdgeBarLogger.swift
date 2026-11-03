import Foundation

public enum EdgeBarLogger {
    private static let logURL = URL(fileURLWithPath: "/tmp/edgebar.log")
    private static let queue = DispatchQueue(label: "io.github.edgebar.logger")
    
    public static func log(_ message: String) {
        queue.async {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let line = "[\(timestamp)] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }
            
            if let handle = try? FileHandle(forWritingTo: logURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: logURL)
            }
        }
    }
}
