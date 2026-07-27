import XCTest
@testable import Myrtine

final class ImageValidatorTests: XCTestCase {
    func testAcceptsPNGSignature() {
        let data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        XCTAssertTrue(ImageValidator.isAllowed(data: data, fileName: "preuve.png", contentType: "image/png"))
    }

    func testRejectsRenamedExecutable() {
        let data = Data("MZ executable".utf8)
        XCTAssertFalse(ImageValidator.isAllowed(data: data, fileName: "preuve.png", contentType: "image/png"))
    }

    func testRejectsSVGContainingScript() {
        let data = Data("<svg><script>alert(1)</script></svg>".utf8)
        XCTAssertFalse(ImageValidator.isAllowed(data: data, fileName: "preuve.svg", contentType: "image/svg+xml"))
    }
}
