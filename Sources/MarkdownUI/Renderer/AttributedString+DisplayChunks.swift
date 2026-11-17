import Foundation

extension AttributedString {
  func displayChunks(maxCharacters: Int) -> [AttributedString] {
    let characters = self.characters
    var start = characters.startIndex
    var index = start
    var count = 0
    var whitespace: (end: AttributedString.Index, count: Int)?
    var chunks: [AttributedString] = []

    while index != characters.endIndex {
      let character = characters[index]
      characters.formIndex(after: &index)
      count += 1
      if character.isWhitespace {
        whitespace = (index, count)
      }
      if count == maxCharacters, index != characters.endIndex {
        let boundary = whitespace ?? (index, count)
        chunks.append(AttributedString(self[start..<boundary.end]))
        start = boundary.end
        count -= boundary.count
        whitespace = nil
      }
    }

    chunks.append(AttributedString(self[start..<characters.endIndex]))
    return chunks
  }
}
