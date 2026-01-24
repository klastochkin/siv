import XCTest
@testable import SIV

final class ZoomStateTests: XCTestCase {
    var zoomState: ZoomState!
    
    override func setUp() {
        super.setUp()
        zoomState = ZoomState()
        zoomState.imageSize = CGSize(width: 1000, height: 800)
        zoomState.viewSize = CGSize(width: 500, height: 400)
    }
    
    override func tearDown() {
        zoomState = nil
        super.tearDown()
    }
    
    func testFitToWindow() {
        zoomState.fitToWindow()
        
        // Should scale to fit
        XCTAssertEqual(zoomState.scale, 0.5, accuracy: 0.01)
        XCTAssertEqual(zoomState.offset, .zero)
    }
    
    func testActualSize() {
        zoomState.fitToWindow()
        zoomState.actualSize()
        
        XCTAssertEqual(zoomState.scale, 1.0)
        XCTAssertEqual(zoomState.offset, .zero)
    }
    
    func testZoomIn() {
        zoomState.scale = 1.0
        zoomState.zoomIn()
        
        XCTAssertEqual(zoomState.scale, 1.25, accuracy: 0.01)
    }
    
    func testZoomOut() {
        zoomState.scale = 1.0
        zoomState.zoomOut()
        
        XCTAssertEqual(zoomState.scale, 0.8, accuracy: 0.01)
    }
    
    func testZoomLimits() {
        // Test max zoom
        zoomState.scale = ZoomState.maxZoom
        zoomState.zoomIn()
        XCTAssertEqual(zoomState.scale, ZoomState.maxZoom)
        
        // Test min zoom
        zoomState.scale = ZoomState.minZoom
        zoomState.zoomOut()
        XCTAssertEqual(zoomState.scale, ZoomState.minZoom)
    }
    
    func testCanPan() {
        // Image smaller than view - should not pan
        zoomState.scale = 0.1
        XCTAssertFalse(zoomState.canPan)
        
        // Image larger than view - should pan
        zoomState.scale = 2.0
        XCTAssertTrue(zoomState.canPan)
    }
    
    func testPanDirections() {
        zoomState.scale = 2.0
        
        zoomState.panRight()
        XCTAssertEqual(zoomState.offset.width, -ZoomState.panStep)
        
        zoomState.offset = .zero
        zoomState.panLeft()
        XCTAssertEqual(zoomState.offset.width, ZoomState.panStep)
        
        zoomState.offset = .zero
        zoomState.panDown()
        XCTAssertEqual(zoomState.offset.height, -ZoomState.panStep)
        
        zoomState.offset = .zero
        zoomState.panUp()
        XCTAssertEqual(zoomState.offset.height, ZoomState.panStep)
    }
    
    func testZoomPercentage() {
        zoomState.scale = 1.5
        XCTAssertEqual(zoomState.zoomPercentage, 150)
        
        zoomState.scale = 0.5
        XCTAssertEqual(zoomState.zoomPercentage, 50)
    }
}
