import Foundation
import XCTest

@testable import MarkdownUI

final class TextDisplayChunksTests: XCTestCase {
  func testChunksPreserveAttributesAndPreferWhitespace() {
    var link = AttributedString("bravo")
    link.link = URL(string: "https://example.com")
    let text = AttributedString("alpha ") + link + AttributedString(" charlie")

    let chunks = text.displayChunks(maxCharacters: 8)

    XCTAssertEqual(chunks.map { String($0.characters) }, ["alpha ", "bravo ", "charlie"])
    XCTAssertEqual(chunks.reduce(AttributedString(), +), text)
  }

  func testChunksKeepExtendedGraphemeClustersIntact() {
    let text = AttributedString("👩🏽‍🍳👨‍👩‍👧‍👦e\u{301}桌")

    let chunks = text.displayChunks(maxCharacters: 2)

    XCTAssertEqual(chunks.map(\.characters.count), [2, 2])
    XCTAssertEqual(chunks.reduce(AttributedString(), +), text)
  }
}
