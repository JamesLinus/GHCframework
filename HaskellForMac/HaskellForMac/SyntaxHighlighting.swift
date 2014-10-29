//
//  SyntaxHighlighting.swift
//  HaskellForMac
//
//  Created by Manuel M T Chakravarty on 31/08/2014.
//  Copyright (c) 2014 Manuel M T Chakravarty. All rights reserved.
//
//  Syntax highlighting support.

import Foundation
import GHCKit


/// Token types distinguished during syntax highlighting.
///
public enum HighlightingTokenKind {
  case Constructor, String, Number, Keyword, LineComment, BlockComment, Other
}

/// Constants for the hardcoded theme
// FIXME: must be variable
let highlightBackgroundColour = NSColor(calibratedRed: 255/255, green: 252/255, blue: 235/255, alpha: 1)
let constructorAttributes     = [NSForegroundColorAttributeName: NSColor(calibratedRed: 180/255, green:  69/255, blue:   0/255, alpha: 1)]
let stringAttributes          = [NSForegroundColorAttributeName: NSColor(calibratedRed: 223/255, green:   7/255, blue:   0/255, alpha: 1)]
let numberAttributes          = [NSForegroundColorAttributeName: NSColor(calibratedRed:  41/255, green:  66/255, blue: 119/255, alpha: 1)]
let keywordAttributes         = [NSForegroundColorAttributeName: NSColor(calibratedRed:  41/255, green:  66/255, blue: 119/255, alpha: 1)]
let commentAttributes         = [NSForegroundColorAttributeName: NSColor(calibratedRed: 195/255, green: 116/255, blue:  28/255, alpha: 1)]

/// Theme = dictionary to look up attributes for a given token type.
///
let theme: [HighlightingTokenKind: [NSString: NSColor]] = [ .Constructor:  constructorAttributes
                                                          , .String:       stringAttributes
                                                          , .Number:       numberAttributes
                                                          , .Keyword:      keywordAttributes
                                                          , .LineComment:  commentAttributes
                                                          , .BlockComment: commentAttributes
                                                          ]

/// Tokens for syntax highlighting.
///
public struct HighlightingToken {
  public let kind: HighlightingTokenKind
  public let span: SrcSpan

  public init (ghcToken: Token) {
    switch ghcToken.kind {
    case .As:                 kind = .Keyword
    case .Case:               kind = .Keyword
    case .Class:              kind = .Keyword
    case .Data:               kind = .Keyword
    case .Default:            kind = .Keyword
    case .Deriving:           kind = .Keyword
    case .Do:                 kind = .Keyword
    case .Else:               kind = .Keyword
    case .Hiding:             kind = .Keyword
    case .If:                 kind = .Keyword
    case .Import:             kind = .Keyword
    case .In:                 kind = .Keyword
    case .Infix:              kind = .Keyword
    case .Infixl:             kind = .Keyword
    case .Infixr:             kind = .Keyword
    case .Instance:           kind = .Keyword
    case .Let:                kind = .Keyword
    case .Module:             kind = .Keyword
    case .Newtype:            kind = .Keyword
    case .Of:                 kind = .Keyword
    case .Qualified:          kind = .Keyword
    case .Then:               kind = .Keyword
    case .Type:               kind = .Keyword
    case .Where:              kind = .Keyword
    case .Forall:             kind = .Keyword
    case .Foreign:            kind = .Keyword
    case .Export:             kind = .Keyword
    case .Label:              kind = .Keyword
    case .Dynamic:            kind = .Keyword
    case .Safe:               kind = .Keyword
    case .Interruptible:      kind = .Keyword
    case .Unsafe:             kind = .Keyword
    case .Stdcallconv:        kind = .Keyword
    case .Ccallconv:          kind = .Keyword
    case .Capiconv:           kind = .Keyword
    case .Primcallconv:       kind = .Keyword
    case .Javascriptcallconv: kind = .Keyword
    case .Mdo:                kind = .Keyword
    case .Family:             kind = .Keyword
    case .Role:               kind = .Keyword
    case .Group:              kind = .Keyword
    case .By:                 kind = .Keyword
    case .Using:              kind = .Keyword
    case .Pattern:            kind = .Keyword
    case .Ctype:              kind = .Keyword

    case .Dotdot:             kind = .Keyword
    case .Colon:              kind = .Keyword
    case .Dcolon:             kind = .Keyword
    case .Equal:              kind = .Keyword
    case .Lam:                kind = .Keyword
    case .Lcase:              kind = .Keyword
    case .Vbar:               kind = .Keyword
    case .Larrow:             kind = .Keyword
    case .Rarrow:             kind = .Keyword
    case .At:                 kind = .Keyword
    case .Tilde:              kind = .Keyword
    case .Tildehsh:           kind = .Keyword
    case .Darrow:             kind = .Keyword
    case .Minus:              kind = .Keyword
    case .Bang:               kind = .Keyword
    case .Star:               kind = .Keyword
    case .Dot:                kind = .Keyword
    case .Biglam:             kind = .Keyword
    case .Ocurly:             kind = .Keyword
    case .Ccurly:             kind = .Keyword
    case .Vocurly:            kind = .Keyword
    case .Vccurly:            kind = .Keyword
    case .Obrack:             kind = .Keyword
    case .Opabrack:           kind = .Keyword
    case .Cpabrack:           kind = .Keyword
    case .Cbrack:             kind = .Keyword
    case .Oparen:             kind = .Keyword
    case .Cparen:             kind = .Keyword
    case .Oubxparen:          kind = .Keyword
    case .Cubxparen:          kind = .Keyword
    case .Semi:               kind = .Keyword
    case .Comma:              kind = .Keyword
    case .Underscore:         kind = .Keyword
    case .Backquote:          kind = .Keyword
    case .SimpleQuote:        kind = .Keyword

    case .Varsym:             kind = .Other
    case .Consym:             kind = .Constructor
    case .Varid:              kind = .Other
    case .Conid:              kind = .Constructor
    case .Qvarsym:            kind = .Other
    case .Qconsym:            kind = .Constructor
    case .Qvarid:             kind = .Other
    case .Qconid:             kind = .Constructor

    case .Integer:            kind = .Number
    case .Rational:           kind = .Number

    case .Char:               kind = .String
    case .String:             kind = .String
    case .LineComment:        kind = .LineComment
    case .BlockComment:       kind = .BlockComment
    case .Other:              kind = .Other
    }
    span = ghcToken.span
  }
}

