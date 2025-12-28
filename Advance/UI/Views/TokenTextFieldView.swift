//
//  TokenTextFieldView.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/26/25.
//

import SwiftUI

class TokenTextFieldDelegate: NSObject, NSTokenFieldDelegate {
  let representable: TokenTextFieldView

  init(representable: TokenTextFieldView) {
    self.representable = representable
  }

  func tokenField(_ tokenField: NSTokenField, displayStringForRepresentedObject representedObject: Any) -> String? {
    let token = representedObject as! String

    return representable.tokenLabel(token)
  }

  func tokenField(
    _ tokenField: NSTokenField,
    styleForRepresentedObject representedObject: Any,
  ) -> NSTokenField.TokenStyle {
    let token = representedObject as! String

    return representable.tokenStyle(token)
  }

  // While this method allows us to provide a represented object in place of the editing string, I found that, in
  // practice, one of the following would happen:
  //
  //   1. The token field would hang on focus restoration (i.e., after inserting text, leaving and entering the field
  //      would could the issue).
  //   2. The runtime would crash when using Unmanaged.
  //
  // It's not difficult to operate on strings, but they make the intent of our code more difficult to parse.
  func tokenField(_ tokenField: NSTokenField, representedObjectForEditing editingString: String) -> Any? {
    // We don't want whitespace trimming behavior.
    editingString
  }

  func tokenField(_ tokenField: NSTokenField, shouldAdd tokens: [Any], at index: Int) -> [Any] {
    let tokens = tokens as! [String]
    let results = tokens.flatMap { representable.tokenizer($0) }

    return results
  }

  func tokenField(_ tokenField: NSTokenField, writeRepresentedObjects objects: [Any], to pboard: NSPasteboard) -> Bool {
    let tokens = objects as! [String]
    let s = representable.detokenizer(tokens)
    // Do we need to prepare the pasteboard?
    pboard.writeObjects([s as NSString])

    return true
  }

  func controlTextDidChange(_ obj: Notification) {
    let textField = obj.object as! NSTextField
    let tokens = textField.objectValue as! [String]

    representable.tokens = tokens
  }
}

struct TokenTextFieldCoordinator {
  let delegate: TokenTextFieldDelegate
}

struct TokenTextFieldView: NSViewRepresentable {
  @Binding var tokens: [String]
  let prompt: String
  let tokenizer: (String) -> [String]
  let detokenizer: ([String]) -> String
  let tokenLabel: (String) -> String
  let tokenStyle: (String) -> NSTokenField.TokenStyle

  func makeNSView(context: Context) -> NSTokenField {
    // TODO: Figure out how to configure NSResponder/validateProposedFirstResponder(_:for:) for the enclosing NSTableView.
    let tokenField = NSTokenField()
    tokenField.tokenizingCharacterSet = CharacterSet()
    tokenField.usesSingleLineMode = true
    tokenField.isBezeled = false
    tokenField.lineBreakMode = .byTruncatingTail
    tokenField.focusRingType = .none
    tokenField.delegate = context.coordinator.delegate
    tokenField.drawsBackground = context.environment.isFocused
    tokenField.placeholderString = prompt
    tokenField.objectValue = tokens

    return tokenField
  }

  func updateNSView(_ tokenField: NSTokenField, context: Context) {
    tokenField.drawsBackground = context.environment.isFocused
    tokenField.placeholderString = prompt
    tokenField.objectValue = tokens
  }

  func makeCoordinator() -> TokenTextFieldCoordinator {
    TokenTextFieldCoordinator(delegate: TokenTextFieldDelegate(representable: self))
  }
}
