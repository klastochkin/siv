import Foundation
import AppKit

/// Publishes the album to a TV library folder and runs the LAN server the TV app reads from.
@MainActor
final class TVPublishViewModel: ObservableObject {
    enum ServerState: Equatable {
        case stopped
        case starting
        case running(port: UInt16)
        case failed(String)
    }

    private enum Keys {
        static let libraryPath = "tv.libraryPath"
        static let port = "tv.port"
        static let bindHost = "tv.bindHost"
        static let token = "tv.token"
        static let exportSize = "tv.exportSize"
    }

    @Published var libraryPath: String { didSet { defaults.set(libraryPath, forKey: Keys.libraryPath) } }
    @Published var port: UInt16 { didSet { defaults.set(Int(port), forKey: Keys.port) } }
    /// Empty string means all interfaces.
    @Published var bindHost: String { didSet { defaults.set(bindHost, forKey: Keys.bindHost) } }
    @Published var token: String { didSet { defaults.set(token, forKey: Keys.token) } }
    @Published var exportSize: TVExportSize { didSet { defaults.set(exportSize.rawValue, forKey: Keys.exportSize) } }

    @Published private(set) var interfaces: [LANAddress.Interface] = []
    @Published private(set) var isPublishing = false
    @Published private(set) var progressDone = 0
    @Published private(set) var progressTotal = 0
    @Published private(set) var lastReport: TVExportReport?
    @Published private(set) var errorMessage: String?
    @Published private(set) var serverState: ServerState = .stopped

    private let defaults: UserDefaults
    private var server: TVServer?

    init(defaults: UserDefaults = .standard, interfaces: [LANAddress.Interface] = LANAddress.ipv4Interfaces()) {
        self.defaults = defaults
        let home = FileManager.default.homeDirectoryForCurrentUser
        libraryPath = defaults.string(forKey: Keys.libraryPath)
            ?? home.appendingPathComponent("SIV-TV-Library", isDirectory: true).path
        let storedPort = defaults.integer(forKey: Keys.port)
        port = (1...65535).contains(storedPort) ? UInt16(storedPort) : TVServer.defaultPort
        token = defaults.string(forKey: Keys.token) ?? ""
        exportSize = defaults.string(forKey: Keys.exportSize).flatMap(TVExportSize.init(rawValue:)) ?? .fullHD
        self.interfaces = interfaces
        bindHost = defaults.string(forKey: Keys.bindHost)
            ?? interfaces.first { LANAddress.isPrivateIPv4($0.address) }?.address
            ?? ""
    }

    var libraryURL: URL { URL(fileURLWithPath: libraryPath, isDirectory: true) }

    var isServerRunning: Bool {
        if case .running = serverState { return true }
        return false
    }

    /// Base URL to type into the TV app's settings.
    var serverURL: String? {
        guard case .running(let boundPort) = serverState else { return nil }
        let host = bindHost.isEmpty
            ? (interfaces.first { LANAddress.isPrivateIPv4($0.address) }?.address ?? "localhost")
            : bindHost
        return "http://\(host):\(boundPort)"
    }

    /// Warns when the server would be reachable on a non-private address.
    var exposureWarning: String? {
        if bindHost.isEmpty {
            let publicAddresses = interfaces.map(\.address).filter { !LANAddress.isPrivateIPv4($0) }
            return publicAddresses.isEmpty
                ? nil
                : "Listening on all interfaces includes non-private address \(publicAddresses.joined(separator: ", "))."
        }
        if bindHost.hasPrefix("127.") {
            return "\(bindHost) is only reachable from this Mac; the TV cannot connect."
        }
        return LANAddress.isPrivateIPv4(bindHost) ? nil : "\(bindHost) is not a private LAN address."
    }

    func refreshInterfaces() {
        interfaces = LANAddress.ipv4Interfaces()
    }

    func generateToken() {
        var bytes = [UInt8](repeating: 0, count: 12)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        token = bytes.map { String(format: "%02x", $0) }.joined()
    }

    func chooseLibraryFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Choose the folder SIV publishes TV photos into"
        panel.directoryURL = libraryURL.deletingLastPathComponent()
        if panel.runModal() == .OK, let url = panel.url {
            libraryPath = url.path
        }
    }

    // MARK: - Publish

    func publish(images: [ImageFile], albumName: String) async {
        guard !isPublishing else { return }
        isPublishing = true
        errorMessage = nil
        progressDone = 0
        progressTotal = images.count
        let root = libraryURL
        let options = TVExportOptions.preset(exportSize)

        let result: Result<TVExportReport, Error> = await Task.detached(priority: .userInitiated) {
            Result {
                try TVExportService.export(images: images, albumName: albumName, to: root, options: options) { done, total in
                    Task { @MainActor [weak self] in
                        guard let self, done > self.progressDone else { return }
                        self.progressDone = done
                        self.progressTotal = total
                    }
                }
            }
        }.value

        switch result {
        case .success(let report):
            lastReport = report
            progressDone = images.count
            log("📺 TV publish: \(report.summary) → \(root.path)")
        case .failure(let error):
            errorMessage = error.localizedDescription
            log("❌ TV publish failed: \(error.localizedDescription)")
        }
        isPublishing = false
    }

    // MARK: - Server

    func startServer() async {
        guard !isServerRunning, serverState != .starting else { return }
        serverState = .starting
        try? FileManager.default.createDirectory(at: libraryURL, withIntermediateDirectories: true)
        let server = TVServer(configuration: .init(
            root: libraryURL,
            host: bindHost.isEmpty ? nil : bindHost,
            port: port,
            token: token
        ))
        do {
            let bound = try await server.start()
            self.server = server
            serverState = .running(port: bound)
            log("📺 TV server listening on \(serverURL ?? "port \(bound)")")
        } catch {
            server.stop()
            serverState = .failed(error.localizedDescription)
            log("❌ TV server failed: \(error.localizedDescription)")
        }
    }

    func stopServer() {
        server?.stop()
        server = nil
        serverState = .stopped
    }
}
