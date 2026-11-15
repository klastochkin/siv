import XCTest
@testable import SIV

final class TVCommandLineTests: XCTestCase {
    func testNonTVArgumentsLaunchGUI() throws {
        XCTAssertNil(try TVCommandLine.parse([]))
        XCTAssertNil(try TVCommandLine.parse(["-NSDocumentRevisionsDebugMode", "YES"]))
        XCTAssertNil(try TVCommandLine.parse(["/path/photo.jpg"]))
    }

    func testPublish() throws {
        XCTAssertEqual(try TVCommandLine.parse(["tv-publish", "--out", "/tmp/lib"]), .publish(album: nil, out: "/tmp/lib"))
        XCTAssertEqual(
            try TVCommandLine.parse(["tv-publish", "--album", "/a.sivalb", "--out", "/tmp/lib"]),
            .publish(album: "/a.sivalb", out: "/tmp/lib")
        )
        XCTAssertThrowsError(try TVCommandLine.parse(["tv-publish"]))
        XCTAssertThrowsError(try TVCommandLine.parse(["tv-publish", "--out"]))
        XCTAssertThrowsError(try TVCommandLine.parse(["tv-publish", "--out", "/x", "--port", "1"]))
    }

    func testServe() throws {
        XCTAssertEqual(
            try TVCommandLine.parse(["tv-serve", "--root", "/lib", "--host", "10.0.0.2", "--port", "9000", "--token", "t"]),
            .serve(root: "/lib", host: "10.0.0.2", port: 9000, token: "t")
        )
        XCTAssertEqual(
            try TVCommandLine.parse(["tv-serve", "--root", "/lib", "--host", "all"]),
            .serve(root: "/lib", host: nil, port: 8080, token: nil)
        )
        guard case .serve(_, let host, _, _)? = try TVCommandLine.parse(["tv-serve", "--root", "/lib"]) else {
            return XCTFail("expected serve")
        }
        let lan = LANAddress.ipv4Interfaces().first { LANAddress.isPrivateIPv4($0.address) }?.address
        XCTAssertEqual(host, lan, "defaults to the LAN address, never all interfaces")

        for bad in [["tv-serve"], ["tv-serve", "--root", "/l", "--port", "0"], ["tv-serve", "--root", "/l", "--port", "x"],
                    ["tv-serve", "--root", "/l", "--port", "70000"], ["tv-serve", "--root", "/l", "extra"], ["tv-nope"]] {
            XCTAssertThrowsError(try TVCommandLine.parse(bad), bad.joined(separator: " "))
        }
    }

    func testHelp() throws {
        XCTAssertEqual(try TVCommandLine.parse(["tv-help"]), .help)
        XCTAssertEqual(try TVCommandLine.parse(["tv-serve", "--help"]), .help)
    }

    func testLoadAlbumReadsSIVAlbumFormat() throws {
        let dir = TVTestSupport.makeTempDirectory("siv-tv-cli")
        defer { try? FileManager.default.removeItem(at: dir) }
        var album = Album(name: "Trip")
        album.addImage(ImageFile(path: "/x/a.jpg"))
        let url = dir.appendingPathComponent("a.sivalb")
        try JSONEncoder().encode(album).write(to: url)

        let loaded = try TVCommandLine.loadAlbum(at: url.path)
        XCTAssertEqual(loaded.name, "Trip")
        XCTAssertEqual(loaded.images.map(\.path), ["/x/a.jpg"])
        XCTAssertThrowsError(try TVCommandLine.loadAlbum(at: dir.appendingPathComponent("none.sivalb").path))
    }
}
