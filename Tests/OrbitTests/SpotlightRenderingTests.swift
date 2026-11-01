import XCTest
import AppKit
@testable import Orbit

final class SpotlightRenderingTests: XCTestCase {
    func testSpotlightIsClearAndBackdropHasRequestedOpacity() async {
        await MainActor.run {
            let image = render(center: CGPoint(x: 200, y: 150))
            XCTAssertEqual(image.colorAt(x: 200, y: 150)!.alphaComponent, 0, accuracy: 0.01)
            XCTAssertEqual(image.colorAt(x: 10, y: 10)!.alphaComponent, 0.6, accuracy: 0.01)
        }
    }

    func testSpotlightCanStraddleAnAdjacentDisplayEdge() async {
        await MainActor.run {
            let image = render(center: CGPoint(x: -10, y: 150))
            XCTAssertEqual(image.colorAt(x: 10, y: 150)!.alphaComponent, 0, accuracy: 0.01)
            XCTAssertEqual(image.colorAt(x: 300, y: 150)!.alphaComponent, 0.6, accuracy: 0.01)
        }
    }

    @MainActor
    private func render(center: CGPoint) -> NSBitmapImageRep {
        let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 400, pixelsHigh: 300, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: image)!
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        let view = SpotlightView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        view.center = center
        view.radius = 100
        view.dimming = 0.6
        context.cgContext.clear(view.bounds)
        view.draw(view.bounds)
        context.flushGraphics()
        return image
    }
}
