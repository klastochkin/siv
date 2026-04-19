import Foundation

private let _logFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    return f
}()

/// Drop-in replacement for print() that prepends a HH:mm:ss.SSS timestamp.
func log(_ message: String) {
    print("[\(_logFormatter.string(from: Date()))] \(message)")
}
