import XCTest
@testable import SIV

@MainActor
final class TVPublishViewModelTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var workDir: URL!
    private let lan = [LANAddress.Interface(name: "en0", address: "192.168.1.50")]

    override func setUp() async throws {
        suiteName = "siv-tv-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        workDir = TVTestSupport.makeTempDirectory("siv-tv-vm")
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: workDir)
    }

    private func makeVM(interfaces: [LANAddress.Interface]? = nil) -> TVPublishViewModel {
        TVPublishViewModel(defaults: defaults, interfaces: interfaces ?? lan)
    }

    func testDefaults() {
        let vm = makeVM()
        XCTAssertTrue(vm.libraryPath.hasSuffix("/SIV-TV-Library"))
        XCTAssertEqual(vm.port, 8080)
        XCTAssertEqual(vm.bindHost, "192.168.1.50")
        XCTAssertEqual(vm.token, "")
        XCTAssertEqual(vm.serverState, .stopped)
        XCTAssertNil(vm.serverURL)
        XCTAssertNil(vm.exposureWarning)
    }

    func testDefaultBindSkipsNonPrivateAddresses() {
        let vm = makeVM(interfaces: [
            LANAddress.Interface(name: "en0", address: "100.70.1.2"),
            LANAddress.Interface(name: "en1", address: "192.168.1.9")
        ])
        XCTAssertEqual(vm.bindHost, "192.168.1.9")
        XCTAssertEqual(makeVM(interfaces: []).bindHost, "")
    }

    func testSettingsPersist() {
        let vm = makeVM()
        vm.libraryPath = workDir.path
        vm.port = 9090
        vm.bindHost = ""
        vm.token = "abc"

        let reloaded = makeVM()
        XCTAssertEqual(reloaded.libraryPath, workDir.path)
        XCTAssertEqual(reloaded.port, 9090)
        XCTAssertEqual(reloaded.bindHost, "")
        XCTAssertEqual(reloaded.token, "abc")
    }

    func testInvalidStoredPortFallsBack() {
        defaults.set(70000, forKey: "tv.port")
        XCTAssertEqual(makeVM().port, 8080)
    }

    func testGenerateToken() {
        let vm = makeVM()
        vm.generateToken()
        XCTAssertEqual(vm.token.count, 24)
        XCTAssertTrue(vm.token.allSatisfy(\.isHexDigit))
        let first = vm.token
        vm.generateToken()
        XCTAssertNotEqual(first, vm.token)
    }

    func testExposureWarnings() {
        let vm = makeVM(interfaces: [
            LANAddress.Interface(name: "en0", address: "10.0.0.2"),
            LANAddress.Interface(name: "utun3", address: "100.80.1.1")
        ])
        vm.bindHost = "10.0.0.2"
        XCTAssertNil(vm.exposureWarning)
        vm.bindHost = ""
        XCTAssertEqual(vm.exposureWarning, "Listening on all interfaces includes non-private address 100.80.1.1.")
        vm.bindHost = "8.8.8.8"
        XCTAssertEqual(vm.exposureWarning, "8.8.8.8 is not a private LAN address.")
        vm.bindHost = "127.0.0.1"
        XCTAssertEqual(vm.exposureWarning, "127.0.0.1 is only reachable from this Mac; the TV cannot connect.")
    }

    func testPublishThenServeEndToEnd() async throws {
        let src = workDir.appendingPathComponent("src", isDirectory: true)
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        let images = (0..<3).map {
            ImageFile(path: TVTestSupport.writeImage(to: src.appendingPathComponent("p\($0).jpg"), width: 300, height: 200).path)
        } + [ImageFile(path: src.appendingPathComponent("missing.jpg").path)]

        let vm = makeVM()
        vm.libraryPath = workDir.appendingPathComponent("lib").path
        vm.bindHost = "127.0.0.1"
        vm.port = 0
        vm.token = "t0k"

        await vm.publish(images: images, albumName: "Holiday")
        XCTAssertFalse(vm.isPublishing)
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.lastReport?.exported, 3)
        XCTAssertEqual(vm.lastReport?.missing.count, 1)
        XCTAssertEqual(vm.progressDone, 4)

        await vm.startServer()
        guard case .running(let port) = vm.serverState else {
            return XCTFail("server not running: \(vm.serverState)")
        }
        XCTAssertTrue(vm.isServerRunning)
        XCTAssertEqual(vm.serverURL, "http://127.0.0.1:\(port)")

        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(from: URL(string: "http://127.0.0.1:\(port)/index.json?token=t0k")!)
        XCTAssertEqual((response as! HTTPURLResponse).statusCode, 200)
        let index = try TVLibraryIndex.makeDecoder().decode(TVLibraryIndex.self, from: data)
        XCTAssertEqual(index.albumName, "Holiday")
        XCTAssertEqual(index.photos.count, 3)

        let (thumb, thumbResponse) = try await session.data(from: URL(string: "http://127.0.0.1:\(port)/\(index.photos[0].thumb)?token=t0k")!)
        XCTAssertEqual((thumbResponse as! HTTPURLResponse).statusCode, 200)
        XCTAssertEqual(Array(thumb.prefix(2)), [0xFF, 0xD8])

        vm.stopServer()
        XCTAssertEqual(vm.serverState, .stopped)
        XCTAssertNil(vm.serverURL)
    }

    func testPublishFailureSetsError() async throws {
        let blocker = workDir.appendingPathComponent("blocker")
        try Data("x".utf8).write(to: blocker)
        let vm = makeVM()
        vm.libraryPath = blocker.appendingPathComponent("lib").path
        await vm.publish(images: [], albumName: "A")
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertNil(vm.lastReport)
        XCTAssertFalse(vm.isPublishing)
    }

    func testServerStartFailureIsReported() async throws {
        let vm = makeVM()
        vm.libraryPath = workDir.path
        vm.bindHost = "203.0.113.77"
        vm.port = 0
        await vm.startServer()
        guard case .failed = vm.serverState else {
            return XCTFail("expected failure, got \(vm.serverState)")
        }
        XCTAssertFalse(vm.isServerRunning)
    }

    func testAllInterfacesURLUsesLANAddress() async throws {
        let vm = makeVM()
        vm.libraryPath = workDir.path
        vm.bindHost = ""
        vm.port = 0
        await vm.startServer()
        defer { vm.stopServer() }
        guard case .running(let port) = vm.serverState else {
            return XCTFail("server not running: \(vm.serverState)")
        }
        XCTAssertEqual(vm.serverURL, "http://192.168.1.50:\(port)")
    }
}
