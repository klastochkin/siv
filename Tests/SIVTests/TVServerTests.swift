import XCTest
@testable import SIV

/// End-to-end tests over real TCP sockets on 127.0.0.1.
final class TVServerTests: XCTestCase {
    private var root: URL!
    private var server: TVServer?
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        root = TVTestSupport.makeTempDirectory("siv-tv-server")
        try! FileManager.default.createDirectory(at: root.appendingPathComponent("thumbs"), withIntermediateDirectories: true)
        try! Data(#"{"version":1,"photos":[]}"#.utf8).write(to: root.appendingPathComponent("index.json"))
        try! Data((0..<200_000).map { UInt8($0 % 251) }).write(to: root.appendingPathComponent("thumbs/big.jpg"))
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 5
        session = URLSession(configuration: config)
    }

    override func tearDown() {
        server?.stop()
        session.invalidateAndCancel()
        try? FileManager.default.removeItem(at: root)
        super.tearDown()
    }

    private func startServer(token: String? = nil, host: String? = "127.0.0.1", port: UInt16 = 0) async throws -> UInt16 {
        let server = TVServer(configuration: .init(root: root, host: host, port: port, token: token))
        self.server = server
        return try await server.start()
    }

    private func get(_ port: UInt16, _ path: String, method: String = "GET", headers: [String: String] = [:]) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)\(path)")!)
        request.httpMethod = method
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        let (data, response) = try await session.data(for: request)
        return (data, response as! HTTPURLResponse)
    }

    private func expectStatus(_ expected: Int, _ port: UInt16, _ path: String, method: String = "GET",
                              headers: [String: String] = [:], line: UInt = #line) async throws {
        let actual = try await get(port, path, method: method, headers: headers).1.statusCode
        XCTAssertEqual(actual, expected, "\(method) \(path)", line: line)
    }

    func testStartReportsBoundPort() async throws {
        let port = try await startServer()
        XCTAssertGreaterThan(port, 0)
        XCTAssertEqual(server?.port, port)
    }

    func testServesIndexAndLargeBinaryIntact() async throws {
        let port = try await startServer()
        let (index, indexResponse) = try await get(port, "/index.json")
        XCTAssertEqual(indexResponse.statusCode, 200)
        XCTAssertEqual(indexResponse.value(forHTTPHeaderField: "Content-Type"), "application/json; charset=utf-8")
        XCTAssertEqual(indexResponse.value(forHTTPHeaderField: "Access-Control-Allow-Origin"), "*")
        XCTAssertEqual(String(data: index, encoding: .utf8), #"{"version":1,"photos":[]}"#)

        let (image, imageResponse) = try await get(port, "/thumbs/big.jpg")
        XCTAssertEqual(imageResponse.statusCode, 200)
        XCTAssertEqual(image, try Data(contentsOf: root.appendingPathComponent("thumbs/big.jpg")))
    }

    func testHeadAndErrors() async throws {
        let port = try await startServer()
        let (headBody, head) = try await get(port, "/thumbs/big.jpg", method: "HEAD")
        XCTAssertEqual(head.statusCode, 200)
        XCTAssertEqual(head.value(forHTTPHeaderField: "Content-Length"), "200000")
        XCTAssertTrue(headBody.isEmpty)

        try await expectStatus(404, port, "/nope.jpg")
        try await expectStatus(405, port, "/index.json", method: "POST")
        try await expectStatus(405, port, "/index.json", method: "DELETE")
        try await expectStatus(204, port, "/index.json", method: "OPTIONS")
    }

    func testRawTraversalIsRejected() async throws {
        let port = try await startServer()
        try Data("outside".utf8).write(to: root.deletingLastPathComponent().appendingPathComponent("outside-\(port).jpg"))
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent().appendingPathComponent("outside-\(port).jpg")) }

        // URLSession normalizes "..", so send it raw.
        let raw = TVTestSupport.rawRequest(Data("GET /../outside-\(port).jpg HTTP/1.1\r\nHost: x\r\n\r\n".utf8), port: port)
        XCTAssertEqual(TVTestSupport.statusCode(of: raw), 404)
        XCTAssertFalse(String(decoding: raw, as: UTF8.self).contains("outside\n"))
    }

    func testMalformedAndOversizedRequests() async throws {
        let port = try await startServer()
        let malformed = TVTestSupport.rawRequest(Data("HELLO\r\n\r\n".utf8), port: port)
        XCTAssertEqual(TVTestSupport.statusCode(of: malformed), 400)

        var huge = "GET / HTTP/1.1\r\nX-Pad: "
        huge += String(repeating: "a", count: TVHTTPHandler.maxHeaderBytes + 100)
        let oversized = TVTestSupport.rawRequest(Data(huge.utf8), port: port)
        XCTAssertEqual(TVTestSupport.statusCode(of: oversized), 431)
    }

    func testRequestsSplitAcrossPacketsAreAssembled() async throws {
        let port = try await startServer()
        let response: Data = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let fd = socket(AF_INET, SOCK_STREAM, 0)
                defer { close(fd) }
                var addr = sockaddr_in()
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port = port.bigEndian
                inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr)
                _ = withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
                }
                for part in ["GET /index", ".json HTTP/1.1\r\n", "Host: x\r\n", "\r\n"] {
                    _ = part.withCString { send(fd, $0, strlen($0), 0) }
                    usleep(50_000)
                }
                var result = Data()
                var buf = [UInt8](repeating: 0, count: 4096)
                while true {
                    let n = recv(fd, &buf, buf.count, 0)
                    if n <= 0 { break }
                    result.append(buf, count: n)
                }
                continuation.resume(returning: result)
            }
        }
        XCTAssertEqual(TVTestSupport.statusCode(of: response), 200)
        XCTAssertTrue(String(decoding: response, as: UTF8.self).hasSuffix(#"{"version":1,"photos":[]}"#))
    }

    func testIdleConnectionDoesNotBlockOthers() async throws {
        let port = try await startServer()
        let idle = socket(AF_INET, SOCK_STREAM, 0)
        defer { close(idle) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr)
        _ = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(idle, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        try await expectStatus(200, port, "/index.json")
    }

    func testManyConcurrentRequests() async throws {
        let port = try await startServer()
        let expected = try Data(contentsOf: root.appendingPathComponent("thumbs/big.jpg"))
        try await withThrowingTaskGroup(of: Data.self) { group in
            for _ in 0..<40 {
                group.addTask { try await self.get(port, "/thumbs/big.jpg").0 }
            }
            var count = 0
            for try await data in group {
                XCTAssertEqual(data, expected)
                count += 1
            }
            XCTAssertEqual(count, 40)
        }
    }

    func testTokenProtection() async throws {
        let port = try await startServer(token: "tok123")
        try await expectStatus(401, port, "/index.json")
        try await expectStatus(401, port, "/index.json?token=bad")
        try await expectStatus(200, port, "/index.json?token=tok123")
        try await expectStatus(200, port, "/index.json", headers: ["Authorization": "Bearer tok123"])
    }

    func testStopClosesListener() async throws {
        let port = try await startServer()
        try await expectStatus(200, port, "/")
        server?.stop()
        XCTAssertNil(server?.port)
        try await Task.sleep(nanoseconds: 200_000_000)
        do {
            _ = try await get(port, "/")
            XCTFail("server still answering after stop")
        } catch {
            // expected: connection refused
        }
    }

    func testPortInUseFails() async throws {
        let port = try await startServer()
        let second = TVServer(configuration: .init(root: root, host: "127.0.0.1", port: port, token: nil))
        defer { second.stop() }
        do {
            _ = try await second.start()
            XCTFail("second server bound to a busy port")
        } catch {
            XCTAssertTrue(error is TVServerError)
        }
    }

    func testBindingToLoopbackIsNotReachableOnLANAddress() async throws {
        guard let lan = LANAddress.ipv4Interfaces().first(where: { LANAddress.isPrivateIPv4($0.address) })?.address else {
            throw XCTSkip("No LAN address")
        }
        let port = try await startServer(host: "127.0.0.1")
        let raw = TVTestSupport.rawRequest(Data("GET / HTTP/1.1\r\n\r\n".utf8), port: port, host: lan, timeout: 2)
        XCTAssertTrue(raw.isEmpty, "loopback-bound server answered on \(lan)")
    }

    func testBindingToLANAddressServes() async throws {
        guard let lan = LANAddress.ipv4Interfaces().first(where: { LANAddress.isPrivateIPv4($0.address) })?.address else {
            throw XCTSkip("No LAN address")
        }
        let port = try await startServer(host: lan)
        let raw = TVTestSupport.rawRequest(Data("GET / HTTP/1.1\r\n\r\n".utf8), port: port, host: lan)
        XCTAssertEqual(TVTestSupport.statusCode(of: raw), 200)
        let loop = TVTestSupport.rawRequest(Data("GET / HTTP/1.1\r\n\r\n".utf8), port: port, host: "127.0.0.1", timeout: 2)
        XCTAssertTrue(loop.isEmpty, "LAN-bound server answered on loopback")
    }

    func testInvalidBindAddressFails() async throws {
        let server = TVServer(configuration: .init(root: root, host: "203.0.113.77", port: 0, token: nil))
        defer { server.stop() }
        do {
            _ = try await server.start()
            XCTFail("bound to an address this machine does not own")
        } catch {
            XCTAssertTrue(error is TVServerError)
        }
    }
}

final class LANAddressTests: XCTestCase {
    func testPrivateRanges() {
        for address in ["10.1.2.3", "10.255.255.255", "172.16.0.1", "172.31.255.1", "192.168.1.50", "169.254.3.4"] {
            XCTAssertTrue(LANAddress.isPrivateIPv4(address), address)
        }
        for address in ["8.8.8.8", "172.15.0.1", "172.32.0.1", "192.169.0.1", "100.64.0.1", "127.0.0.1", "", "10.0.0", "10.0.0.256", "a.b.c.d"] {
            XCTAssertFalse(LANAddress.isPrivateIPv4(address), address)
        }
    }

    func testInterfacesExcludeLoopbackAndPreferEthernet() {
        let interfaces = LANAddress.ipv4Interfaces()
        XCTAssertFalse(interfaces.contains { $0.address == "127.0.0.1" })
        if let firstNonEN = interfaces.firstIndex(where: { !$0.name.hasPrefix("en") }) {
            XCTAssertFalse(interfaces[firstNonEN...].contains { $0.name.hasPrefix("en") })
        }
    }
}
