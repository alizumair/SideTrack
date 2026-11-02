import Foundation
import AppKit

@main
enum Main {
    private static var strongDelegate: AppDelegate?
    
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        strongDelegate = delegate
        app.delegate = delegate
        app.run()
    }
}
