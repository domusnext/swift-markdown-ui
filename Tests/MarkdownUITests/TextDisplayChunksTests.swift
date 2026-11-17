import Foundation
import SwiftUI
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

  func testLoadedInlineImageDoesNotDisableLongTextChunking() {
    let longText = String(repeating: "word ", count: 2_000)
    let chunks = render([.text(longText), .image(source: "example", children: []), .text("after")])

    XCTAssertGreaterThan(chunks.count, 1)
  }

  func testChunkingUsesTotalLengthAcrossInlineImages() {
    let text = String(repeating: "word ", count: 1_000)
    let image = InlineNode.image(source: "example", children: [])

    XCTAssertGreaterThan(render([.text(text), image, .text(text)]).count, 1)
    XCTAssertEqual(render([.text("before"), image, .text("after")]).count, 1)
  }

  func testChunkingBoundsDenseSequencesOfInlineImages() {
    let inlinePair: [InlineNode] = [.text("x"), .image(source: "example", children: [])]
    let nodes = Array(repeating: inlinePair, count: 3_500).flatMap { $0 }

    XCTAssertGreaterThan(render(nodes).count, 1)
  }

  private func render(_ nodes: [InlineNode]) -> [Text] {
    let theme = Theme.basic
    return nodes.renderTextChunks(
      baseURL: nil,
      textStyles: .init(
        code: theme.code, emphasis: theme.emphasis, strong: theme.strong,
        strikethrough: theme.strikethrough, link: theme.link
      ),
      images: ["example": Image(systemName: "star")],
      softBreakMode: .space,
      attributes: .init()
    )

  }
}
