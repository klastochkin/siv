import XCTest
@testable import SIV

/// Runs `scripts/tv_api_test.py` against a real exported library served by `TVServer`.
final class TVAPIContractTests: XCTestCase {
    private var work: URL!
    private var library: URL!
    private var server: TVServer?

    private static let script = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("scripts/tv_api_test.py")

    override func setUpWithError() throws {
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/env"),
              run(["python3", "--version"]).status == 0 else {
            throw XCTSkip("python3 not available")
        }
        work = TVTestSupport.makeTempDirectory("siv-tv-contract")
        library = work.appendingPathComponent("library")
        let src = work.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        let images = [
            TVTestSupport.writeImage(to: src.appendingPathComponent("land.jpg"), width: 1200, height: 800, dateTimeOriginal: "2024:06:01 15:22:00", withGPS: true),
            TVTestSupport.writeImage(to: src.appendingPathComponent("port.jpg"), width: 900, height: 600, orientation: 6),
            TVTestSupport.writeImage(to: src.appendingPathComponent("alpha.png"), width: 300, height: 300, type: .png, alpha: true)
        ].map { ImageFile(path: $0.path) }
        try TVExportService.export(images: images, albumName: "Contract", to: library)
    }

    override func tearDown() {
        server?.stop()
        if let work { try? FileManager.default.removeItem(at: work) }
        super.tearDown()
    }

    private func serve(token: String? = nil) async throws -> String {
        let server = TVServer(configuration: .init(root: library, host: "127.0.0.1", port: 0, token: token))
        self.server = server
        let port = try await server.start()
        return "http://127.0.0.1:\(port)"
    }

    @discardableResult
    private func run(_ args: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return (-1, "\(error)") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    private func contract(_ url: String, _ extra: [String] = []) -> (status: Int32, output: String) {
        run(["python3", Self.script.path, "--url", url, "--all"] + extra)
    }

    func testContractPassesAgainstExportedLibrary() async throws {
        let url = try await serve()
        let result = contract(url, ["--min-photos", "3"])
        XCTAssertEqual(result.status, 0, result.output)
        XCTAssertTrue(result.output.contains(" 0 failed"), result.output)
    }

    func testContractPassesWithToken() async throws {
        let url = try await serve(token: "contract-token")
        let result = contract(url, ["--token", "contract-token", "--min-photos", "3"])
        XCTAssertEqual(result.status, 0, result.output)
        XCTAssertTrue(result.output.contains(" 0 failed"), result.output)
    }

    func testContractFailsWithoutTokenWhenServerRequiresOne() async throws {
        let url = try await serve(token: "contract-token")
        let result = contract(url)
        XCTAssertNotEqual(result.status, 0)
        XCTAssertTrue(result.output.contains("GET /index.json -> 200"), result.output)
    }

    func testContractDetectsBrokenIndex() async throws {
        var index = try TVTestSupport.readIndex(library)
        index.photos[0].width += 1
        index.photos[1].full = "../outside.jpg"
        index.photos[2].thumb = "thumbs/does-not-exist.jpg"
        try TVLibraryIndex.makeEncoder().encode(index).write(to: library.appendingPathComponent("index.json"))

        let url = try await serve()
        let result = contract(url)
        XCTAssertNotEqual(result.status, 0, result.output)
        XCTAssertTrue(result.output.contains("dimensions match index"), result.output)
        XCTAssertTrue(result.output.contains("safe relative path"), result.output)
        XCTAssertTrue(result.output.contains("does-not-exist.jpg -> 200"), result.output)
    }

    func testContractFailsWhenServerUnreachable() async throws {
        let url = try await serve()
        server?.stop()
        try await Task.sleep(nanoseconds: 200_000_000)
        let result = contract(url, ["--timeout", "2"])
        XCTAssertNotEqual(result.status, 0)
        XCTAssertTrue(result.output.contains("server reachable"), result.output)
    }
}
