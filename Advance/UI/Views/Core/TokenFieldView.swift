//
//  TokenFieldView.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/30/24.
//

import DequeModule
import OSLog
import SwiftUI

struct TokenFieldView: NSViewRepresentable {
  let prompt: String?
  let isBezeled: Bool
  @Binding var tokens: [String]
  let enclosing: Character
  let isKeyword: (String) -> Bool
  let keywordTitle: (String) -> String

  init(
    prompt: String?,
    isBezeled: Bool,
    tokens: Binding<[String]>,
    enclosing: Character,
    isKeyword: @escaping (String) -> Bool,
    title keywordTitle: @escaping (String) -> String
  ) {
    self.prompt = prompt
    self.isBezeled = isBezeled
    self._tokens = tokens
    self.enclosing = enclosing
    self.isKeyword = isKeyword
    self.keywordTitle = keywordTitle
  }

  func makeNSView(context: Context) -> NSTokenField {
    let tokenField = NSTokenField()
    tokenField.delegate = context.coordinator.delegate
    // The set of tokens is determined by the instantiator of this view, and not the user in the token field.
    tokenField.tokenizingCharacterSet = CharacterSet()
    tokenField.isBezeled = isBezeled
    // Setting drawsBackground to false still draws a background on focus. This explicitly draws nothing.
    tokenField.drawsBackground = true
    tokenField.backgroundColor = nil
    // When the field has several tokens in a row, the field may get truncated. Truncating the head results in an odd
    // behavior where it shifts the remaining contents in the field.
    tokenField.usesSingleLineMode = true

    update(tokenField, context: context)

    return tokenField
  }

  func updateNSView(_ tokenField: NSTokenField, context: Context) {
    context.coordinator.delegate.representable = self

    update(tokenField, context: context)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(delegate: Delegate(representable: self))
  }

  func update(_ tokenField: NSTokenField, context: Context) {
    tokenField.objectValue = tokens
    tokenField.placeholderString = prompt

    if let mode = NSLineBreakMode(context.environment.truncationMode) {
      tokenField.lineBreakMode = mode
    }

    tokenField.focusRingType = context.environment.isFocusEffectEnabled ? .default : .none
  }

  nonisolated static func parse(token: String, enclosing: Character) -> [String] {
    var iterator = token.makeIterator()
    var tokens = [String]()
    var token = ""

    outer:
    while true {
      while true {
        guard let c = iterator.next() else {
          break outer
        }

        if c == enclosing {
          tokens.append(token)

          token = String(c)

          break
        }

        token.append(c)
      }

      while true {
        guard let c = iterator.next() else {
          break outer
        }

        token.append(c)

        if c == enclosing {
          tokens.append(token)

          break
        }
      }

      token = ""
    }

    tokens.append(token)

    return tokens
  }

  nonisolated static func string(tokens: [String]) -> String {
    tokens.joined()
  }

  nonisolated static func enclose(
    _ string: some CustomStringConvertible,
    with enclosing: some CustomStringConvertible,
  ) -> String {
    "\(enclosing)\(string)\(enclosing)"
  }

  struct Coordinator {
    let delegate: Delegate

    init(delegate: Delegate) {
      self.delegate = delegate
    }
  }

  class Delegate: NSObject, NSTokenFieldDelegate {
    var representable: TokenFieldView

    init(representable: TokenFieldView) {
      self.representable = representable
    }

    func tokenField(_ tokenField: NSTokenField, displayStringForRepresentedObject representedObject: Any) -> String? {
      let token = representedObject as! String

      guard representable.isKeyword(token) else {
        return token
      }

      return representable.keywordTitle(token)
    }

    func tokenField(_ tokenField: NSTokenField, styleForRepresentedObject representedObject: Any) -> NSTokenField.TokenStyle {
      let token = representedObject as! String

      guard representable.isKeyword(token) else {
        return .none
      }

      return .rounded
    }

    // While this method allows us to provide a represented object in place of an editing string, in practice, when I
    // tried to use it, one of the following would occur:
    //
    // - The token field would hang on focus restoration (that is, after inserting text, leaving and entering the field
    // would cause the issue)
    // - The runtime would crash working with Unmanaged types.
    //
    // It's not difficult to operate on strings; but they make the intent of the code more difficult to parse.
    func tokenField(_ tokenField: NSTokenField, representedObjectForEditing editingString: String) -> Any? {
      // We don't want whitespace trimming behavior.
      editingString
    }
    
    func tokenField(_ tokenField: NSTokenField, shouldAdd tokens: [Any], at index: Int) -> [Any] {
      let tokens = tokens as! [String]

      return tokens.flatMap { token -> [String] in
        TokenFieldView.parse(token: token, enclosing: representable.enclosing)
      }
    }

    func tokenField(_ tokenField: NSTokenField, writeRepresentedObjects objects: [Any], to pasteboard: NSPasteboard) -> Bool {
      let tokens = objects as! [String]
      let s = TokenFieldView.string(tokens: tokens)

      // Do we need to prepare the pasteboard?
      pasteboard.writeObjects([s as NSString])

      return true
    }

    func controlTextDidChange(_ notification: Notification) {
      let tokenField = notification.object as! NSTokenField
      let tokens = tokenField.objectValue as! [String]

      representable.tokens = tokens
    }
  }
}

@MainActor
struct TokenFieldProxy {
  private let view: NSView!
  private var tokenField: NSTokenField? {
    var descendants = Deque(view.subviews)

    while let descendant = descendants.popFirst() {
      guard let overlayView = descendant as? NSTokenField else {
        descendants.append(contentsOf: descendant.subviews)

        continue
      }

      return overlayView
    }

    return nil
  }

  init(_ view: NSView!) {
    self.view = view
  }

  func insert(token: String, enclosing: Character) {
    guard let tokenField else {
      return
    }

    let tokens = tokenField.objectValue as! [String]
    let string = TokenFieldView.string(tokens: tokens)
    let s: String

    if let textView = tokenField.currentEditor() as? NSTextView {
      let range = textView.selectedRange()

      // TODO: Position cursor after inserted token
      //
      // For some reason, incrementing the location subsequently and inserting token causes this to insert in the
      // current token. A partial solution would be to operate the replace range on tokens, so as to simply "jump over"
      // keywords.

      if let r = Range(range, in: string) {
        s = string.replacingCharacters(in: r, with: token)
      } else {
        s = string.appending(token)
      }

      textView.selectedRanges = [NSValue(range: NSRange(location: range.location, length: 0))]
    } else {
      s = string.appending(token)
    }

    tokenField.objectValue = TokenFieldView.parse(token: s, enclosing: enclosing)

    NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: tokenField)
  }
}

struct TokenFieldReaderView<Content>: NSViewRepresentable where Content: View {
  typealias NSViewType = NSHostingView<Content>

  let content: (TokenFieldProxy) -> Content

  func makeNSView(context: Context) -> NSViewType {
    NSHostingView(rootView: content(TokenFieldProxy(nil)))
  }

  func updateNSView(_ hostingView: NSViewType, context: Context) {
    hostingView.rootView = content(TokenFieldProxy(hostingView))
  }
}
