import Foundation

/// Headless entry points so the TV library can be published and served without the GUI
/// (e.g. from a launchd agent):
///
///     SIV tv-publish [--album PATH.sivalb] [--size fullhd|original] --out DIR
///     SIV tv-serve --root DIR [--host IP|all] [--port 8080] [--token TOKEN]
enum TVCommandLine {
    enum Command: Equatable {
        case publish(album: String?, out: String, size: TVExportSize)
        case serve(root: String, host: String?, port: UInt16, token: String?)
        case help
    }

    struct UsageError: LocalizedError, Equatable {
        let message: String
        var errorDescription: String? { message }
    }

    static let usage = """
    Usage:
      SIV tv-publish [--album PATH.sivalb] [--size fullhd|original] --out DIR
          Export an album (default: your default album) as a TV library.
          --size fullhd (default) fits 1920×1080 and sharpens; original keeps the source resolution.
      SIV tv-serve --root DIR [--host IP|all] [--port 8080] [--token TOKEN]
          Serve a TV library read-only. --host defaults to this Mac's LAN address.
    """

    /// Returns nil when the arguments are not a TV subcommand (normal GUI launch).
    static func parse(_ args: [String]) throws -> Command? {
        guard let sub = args.first, sub.hasPrefix("tv-") else { return nil }
        var options: [String: String] = [:]
        var rest = Array(args.dropFirst())
        while !rest.isEmpty {
            let flag = rest.removeFirst()
            if flag == "-h" || flag == "--help" { return .help }
            guard flag.hasPrefix("--"), !rest.isEmpty else {
                throw UsageError(message: "Unexpected argument \(flag)")
            }
            options[String(flag.dropFirst(2))] = rest.removeFirst()
        }

        func take(_ allowed: Set<String>) throws {
            if let unknown = options.keys.first(where: { !allowed.contains($0) }) {
                throw UsageError(message: "Unknown option --\(unknown)")
            }
        }

        switch sub {
        case "tv-publish":
            try take(["album", "out", "size"])
            guard let out = options["out"] else { throw UsageError(message: "tv-publish needs --out DIR") }
            var size = TVExportSize.fullHD
            if let raw = options["size"] {
                guard let parsed = TVExportSize(rawValue: raw.lowercased()) else {
                    throw UsageError(message: "Invalid size \(raw) (use fullhd or original)")
                }
                size = parsed
            }
            return .publish(album: options["album"], out: out, size: size)
        case "tv-serve":
            try take(["root", "host", "port", "token"])
            guard let root = options["root"] else { throw UsageError(message: "tv-serve needs --root DIR") }
            var port = TVServer.defaultPort
            if let raw = options["port"] {
                guard let value = UInt16(raw), value > 0 else { throw UsageError(message: "Invalid port \(raw)") }
                port = value
            }
            var host = options["host"]
            if host == nil {
                host = LANAddress.ipv4Interfaces().first { LANAddress.isPrivateIPv4($0.address) }?.address
            } else if host == "all" {
                host = nil
            }
            return .serve(root: root, host: host, port: port, token: options["token"])
        case "tv-help":
            return .help
        default:
            throw UsageError(message: "Unknown command \(sub)")
        }
    }

    static func loadAlbum(at path: String) throws -> Album {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode(Album.self, from: data)
    }

    /// Runs a TV subcommand if present. Returns false for a normal GUI launch; otherwise exits.
    static func runIfRequested(_ args: [String] = Array(CommandLine.arguments.dropFirst())) -> Bool {
        let command: Command?
        do {
            command = try parse(args)
        } catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n\n\(usage)\n".utf8))
            exit(2)
        }
        guard let command else { return false }
        setvbuf(stdout, nil, _IOLBF, 0)

        switch command {
        case .help:
            print(usage)
            exit(0)
        case .publish(let albumPath, let out, let size):
            do {
                let path = albumPath ?? AlbumManager().defaultAlbumPath
                let album = try loadAlbum(at: path)
                let root = URL(fileURLWithPath: out, isDirectory: true)
                let report = try TVExportService.export(
                    images: album.images, albumName: album.name, to: root, options: .preset(size)
                )
                print("\(report.summary) → \(root.path)")
                for failure in report.failed { print("  failed: \(failure.path): \(failure.reason)") }
                for missing in report.missing { print("  missing: \(missing)") }
                exit(report.failed.isEmpty ? 0 : 1)
            } catch {
                FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
                exit(1)
            }
        case .serve(let root, let host, let port, let token):
            let server = TVServer(configuration: .init(
                root: URL(fileURLWithPath: root, isDirectory: true), host: host, port: port, token: token
            ))
            server.start { result in
                switch result {
                case .success(let bound):
                    print("Serving \(root) at http://\(host ?? "0.0.0.0"):\(bound)\(token.map { _ in " (token required)" } ?? "")")
                    print("Press Ctrl-C to stop.")
                case .failure(let error):
                    FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
                    exit(1)
                }
            }
            withExtendedLifetime(server) { dispatchMain() }
        }
    }
}
