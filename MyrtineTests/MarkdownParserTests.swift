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
}