extension HighlightingToken: Equatable {}

public func ==(lhs: HighlightingToken, rhs: HighlightingToken) -> Bool {
  return lhs.kind == rhs.kind && lhs.span == rhs.span
}

/// Map from line numbers to pairs of character index (where the line starts) and tokens on the line.
///
/// Tokens are in column order. If a token spans multiple lines, it occurs as the last token on its first line and as
/// the first (and possibly only) token on all of its subsqeuent lines.
///
public typealias LineTokenMap = StringLineMap<HighlightingToken>

/// Tokeniser functions take source language stings and turn them into tokens for highlighting.
///
// FIXME: need to have a starting location to tokenise partial programs
public typealias HighlightingTokeniser = (Line, Column, String) -> [HighlightingToken]

/// Initialise a line token map from a string.
///
public func lineTokenMap(string: String, tokeniser: HighlightingTokeniser) -> LineTokenMap {
  var lineMap: LineTokenMap = StringLineMap(string: string)
  lineMap.addLineInfo(tokensForLines(tokeniser(1, 1, string)))
  return lineMap
}

/// Compute the line assignment for an array of tokens.
///
private func tokensForLines(tokens: [HighlightingToken]) -> [(Line, HighlightingToken)] {

  // Compute the tokens for every line.
  var lineInfo: [(Line, HighlightingToken)] = []
  for token in tokens {
    for offset in 0..<token.span.lines {
      let lineToken: (Line, HighlightingToken) = (token.span.start.line + offset, token)
      lineInfo.append(lineToken)
    }
  }
  return lineInfo
}

/// For the given line range, determine how many preceeding or succeeding lines are part of multi-line tokens, and
/// hence, need to be rescanned for re-tokenisation.
///
/// The current implementation is a conservative approximation as it extends the range by the number of extra lines that
/// the token has *independent* of which lines within the multiline token is at the border of the original line range.
///
public func lineRangeRescanOffsets(lineTokenMap: LineTokenMap, lines: Range<Line>) -> (UInt, UInt) {
  if lines.isEmpty { return (0, 0) }

  let preOffset: UInt = {
    if let firstToken = lineTokenMap.infoOfLine(lines.startIndex).first {
      if firstToken.span.lines > 1 {
        return firstToken.span.lines - 1
      }
    }
    return 0
  }()
  let sucOffset: UInt = {
    if let lastToken = lineTokenMap.infoOfLine(lines.endIndex - 1).last {
      if lastToken.span.lines > 1 {
        return lastToken.span.lines - 1
      }
    }
    return 0
    }()
  return (preOffset, sucOffset)
}

