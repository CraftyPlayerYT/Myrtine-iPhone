import XCTest
import UIKit
@testable import Myrtine

final class RichTextHTMLSerializerTests: XCTestCase {
    func testSerializesFormattingAsHTMLInsteadOfVisibleTags() {
        let value = NSMutableAttributedString(string: "Texte important", attributes: [.font: UIFont.systemFont(ofSize: 17)])
        value.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 17), range: NSRange(location: 6, length: 9))
        value.addAttribute(.backgroundColor, value: UIColor.systemYellow, range: NSRange(location: 6, length: 9))

        let html = RichTextHTMLSerializer.serialize(value, inlineAttachments: [])

        XCTAssertTrue(html.contains("<strong>"))
        XCTAssertTrue(html.contains("important"))
        XCTAssertTrue(html.contains("background-color:#"))
        XCTAssertFalse(value.string.contains("<strong>"))
    }
}
