import XCTest
@testable import SIV

final class AlbumTests: XCTestCase {
    var album: Album!
    
    override func setUp() {
        super.setUp()
        album = Album(name: "Test Album")
    }
    
    override func tearDown() {
        album = nil
        super.tearDown()
    }
    
    func testAddImage() {
        let imageFile = ImageFile(path: "/test/image.jpg")
        album.addImage(imageFile)
        
        XCTAssertEqual(album.images.count, 1)
        XCTAssertEqual(album.images.first?.path, "/test/image.jpg")
    }
    
    func testAddDuplicateImage() {
        let imageFile = ImageFile(path: "/test/image.jpg")
        album.addImage(imageFile)
        album.addImage(imageFile)
        
        // Should not add duplicate
        XCTAssertEqual(album.images.count, 1)
    }
    
    func testRemoveImage() {
        let imageFile1 = ImageFile(path: "/test/image1.jpg")
        let imageFile2 = ImageFile(path: "/test/image2.jpg")
        
        album.addImage(imageFile1)
        album.addImage(imageFile2)
        
        XCTAssertEqual(album.images.count, 2)
        
        album.removeImage(at: 0)
        
        XCTAssertEqual(album.images.count, 1)
        XCTAssertEqual(album.images.first?.path, "/test/image2.jpg")
    }
    
    func testRemoveImageById() {
        let imageFile = ImageFile(path: "/test/image.jpg")
        album.addImage(imageFile)
        
        XCTAssertEqual(album.images.count, 1)
        
        album.removeImage(id: imageFile.id)
        
        XCTAssertEqual(album.images.count, 0)
    }
    
    func testAlbumProperties() {
        XCTAssertEqual(album.name, "Test Album")
        XCTAssertTrue(album.images.isEmpty)
        XCTAssertNotNil(album.created)
        XCTAssertNotNil(album.modified)
    }
}