/// Update the given token map by re-running the tokeniser on the given range of lines and fixing up the start indicies
/// (and the last line end index) for all rescan lines and all following lines.
///
/// PRECONDITION: This function expects that the number of lines in the old and new line token map are the *same*.
///
public func rescanTokenLines(lineMap: LineTokenMap,
                         rescanLines: Range<Line>,
                              string: String,
                           tokeniser: HighlightingTokeniser) -> LineTokenMap
{
  if rescanLines.isEmpty { return lineMap }

  var newLineMap = lineMap
  if let startIndex = lineMap.startOfLine(rescanLines.startIndex) {

      // First, fix the start indicies in the line map (for edited lines and all following lines).
    var idx = startIndex
    for line in rescanLines {                                       // fix rescan lines
      newLineMap.setStartOfLine(line, startIndex: idx)
      idx = NSMaxRange((string as NSString).lineRangeForRange(NSRange(location: idx, length: 0)))
    }
    let oldEndIndex    = lineMap.endOfLine(rescanLines.endIndex - 1)
    let newEndIndex    = idx
    let changeInLength = newEndIndex - oldEndIndex

    newLineMap.setStartOfLine(0, startIndex: string.utf16.endIndex) // special case of the end of the string

    for line in rescanLines.endIndex..<(lineMap.lastLine + 1) {     // fix all lines after the rescan lines
      newLineMap.setStartOfLine(line, startIndex: advance(lineMap.startOfLine(line)!, changeInLength))
    }

      // Second, we update the token information for all affected lines.
    let rescanString = (string as NSString).substringWithRange(toNSRange(startIndex..<newEndIndex))
    newLineMap.replaceLineInfo(rescanLines.map{ ($0, []) })       // FIXME: this and next line might be nicer combined
    newLineMap.addLineInfo(tokensForLines(tokeniser(rescanLines.startIndex, 1, rescanString)))
    return newLineMap

  } else { return lineMap }
}

/// Computes an array of tokens (and their source span) for a range of lines from a `LineTokenMap`.
///
public func tokensWithSpan(lineTokenMap: LineTokenMap)(atLine line: Line) -> [(HighlightingToken, Range<Int>)] {
  if let index = lineTokenMap.startOfLine(line) {
    let tokens = lineTokenMap.infoOfLine(line)
    return map(tokens){ token in
      let endLine = token.span.start.line + token.span.lines - 1
      let start   = line == token.span.start.line
                    ? advance(index, Int(token.span.start.column) - 1)   // token starts on this line
                    : index                                              // token started on a previous line
      let end     = line == endLine
                    ? advance(index, Int(token.span.endColumn) - 1)      // token ends on this line
                    : lineTokenMap.endOfLine(line)                       // token ends on a subsequent line
      return (token, start..<end)
    }
  } else {
    return []
  }
}

extension CodeView {

  func enableHighlighting(tokeniser: HighlightingTokeniser) {
    backgroundColor = highlightBackgroundColour
    layoutManager?.enableHighlighting(tokeniser)
  }

  func highlight(lineRange: Range<Line>) {
    if let lineMap = self.lineMap { layoutManager?.highlight(lineMap, lineRange: lineRange) }
  }

  func highlight() {
    if let lineMap = self.lineMap { layoutManager?.highlight(lineMap) }
  }
}

extension NSLayoutManager {

  func enableHighlighting(tokeniser: HighlightingTokeniser) {
    (textStorage?.delegate as? CodeStorageDelegate)?.enableHighlighting(tokeniser)
  }

  func highlight(lineTokenMap: LineTokenMap) {
    highlight(lineTokenMap, lineRange: 1..<lineTokenMap.lastLine)
  }

  func highlight(lineTokenMap: LineTokenMap, lineRange: Range<Line>) {
    if lineRange.isEmpty { return }

      // Remove any existing temporary attributes in the entire range.
    if let start = lineTokenMap.startOfLine(lineRange.startIndex) {

      let end = lineTokenMap.endOfLine(lineRange.endIndex - 1)
      setTemporaryAttributes([:], forCharacterRange: toNSRange(start..<end))

    }

      // Apply highlighting to all tokens in the affected range.
    for (token, span) in [].join(lineRange.map(tokensWithSpan(lineTokenMap))) {
      if let attributes = theme[token.kind] {
        addTemporaryAttributes(attributes, forCharacterRange: toNSRange(span))
      }
    }
  }
}