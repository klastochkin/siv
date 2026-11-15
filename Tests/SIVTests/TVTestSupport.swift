import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import SIV

enum TVTestSupport {
    static func makeTempDirectory(_ name: String = "siv-tv-tests") -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url.resolvingSymlinksInPath()
    }

    static func makeImage(width: Int, height: Int, alpha: Bool = false, color: (CGFloat, CGFloat, CGFloat) = (0.8, 0.2, 0.1)) -> CGImage {
        let space = CGColorSpace(name: CGColorSpace.displayP3)!
        let info = alpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: info)!
        if alpha {
            ctx.clear(CGRect(x: 0, y: 0, width: width, height: height))
            ctx.setFillColor(CGColor(red: color.0, green: color.1, blue: color.2, alpha: 0.5))
        } else {
            ctx.setFillColor(CGColor(red: color.0, green: color.1, blue: color.2, alpha: 1))
        }
        ctx.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        ctx.setFillColor(CGColor(red: 0.1, green: 0.3, blue: 0.9, alpha: 1))
        ctx.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        return ctx.makeImage()!
    }

    /// Writes an image file with optional EXIF orientation, capture date and GPS position.
    @discardableResult
    static func writeImage(
        to url: URL,
        width: Int,
        height: Int,
        type: UTType = .jpeg,
        alpha: Bool = false,
        orientation: Int? = nil,
        dateTimeOriginal: String? = nil,
        withGPS: Bool = false
    ) -> URL {
        let image = makeImage(width: width, height: height, alpha: alpha)
        let dest = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)!
        var props: [CFString: Any] = [:]
        if let orientation { props[kCGImagePropertyOrientation] = orientation }
        if let dateTimeOriginal {
            props[kCGImagePropertyExifDictionary] = [kCGImagePropertyExifDateTimeOriginal: dateTimeOriginal]
        }
        if withGPS {
            props[kCGImagePropertyGPSDictionary] = [
                kCGImagePropertyGPSLatitude: 37.7749,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 122.4194,
                kCGImagePropertyGPSLongitudeRef: "W"
            ]
        }
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dest), "failed to write \(url.lastPathComponent)")
        return url
    }

    static func properties(of url: URL) -> [CFString: Any] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return [:] }
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
    }

    static func cgImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    static func readIndex(_ root: URL) throws -> TVLibraryIndex {
        let data = try Data(contentsOf: root.appendingPathComponent(TVLibraryIndex.fileName))
        return try TVLibraryIndex.makeDecoder().decode(TVLibraryIndex.self, from: data)
    }

    static func setModificationDate(_ date: Date, of url: URL) {
        try! FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }

    /// Sends raw bytes over TCP and returns everything the server writes before closing.
    static func rawRequest(_ bytes: Data, port: UInt16, host: String = "127.0.0.1", timeout: TimeInterval = 5) -> Data {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        precondition(fd >= 0)
        defer { close(fd) }
        var tv = timeval(tv_sec: Int(timeout), tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        inet_pton(AF_INET, host, &addr.sin_addr)
        let connected = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard connected == 0 else { return Data() }
        _ = bytes.withUnsafeBytes { send(fd, $0.baseAddress, bytes.count, 0) }
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 65536)
        while true {
            let n = recv(fd, &buffer, buffer.count, 0)
            if n <= 0 { break }
            result.append(buffer, count: n)
        }
        return result
    }

    static func statusCode(of rawResponse: Data) -> Int? {
        guard let text = String(data: rawResponse.prefix(64), encoding: .utf8) else { return nil }
        let parts = text.split(separator: " ")
        return parts.count > 1 ? Int(parts[1]) : nil
    }
}
