import XCTest
@testable import SIV

final class TVHTTPHandlerTests: XCTestCase {
    private var base: URL!
    private var root: URL!

    override func setUp() {
        super.setUp()
        base = TVTestSupport.makeTempDirectory("siv-tv-http")
        root = base.appendingPathComponent("library", isDirectory: true)
        let fm = FileManager.default
        try! fm.createDirectory(at: root.appendingPathComponent("thumbs"), withIntermediateDirectories: true)
        try! fm.createDirectory(at: root.appendingPathComponent("full"), withIntermediateDirectories: true)
        try! Data(#"{"version":1,"photos":[]}"#.utf8).write(to: root.appendingPathComponent("index.json"))
        try! Data([0xFF, 0xD8, 0xFF, 0x00, 0x01]).write(to: root.appendingPathComponent("thumbs/abc.jpg"))
        try! Data("png".utf8).write(to: root.appendingPathComponent("full/x.PNG"))
        try! Data("webp".utf8).write(to: root.appendingPathComponent("full/x.webp"))
        try! Data("secret".utf8).write(to: root.appendingPathComponent(".hidden.jpg"))
        try! Data("notes".utf8).write(to: root.appendingPathComponent("notes.txt"))
        try! Data("outside".utf8).write(to: base.appendingPathComponent("secret.jpg"))
        try! fm.createDirectory(at: root.appendingPathComponent("dir.jpg"), withIntermediateDirectories: true)
        try! fm.createSymbolicLink(at: root.appendingPathComponent("escape.jpg"), withDestinationURL: base.appendingPathComponent("secret.jpg"))
        try! fm.createSymbolicLink(at: root.appendingPathComponent("inside.jpg"), withDestinationURL: root.appendingPathComponent("thumbs/abc.jpg"))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: base)
        super.tearDown()
    }

    private func request(_ target: String, headers: [String: String] = [:]) -> TVHTTPRequest {
        TVHTTPRequest(method: "GET", target: target, headers: headers)
    }

    private func request(_ method: String, _ target: String) -> TVHTTPRequest {
        TVHTTPRequest(method: method, target: target, headers: [:])
    }

    private func handler(token: String? = nil) -> TVHTTPHandler {
        TVHTTPHandler(root: root, token: token)
    }

    // MARK: - Parsing

    func testParseRequestLineAndHeaders() {
        let raw = Data("GET /thumbs/abc.jpg?token=a%20b&x HTTP/1.1\r\nHost: tv\r\nAuthorization:  Bearer t \r\n\r\n".utf8)
        let req = TVHTTPRequest.parse(raw)!
        XCTAssertEqual(req.method, "GET")
        XCTAssertEqual(req.path, "/thumbs/abc.jpg")
        XCTAssertEqual(req.queryItems, ["token": "a b", "x": ""])
        XCTAssertEqual(req.headers["host"], "tv")
        XCTAssertEqual(req.headers["authorization"], "Bearer t")
    }

    func testParseRejectsIncompleteAndMalformedRequests() {
        XCTAssertNil(TVHTTPRequest.parse(Data("GET / HTTP/1.1\r\nHost: x\r\n".utf8)))
        XCTAssertNil(TVHTTPRequest.parse(Data("GARBAGE\r\n\r\n".utf8)))
        XCTAssertNil(TVHTTPRequest.parse(Data("GET relative HTTP/1.1\r\n\r\n".utf8)))
        XCTAssertNil(TVHTTPRequest.parse(Data("GET / SPDY/3\r\n\r\n".utf8)))
        XCTAssertNil(TVHTTPRequest.parse(Data([0xFF, 0xFE, 0x0D, 0x0A, 0x0D, 0x0A])))
    }

    func testQueryParsingHandlesPlusAndMissingQuery() {
        XCTAssertEqual(request("/a?token=x+y").queryItems["token"], "x y")
        XCTAssertEqual(request("/a").queryItems, [:])
        XCTAssertEqual(request("/a?").queryItems, [:])
    }

    // MARK: - Serving

