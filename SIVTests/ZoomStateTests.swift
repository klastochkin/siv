import XCTest
@testable import SIV

final class ZoomStateTests: XCTestCase {
    
    func testInitialState() {
        let zoomState = ZoomState()
        XCTAssertEqual(zoomState.scale, 1.0)
        XCTAssertEqual(zoomState.offset, .zero)
        XCTAssertEqual(zoomState.mode, .fitToWindow)
    }
    
    func testClampScale() {
        var zoomState = ZoomState()
        
        // Test minimum clamping
        zoomState.scale = 0.05
        zoomState.clampScale()
        XCTAssertEqual(zoomState.scale, ZoomState.minScale)
        
        // Test maximum clamping
        zoomState.scale = 20.0
        zoomState.clampScale()
        XCTAssertEqual(zoomState.scale, ZoomState.maxScale)
    }
    
    func testReset() {
        var zoomState = ZoomState()
        zoomState.scale = 2.0
        zoomState.offset = CGSize(width: 100, height: 100)
        zoomState.mode = .custom
        
        zoomState.reset()
        
        XCTAssertEqual(zoomState.scale, 1.0)
        XCTAssertEqual(zoomState.offset, .zero)
        XCTAssertEqual(zoomState.mode, .fitToWindow)
    }
    
    func testPercentage() {
        var zoomState = ZoomState()
        zoomState.scale = 1.5
        XCTAssertEqual(zoomState.percentage, 150)
        
        zoomState.scale = 0.25
        XCTAssertEqual(zoomState.percentage, 25)
    }
}

