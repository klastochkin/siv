import XCTest
@testable import SIV

final class ImageLoaderTests: XCTestCase {
    
    var imageLoader: ImageLoader!
    
    override func setUp() {
        super.setUp()
        imageLoader = ImageLoader()
    }
    
    override func tearDown() {
        imageLoader = nil
        super.tearDown()
    }
    
    func testLoadValidImage() async throws {
        // TODO: Implement test with test image
    }
    
    func testLoadInvalidImage() async {
        // TODO: Implement test
    }
    
    func testGetMetadata() throws {
        // TODO: Implement test
    }
}

