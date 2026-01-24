import XCTest
@testable import SIV

final class ImageFileTests: XCTestCase {
    func testImageFileCreation() {
        let path = "/test/path/image.jpg"
        let imageFile = ImageFile(path: path)
        
        XCTAssertEqual(imageFile.path, path)
        XCTAssertEqual(imageFile.fileName, "image.jpg")
        XCTAssertNotNil(imageFile.id)
    }
    
    func testImageFileEquality() {
        let imageFile1 = ImageFile(path: "/test/image.jpg")
        let imageFile2 = ImageFile(path: "/test/image.jpg")
        
        // Different instances with same path should not be equal (different IDs)
        XCTAssertNotEqual(imageFile1, imageFile2)
        
        // Same instance should be equal to itself
        XCTAssertEqual(imageFile1, imageFile1)
    }
    
    func testFileName() {
        let imageFile = ImageFile(path: "/path/to/my/image.png")
        XCTAssertEqual(imageFile.fileName, "image.png")
    }
}
