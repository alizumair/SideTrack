import Foundation
import AppKit

public final class ScriptDispatcher {
    public static let shared = ScriptDispatcher()
    
    private let executionQueue = DispatchQueue(label: "io.github.edgebar.scripts", qos: .userInitiated)
    
    private init() {}
    
    public func execute(
        trigger: CustomScriptTrigger,
        completion: ((Result<String, Error>) -> Void)? = nil
    ) {
        guard !trigger.payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion?(.failure(NSError(domain: "EdgeBar", code: 1, userInfo: [NSLocalizedDescriptionKey: "Script payload is empty"])))
            return
        }
        
        executionQueue.async {
            switch trigger.type {
            case .shortcut:
                self.runShortcut(name: trigger.payload, completion: completion)
            case .appleScript:
                self.runAppleScript(source: trigger.payload, completion: completion)
            case .shell:
                self.runShellCommand(command: trigger.payload, completion: completion)
            }
        }
    }
    
    private func runShortcut(name: String, completion: ((Result<String, Error>) -> Void)?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            if process.terminationStatus == 0 {
                completion?(.success(output.isEmpty ? "Shortcut executed" : output))
            } else {
                completion?(.failure(NSError(domain: "EdgeBar", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output.isEmpty ? "Shortcut failed" : output])))
            }
        } catch {
            completion?(.failure(error))
        }
    }
    
    private func runAppleScript(source: String, completion: ((Result<String, Error>) -> Void)?) {
        DispatchQueue.main.async {
            var errorInfo: NSDictionary?
            if let script = NSAppleScript(source: source) {
                let descriptor = script.executeAndReturnError(&errorInfo)
                if let error = errorInfo {
                    let msg = error[NSAppleScript.errorMessage] as? String ?? "AppleScript error"
                    completion?(.failure(NSError(domain: "EdgeBar", code: 2, userInfo: [NSLocalizedDescriptionKey: msg])))
                } else {
                    completion?(.success(descriptor.stringValue ?? "Success"))
                }
            } else {
                completion?(.failure(NSError(domain: "EdgeBar", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize AppleScript"])))
            }
        }
    }
    
    private func runShellCommand(command: String, completion: ((Result<String, Error>) -> Void)?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            if process.terminationStatus == 0 {
                completion?(.success(output))
            } else {
                completion?(.failure(NSError(domain: "EdgeBar", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output])))
            }
        } catch {
            completion?(.failure(error))
        }
    }
}