    func testServesIndexJSONWithNoCache() {
        let res = handler().respond(to: request("/index.json"))
        XCTAssertEqual(res.status, 200)
        XCTAssertEqual(res.header("Content-Type"), "application/json; charset=utf-8")
        XCTAssertEqual(res.header("Cache-Control"), "no-cache")
        XCTAssertEqual(String(data: res.body, encoding: .utf8), #"{"version":1,"photos":[]}"#)
        XCTAssertEqual(res.header("Content-Length"), String(res.body.count))
    }

    func testServesImagesWithContentTypes() {
        let jpg = handler().respond(to: request("/thumbs/abc.jpg"))
        XCTAssertEqual(jpg.status, 200)
        XCTAssertEqual(jpg.header("Content-Type"), "image/jpeg")
        XCTAssertEqual(jpg.header("Cache-Control"), "public, max-age=86400")
        XCTAssertEqual(jpg.body, Data([0xFF, 0xD8, 0xFF, 0x00, 0x01]))
        XCTAssertEqual(handler().respond(to: request("/full/x.PNG")).header("Content-Type"), "image/png")
        XCTAssertEqual(handler().respond(to: request("/full/x.webp")).header("Content-Type"), "image/webp")
    }

    func testPercentEncodedPathAndDuplicateSlashes() {
        try! Data("sp".utf8).write(to: root.appendingPathComponent("thumbs/a b.jpg"))
        XCTAssertEqual(handler().respond(to: request("/thumbs/a%20b.jpg")).status, 200)
        XCTAssertEqual(handler().respond(to: request("//thumbs///abc.jpg")).status, 200)
    }

    func testHeadReturnsHeadersWithoutBody() {
        let res = handler().respond(to: request("HEAD", "/thumbs/abc.jpg"))
        XCTAssertEqual(res.status, 200)
        XCTAssertTrue(res.body.isEmpty)
        XCTAssertEqual(res.header("Content-Length"), "5")
        XCTAssertEqual(res.header("Content-Type"), "image/jpeg")
    }

    func testRootReturnsHealthText() {
        let res = handler().respond(to: request("/"))
        XCTAssertEqual(res.status, 200)
        XCTAssertEqual(String(data: res.body, encoding: .utf8), "SIV TV library server\n")
    }

    func testEveryResponseHasCORSAndSecurityHeaders() {
        let targets = ["/", "/index.json", "/missing.jpg", "/notes.txt"]
        for res in targets.map({ handler().respond(to: request($0)) })
            + [handler().respond(to: request("POST", "/index.json")),
               handler(token: "t").respond(to: request("/index.json")),
               handler().respond(to: request("OPTIONS", "/index.json"))] {
            XCTAssertEqual(res.header("Access-Control-Allow-Origin"), "*")
            XCTAssertEqual(res.header("Connection"), "close")
            XCTAssertEqual(res.header("X-Content-Type-Options"), "nosniff")
        }
    }

    // MARK: - Methods

    func testOptionsPreflight() {
        let res = handler(token: "secret").respond(to: request("OPTIONS", "/index.json"))
        XCTAssertEqual(res.status, 204)
        XCTAssertEqual(res.header("Access-Control-Allow-Methods"), "GET, HEAD, OPTIONS")
        XCTAssertEqual(res.header("Access-Control-Allow-Headers"), "Authorization")
        XCTAssertTrue(res.body.isEmpty)
    }

    func testWriteMethodsAreRejected() {
        for method in ["POST", "PUT", "DELETE", "PATCH", "PROPFIND", "get"] {
            let res = handler().respond(to: request(method, "/index.json"))
            XCTAssertEqual(res.status, 405, method)
            XCTAssertEqual(res.header("Allow"), "GET, HEAD, OPTIONS")
        }
    }

    // MARK: - Path safety

    func testTraversalAndEscapesAreNotFound() {
        let attacks = [
            "/../secret.jpg",
            "/thumbs/../../secret.jpg",
            "/%2e%2e/secret.jpg",
            "/thumbs%2f..%2f..%2fsecret.jpg",
            "/%2E%2E%2Fsecret.jpg",
            "/escape.jpg",
            "/.hidden.jpg",
            "/thumbs/./abc.jpg",
            "/notes.txt",
            "/thumbs",
            "/thumbs/",
            "/dir.jpg",
            "/missing.jpg",
            "/index.json/",
            "/etc/passwd"
        ]
        for target in attacks {
            let res = handler().respond(to: request(target))
            XCTAssertEqual(res.status, 404, target)
            XCTAssertFalse(String(decoding: res.body, as: UTF8.self).contains("outside"), target)
        }
    }

    func testBackslashNullAndBadEncodingAreBadRequests() {
        for target in ["/thumbs\\abc.jpg", "/abc%00.jpg", "/bad%zz.jpg", "/%E0%A4%A.jpg"] {
            XCTAssertEqual(handler().respond(to: request(target)).status, 400, target)
        }
    }

    func testSymlinkInsideRootIsServed() {
        XCTAssertEqual(handler().respond(to: request("/inside.jpg")).status, 200)
    }

    func testRootReachedThroughSymlinkStillServes() {
        let link = base.appendingPathComponent("link")
        try! FileManager.default.createSymbolicLink(at: link, withDestinationURL: root)
        let res = TVHTTPHandler(root: link, token: nil).respond(to: request("/thumbs/abc.jpg"))
        XCTAssertEqual(res.status, 200)
        XCTAssertEqual(TVHTTPHandler(root: link, token: nil).respond(to: request("/../secret.jpg")).status, 404)
    }

    // MARK: - Token

    func testTokenRequiredWhenConfigured() {
        let h = handler(token: "s3cret")
        XCTAssertEqual(h.respond(to: request("/index.json")).status, 401)
        XCTAssertEqual(h.respond(to: request("/")).status, 401)
        XCTAssertEqual(h.respond(to: request("/index.json?token=wrong")).status, 401)
        XCTAssertEqual(h.respond(to: request("/index.json?token=s3cre")).status, 401)
        XCTAssertEqual(h.respond(to: request("/index.json", headers: ["authorization": "Bearer nope"])).status, 401)
        XCTAssertEqual(h.respond(to: request("/index.json", headers: ["authorization": "Basic s3cret"])).status, 401)

        XCTAssertEqual(h.respond(to: request("/index.json?token=s3cret")).status, 200)
        XCTAssertEqual(h.respond(to: request("/thumbs/abc.jpg?v=1&token=s3cret")).status, 200)
        XCTAssertEqual(h.respond(to: request("/index.json", headers: ["authorization": "Bearer s3cret"])).status, 200)
    }

    func testUnauthorizedDoesNotRevealExistence() {
        let h = handler(token: "s3cret")
        XCTAssertEqual(h.respond(to: request("/index.json")).body, h.respond(to: request("/missing.jpg")).body)
    }

    func testBlankTokenMeansOpen() {
        XCTAssertNil(handler(token: "  ").token)
        XCTAssertEqual(handler(token: "").respond(to: request("/index.json")).status, 200)
        XCTAssertEqual(handler(token: " t ").token, "t")
    }

    func testConstantTimeEquals() {
        XCTAssertTrue(TVHTTPHandler.constantTimeEquals("abc", "abc"))
        XCTAssertFalse(TVHTTPHandler.constantTimeEquals("abc", "abd"))
        XCTAssertFalse(TVHTTPHandler.constantTimeEquals("abc", "abcd"))
        XCTAssertTrue(TVHTTPHandler.constantTimeEquals("", ""))
    }

    // MARK: - Serialization

    func testSerializedResponseFormat() {
        let res = handler().respond(to: request("/index.json"))
        let text = String(data: res.serialized(), encoding: .utf8)!
        XCTAssertTrue(text.hasPrefix("HTTP/1.1 200 OK\r\n"))
        XCTAssertTrue(text.contains("\r\nContent-Type: application/json; charset=utf-8\r\n"))
        XCTAssertTrue(text.hasSuffix("\r\n\r\n" + #"{"version":1,"photos":[]}"#))
    }

    func testBadRequestResponse() {
        let res = TVHTTPHandler.badRequest(status: 431)
        XCTAssertEqual(res.status, 431)
        XCTAssertTrue(String(data: res.serialized(), encoding: .utf8)!.hasPrefix("HTTP/1.1 431 Request Header Fields Too Large\r\n"))
    }
}
