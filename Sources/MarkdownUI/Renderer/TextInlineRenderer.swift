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
    if self.resultComponents.count == 1,
      case .attributedString(let text)? = self.resultComponents.first,
      text.characters.prefix(8_193).count > 8_192
    {
      // 保留属性并分段绘制，避免超高的单个 SwiftUI Text 显示为空白。
      return text.displayChunks(maxCharacters: 512).map { Text($0) }
    }
    return [self.result]
  }

  private var result: Text {
    var result = Text("")
    for component in resultComponents {
      switch component {
      case .attributedString(let attributedString):
        result = result + Text(attributedString)

      case .image(let image):
        result = result + Text(image)
      }
    }

    return result
  }

  private enum ResultComponent {
    case attributedString(AttributedString)
    case image(Image)
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
