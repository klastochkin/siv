import Foundation

struct TVHTTPRequest: Equatable {
    let method: String
    let target: String
    let headers: [String: String]

    var path: String {
        String(target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
    }

    var queryItems: [String: String] {
        let parts = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return [:] }
        var items: [String: String] = [:]
        for pair in parts[1].split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let decode: (Substring) -> String = {
                $0.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? String($0)
            }
            items[decode(kv[0])] = kv.count > 1 ? decode(kv[1]) : ""
        }
        return items
    }

    static let headerTerminator = Data("\r\n\r\n".utf8)

    /// Parses the request line and headers. Returns nil both while the header block is incomplete
    /// and when it is not a valid HTTP/1.x request; callers tell them apart via `headerTerminator`.
    static func parse(_ data: Data) -> TVHTTPRequest? {
        guard let end = data.range(of: headerTerminator),
              let head = String(data: data[data.startIndex..<end.lowerBound], encoding: .utf8) else {
            return nil
        }
        var lines = head.components(separatedBy: "\r\n")
        let requestLine = lines.removeFirst().split(separator: " ", omittingEmptySubsequences: true)
        guard requestLine.count == 3, requestLine[2].hasPrefix("HTTP/1."), requestLine[1].hasPrefix("/") else {
            return nil
        }
        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            headers[name] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        return TVHTTPRequest(method: String(requestLine[0]), target: String(requestLine[1]), headers: headers)
    }
}

struct TVHTTPResponse: Equatable {
    var status: Int
    var headers: [(String, String)]
    var body: Data

    static func == (lhs: TVHTTPResponse, rhs: TVHTTPResponse) -> Bool {
        lhs.status == rhs.status && lhs.body == rhs.body
            && lhs.headers.map { "\($0.0):\($0.1)" } == rhs.headers.map { "\($0.0):\($0.1)" }
    }

    func header(_ name: String) -> String? {
        headers.first { $0.0.caseInsensitiveCompare(name) == .orderedSame }?.1
    }

    static func reason(for status: Int) -> String {
        switch status {
        case 200: return "OK"
        case 204: return "No Content"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 431: return "Request Header Fields Too Large"
        case 500: return "Internal Server Error"
        default: return "Status"
        }
    }

    func serialized() -> Data {
        var head = "HTTP/1.1 \(status) \(Self.reason(for: status))\r\n"
        for (name, value) in headers {
            head += "\(name): \(value)\r\n"
        }
        head += "\r\n"
        var data = Data(head.utf8)
        data.append(body)
        return data
    }
}

/// Read-only request handler for the TV library. Serves only image/JSON files under `root`,
/// never lists directories, hides dotfiles, and rejects anything that escapes `root`.
struct TVHTTPHandler {
    static let maxHeaderBytes = 16 * 1024
    static let allowedMethods = "GET, HEAD, OPTIONS"
    static let contentTypes: [String: String] = [
        "json": "application/json; charset=utf-8",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "png": "image/png",
        "webp": "image/webp"
    ]

    let root: URL
    let token: String?
    private let resolvedRoot: String

    init(root: URL, token: String?) {
        self.root = root
        let trimmed = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.token = (trimmed?.isEmpty ?? true) ? nil : trimmed
        self.resolvedRoot = root.resolvingSymlinksInPath().standardizedFileURL.path
    }

    func respond(to request: TVHTTPRequest) -> TVHTTPResponse {
        switch request.method {
        case "OPTIONS":
            return make(204, extra: [
                ("Access-Control-Allow-Methods", Self.allowedMethods),
                ("Access-Control-Allow-Headers", "Authorization"),
                ("Access-Control-Max-Age", "86400")
            ])
        case "GET", "HEAD":
            break
        default:
            return text(405, "Method not allowed\n", extra: [("Allow", Self.allowedMethods)])
        }

        guard isAuthorized(request) else {
            return text(401, "Unauthorized\n")
        }

        guard let path = request.path.removingPercentEncoding,
              !path.contains("\0"), !path.contains("\\") else {
            return text(400, "Bad request\n")
        }

        if path == "/" {
            return finish(text(200, "SIV TV library server\n"), method: request.method)
        }

        let segments = path.split(separator: "/", omittingEmptySubsequences: true)
        guard !segments.isEmpty, !path.hasSuffix("/"), !segments.contains(where: { $0.hasPrefix(".") }),
              let ext = segments.last.map({ URL(fileURLWithPath: String($0)).pathExtension.lowercased() }),
              let contentType = Self.contentTypes[ext] else {
            return text(404, "Not found\n")
        }

        let fileURL = segments.reduce(root) { $0.appendingPathComponent(String($1)) }
        let resolved = fileURL.resolvingSymlinksInPath().standardizedFileURL.path
        var isDirectory: ObjCBool = false
        guard resolved.hasPrefix(resolvedRoot + "/"),
              FileManager.default.fileExists(atPath: resolved, isDirectory: &isDirectory), !isDirectory.boolValue else {
            return text(404, "Not found\n")
        }
        guard let data = FileManager.default.contents(atPath: resolved) else {
            return text(500, "Cannot read file\n")
        }

        let cacheControl = ext == "json" ? "no-cache" : "public, max-age=86400"
        let response = make(200, body: data, extra: [
            ("Content-Type", contentType),
            ("Cache-Control", cacheControl)
        ])
        return finish(response, method: request.method)
    }

    func isAuthorized(_ request: TVHTTPRequest) -> Bool {
        guard let token else { return true }
        if let supplied = request.queryItems["token"], Self.constantTimeEquals(supplied, token) {
            return true
        }
        if let auth = request.headers["authorization"], auth.hasPrefix("Bearer ") {
            return Self.constantTimeEquals(String(auth.dropFirst(7)), token)
        }
        return false
    }

    static func constantTimeEquals(_ a: String, _ b: String) -> Bool {
        let x = Array(a.utf8), y = Array(b.utf8)
        guard x.count == y.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<x.count { diff |= x[i] ^ y[i] }
        return diff == 0
    }

    // MARK: - Response builders

    private func make(_ status: Int, body: Data = Data(), extra: [(String, String)] = []) -> TVHTTPResponse {
        var headers: [(String, String)] = [
            ("Access-Control-Allow-Origin", "*"),
            ("X-Content-Type-Options", "nosniff"),
            ("Connection", "close"),
            ("Content-Length", String(body.count))
        ]
        headers.append(contentsOf: extra)
        return TVHTTPResponse(status: status, headers: headers, body: body)
    }

    private func text(_ status: Int, _ message: String, extra: [(String, String)] = []) -> TVHTTPResponse {
        make(status, body: Data(message.utf8), extra: [("Content-Type", "text/plain; charset=utf-8")] + extra)
    }

    /// HEAD keeps GET's headers (including Content-Length) but drops the body.
    private func finish(_ response: TVHTTPResponse, method: String) -> TVHTTPResponse {
        guard method == "HEAD" else { return response }
        var head = response
        head.body = Data()
        return head
    }

    static func badRequest(status: Int = 400) -> TVHTTPResponse {
        let body = Data("\(TVHTTPResponse.reason(for: status))\n".utf8)
        return TVHTTPResponse(status: status, headers: [
            ("Access-Control-Allow-Origin", "*"),
            ("Connection", "close"),
            ("Content-Length", String(body.count)),
            ("Content-Type", "text/plain; charset=utf-8")
        ], body: body)
    }
}
