import SwiftUI

extension Sequence where Element == InlineNode {
  func renderTextChunks(
    baseURL: URL?,
    textStyles: InlineTextStyles,
    images: [String: Image],
    softBreakMode: SoftBreak.Mode,
    attributes: AttributeContainer
  ) -> [Text] {
    var renderer = TextInlineRenderer(
      baseURL: baseURL,
      textStyles: textStyles,
      images: images,
      softBreakMode: softBreakMode,
      attributes: attributes
    )
    renderer.render(self)
    return renderer.textChunks
  }
}

private struct TextInlineRenderer {
  var textChunks: [Text] {
    let totalLength = resultComponents.reduce(0) { $0 + $1.length }
    guard totalLength > 8_192 else {
      return [resultComponents.reduce(Text("")) { $0 + $1.text }]
    }

    // 对整个段落维持分段预算，避免图片加载后把同段文本重新拼成超高的 Text。
    let chunkSize = 512
    var chunks: [Text] = []
    var current = Text("")
    var currentLength = 0

    func append(_ part: Text, length: Int) {
      if currentLength + length > chunkSize {
        chunks.append(current)
        current = Text("")
        currentLength = 0
      }
      current = current + part
      currentLength += length
    }

    for component in resultComponents {
      switch component {
      case .attributedString(let text):
        for segment in text.displayChunks(maxCharacters: chunkSize) {
          append(Text(segment), length: segment.characters.count)
        }
      case .image(let image):
        append(Text(image), length: 1)
      }
    }
    chunks.append(current)
    return chunks
  }

  private enum ResultComponent {
    case attributedString(AttributedString)
    case image(Image)

    var length: Int {
      switch self {
      case .attributedString(let text): return text.characters.count
      case .image: return 1
      }
    }

    var text: Text {
      switch self {
      case .attributedString(let text): return Text(text)
      case .image(let image): return Text(image)
      }
    }
  }

  private var resultComponents: [ResultComponent] = []

  private let baseURL: URL?
  private let textStyles: InlineTextStyles
  private let images: [String: Image]
  private let softBreakMode: SoftBreak.Mode
  private let attributes: AttributeContainer
  private var shouldSkipNextWhitespace = false

  init(
    baseURL: URL?,
    textStyles: InlineTextStyles,
    images: [String: Image],
    softBreakMode: SoftBreak.Mode,
    attributes: AttributeContainer
  ) {
    self.baseURL = baseURL
    self.textStyles = textStyles
    self.images = images
    self.softBreakMode = softBreakMode
    self.attributes = attributes
  }

  mutating func render<S: Sequence>(_ inlines: S) where S.Element == InlineNode {
    for inline in inlines {
      self.render(inline)
    }
  }

  private mutating func render(_ inline: InlineNode) {
    switch inline {
    case .text(let content):
      self.renderText(content)
    case .softBreak:
      self.renderSoftBreak()
    case .html(let content):
      self.renderHTML(content)
    case .image(let source, _):
      self.renderImage(source)
    default:
      self.defaultRender(inline)
    }
  }

  private mutating func renderText(_ text: String) {
    var text = text

    if self.shouldSkipNextWhitespace {
      self.shouldSkipNextWhitespace = false
      text = text.replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
    }

    self.defaultRender(.text(text))
  }

  private mutating func renderSoftBreak() {
    switch self.softBreakMode {
    case .space where self.shouldSkipNextWhitespace:
      self.shouldSkipNextWhitespace = false
    case .space:
      self.defaultRender(.softBreak)
    case .lineBreak:
      self.shouldSkipNextWhitespace = true
      self.defaultRender(.lineBreak)
    }
  }

  private mutating func renderHTML(_ html: String) {
    let tag = HTMLTag(html)

    switch tag?.name.lowercased() {
    case "br":
      self.defaultRender(.lineBreak)
      self.shouldSkipNextWhitespace = true
    default:
      self.defaultRender(.html(html))
    }
  }

  private mutating func renderImage(_ source: String) {
    if let image = self.images[source] {
      self.resultComponents.append(.image(image))
    }
  }

  private mutating func defaultRender(_ inline: InlineNode) {
    let renderedInline = inline.renderAttributedString(
      baseURL: self.baseURL,
      textStyles: self.textStyles,
      softBreakMode: self.softBreakMode,
      attributes: self.attributes
    )

    if case let .attributedString(attributedString) = self.resultComponents.last {
      let newAttributedString = attributedString + renderedInline
      self.resultComponents.removeLast()
      self.resultComponents.append(.attributedString(newAttributedString))
    } else {
      self.resultComponents.append(.attributedString(renderedInline))
    }
  }
}
