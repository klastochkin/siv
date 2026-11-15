import Foundation
import Network

enum TVServerError: LocalizedError {
    case invalidPort(UInt16)
    case listenerFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidPort(let port): return "Invalid port \(port)"
        case .listenerFailed(let reason): return "Cannot start server: \(reason)"
        }
    }
}

/// Minimal HTTP/1.1 server (one request per connection) serving a TV library folder.
final class TVServer {
    struct Configuration: Equatable {
        var root: URL
        /// Local address to bind; nil listens on all interfaces.
        var host: String?
        /// 0 picks a free port.
        var port: UInt16
        var token: String?
    }

    static let defaultPort: UInt16 = 8080
    static let requestTimeout: TimeInterval = 10

    let configuration: Configuration
    private let handler: TVHTTPHandler
    private let queue = DispatchQueue(label: "siv.tvserver", attributes: .concurrent)
    private var listener: NWListener?

    private(set) var port: UInt16?

    init(configuration: Configuration) {
        self.configuration = configuration
        self.handler = TVHTTPHandler(root: configuration.root, token: configuration.token)
    }

    deinit {
        listener?.cancel()
    }

    /// Calls `completion` once on an arbitrary queue with the bound port or an error.
    func start(completion: @escaping (Result<UInt16, Error>) -> Void) {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let nwPort: NWEndpoint.Port
        if configuration.port == 0 {
            nwPort = .any
        } else if let p = NWEndpoint.Port(rawValue: configuration.port) {
            nwPort = p
        } else {
            completion(.failure(TVServerError.invalidPort(configuration.port)))
            return
        }

        let listener: NWListener
        do {
            if let host = configuration.host, !host.isEmpty {
                parameters.requiredLocalEndpoint = .hostPort(host: NWEndpoint.Host(host), port: nwPort)
                listener = try NWListener(using: parameters)
            } else {
                listener = try NWListener(using: parameters, on: nwPort)
            }
        } catch {
            completion(.failure(TVServerError.listenerFailed(error.localizedDescription)))
            return
        }

        var reported = false
        let report: (Result<UInt16, Error>) -> Void = { result in
            guard !reported else { return }
            reported = true
            completion(result)
        }

        listener.stateUpdateHandler = { [weak self, weak listener] state in
            switch state {
            case .ready:
                let bound = listener?.port?.rawValue ?? 0
                self?.port = bound
                report(.success(bound))
            case .failed(let error):
                report(.failure(TVServerError.listenerFailed(error.localizedDescription)))
                listener?.cancel()
            case .waiting(let error):
                report(.failure(TVServerError.listenerFailed(error.localizedDescription)))
                listener?.cancel()
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        self.listener = listener
        listener.start(queue: DispatchQueue(label: "siv.tvserver.listener"))
    }

    func start() async throws -> UInt16 {
        try await withCheckedThrowingContinuation { continuation in
            start { continuation.resume(with: $0) }
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        port = nil
    }

    // MARK: - Connections

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + Self.requestTimeout) {
            connection.cancel()
        }
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] chunk, _, isComplete, error in
            guard let self else { connection.cancel(); return }
            var buffer = buffer
            if let chunk { buffer.append(chunk) }

            if buffer.range(of: TVHTTPRequest.headerTerminator) != nil {
                let response = TVHTTPRequest.parse(buffer).map(self.handler.respond) ?? TVHTTPHandler.badRequest()
                self.send(response, on: connection)
            } else if buffer.count > TVHTTPHandler.maxHeaderBytes {
                self.send(TVHTTPHandler.badRequest(status: 431), on: connection)
            } else if isComplete || error != nil {
                connection.cancel()
            } else {
                self.receive(on: connection, buffer: buffer)
            }
        }
    }

    private func send(_ response: TVHTTPResponse, on connection: NWConnection) {
        connection.send(content: response.serialized(), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

enum LANAddress {
    struct Interface: Equatable, Hashable {
        let name: String
        let address: String
    }

    /// IPv4 addresses on active, non-loopback interfaces, Wi‑Fi/Ethernet (`en*`) first.
    static func ipv4Interfaces() -> [Interface] {
        var result: [Interface] = []
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [] }
        defer { freeifaddrs(head) }

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let ifa = ptr.pointee
            let flags = Int32(ifa.ifa_flags)
            guard let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET),
                  flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else {
                continue
            }
            result.append(Interface(name: String(cString: ifa.ifa_name), address: String(cString: host)))
        }
        return result.sorted { lhs, rhs in
            let l = lhs.name.hasPrefix("en"), r = rhs.name.hasPrefix("en")
            return l != r ? l : lhs.name < rhs.name
        }
    }

    /// True for RFC 1918 private ranges and link-local, i.e. addresses not routable from the internet.
    static func isPrivateIPv4(_ address: String) -> Bool {
        let octets = address.split(separator: ".").compactMap { Int($0) }
        guard octets.count == 4, octets.allSatisfy({ (0...255).contains($0) }) else { return false }
        switch (octets[0], octets[1]) {
        case (10, _): return true
        case (172, 16...31): return true
        case (192, 168): return true
        case (169, 254): return true
        default: return false
        }
    }
}
