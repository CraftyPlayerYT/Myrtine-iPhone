import XCTest
@testable import Myrtine

final class MarkdownParserTests: XCTestCase {
    func testParsesHeadingsListsLinksAndTable() {
        let markdown = """
        # Résultat

        Un [lien](https://example.fr) officiel.

        | Organisme | Aide |
        |---|---|
        | ADEME | Fonds Chaleur |

        1. Première démarche
        - Pièce à préparer
        """

        let blocks = MarkdownParser.parse(markdown)

        XCTAssertEqual(blocks[0], .heading(1, "Résultat"))
        XCTAssertTrue(blocks.contains(.table(["Organisme", "Aide"], [["ADEME", "Fonds Chaleur"]])))
        XCTAssertTrue(blocks.contains(.numbered(1, "Première démarche")))
        XCTAssertTrue(blocks.contains(.bullet("Pièce à préparer")))
    }

    func testDoesNotTreatOrdinaryPipeAsTable() {
        XCTAssertEqual(MarkdownParser.parse("Valeur A | Valeur B"), [.paragraph("Valeur A | Valeur B")])
    }

    func testTableUsesWiderColumnsForLongDiagnosticContent() {
        XCTAssertEqual(MarkdownTableLayout.width(for: "Critères à respecter"), 300)
        XCTAssertEqual(MarkdownTableLayout.width(for: "Lien vers le cahier des charges"), 240)
        XCTAssertEqual(MarkdownTableLayout.width(for: "Organisme financeur"), 180)
    }

    func testMailRendererExtractsBodyAndResolvesInlineImages() {
        let attachment = MailAttachmentPayload(
            fileName: "preuve.png",
            contentType: "image/png",
            base64Content: "iVBORw0KGgo=",
            isInline: true,
            contentID: "image-1"
        )
        let result = MailHTMLRenderer.prepare(
            "<html><head><title>Test</title></head><body><strong>Bonjour</strong><img src=\"cid:image-1\"><script>alert(1)</script></body></html>",
            attachments: [attachment]
        )

        XCTAssertTrue(result.contains("<strong>Bonjour</strong>"))
        XCTAssertTrue(result.contains("data:image/png;base64,iVBORw0KGgo="))
        XCTAssertFalse(result.contains("<html>"))
        XCTAssertFalse(result.contains("<script"))
    }
}
