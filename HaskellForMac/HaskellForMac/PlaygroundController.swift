//
//  PlaygroundController.swift
//  HaskellForMac
//
//  Created by Manuel M T Chakravarty on 31/07/2014.
//  Copyright (c) 2014 Manuel M T Chakravarty. All rights reserved.
//
//  A single playground instance is always associated with one context, usually a Haskell module. It never changes its
//  context. A new context implies the creation of a new playground.

import Cocoa
import GHCKit


private let kPlaygroundSource = "<playground>"

class PlaygroundController: NSViewController {

  // Views in 'Playground.xib'
  //
  @IBOutlet private weak var splitView:        NSSplitView!
  @IBOutlet private weak var codeScrollView:   SynchroScrollView!
  @IBOutlet private weak var resultScrollView: SynchroScrollView!
  @IBOutlet private      var codeTextView:     CodeView!
  @IBOutlet private weak var resultTableView:  NSTableView!

  /// We need to keep the code storage delegate alive as the delegate reference from `NSTextStorage` is unowned.
  ///
  var codeStorageDelegate: CodeStorageDelegate!

  /// We need to keep the result storage alive as the data source reference from `NSTableView` is weak.
  ///
  var resultStorage: PlaygroundResultStorage!

  /// The GHC session associated with this playground.
  ///
  /// NB: We need to use an implcit optional as we can only initialise after calling `super.init` in `init` (as we need
  ///     to capture `self`).
  private let haskellSession: HaskellSession!

  /// The text attributes to be applied to all text in the code text views. (Currently, they are fixed.)
  ///
  private let codeTextAttributes: NSDictionary = {
    let menlo13 = NSFont(name: "Menlo-Regular", size:13)!
    return [NSFontAttributeName: menlo13]
  }()

//  /// The text attributes to be applied to all text in the result text views. (Currently, they are fixed.)
//  ///
//  private let resultTextAttributes: NSDictionary = {
//    let menlo13        = NSFont(name: "Menlo-Regular", size:13)!
//    let paragraphStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as NSMutableParagraphStyle
//    paragraphStyle.lineBreakMode = .ByTruncatingTail
//    return [NSFontAttributeName: menlo13, NSParagraphStyleAttributeName: paragraphStyle]
//  }()

  private let fontHeight: CGFloat = {
    let x = NSAttributedString(string: "X", attributes: [NSFontAttributeName: NSFont(name: "Menlo-Regular", size:13)!])
    return x.size.height
  }()

  /// Bin to collext issues for this playground
  ///
  private var issues = IssuesForFile(file: kPlaygroundSource, issues: [:])


  //MARK: -
  //MARK: Initialisation and deinitialisation

  init?(
    nibName:              String!,
    bundle:               NSBundle!,
    projectViewModelItem: HFMProjectViewModelItem!,
    diagnosticsHandler:   Issue -> Void)
  {
      // Call the designated initialiser.
    super.init(nibName: nibName, bundle: bundle)

      // Launch a GHC session for this playground.
    haskellSession = HaskellSession(diagnosticsHandler: processIssue(diagnosticsHandler))
  }

  required init?(coder: NSCoder) {
    haskellSession = HaskellSession(diagnosticsHandler: {severity, filename, line, column, lines, endColumn, message in })
    super.init(coder: coder)
  }

  deinit {
    codeScrollView.stopSynchronising()
  }

  override func awakeFromNib() {

      // Synchronise the scroll views.
    codeScrollView.setSynchronisedScrollView(resultScrollView)
    resultScrollView.setSynchronisedScrollView(codeScrollView)

      // Set up the gutter.
    codeScrollView.hasVerticalRuler = true
    codeScrollView.rulersVisible    = true

      // The size of the playground text views is fixed. We want them to be rigid.
    codeTextView.horizontallyResizable   = true

      // For now, we have got a fixed font.
    codeTextView.font   = codeTextAttributes[NSFontAttributeName] as? NSFont
//    resultTextView.font = resultTextAttributes[NSFontAttributeName] as? NSFont

      // Set up for code editing (not prose).
    codeTextView.automaticDashSubstitutionEnabled   = false
    codeTextView.automaticDataDetectionEnabled      = false
    codeTextView.automaticLinkDetectionEnabled      = false
    codeTextView.automaticQuoteSubstitutionEnabled  = false
    codeTextView.automaticSpellingCorrectionEnabled = false
    codeTextView.automaticTextReplacementEnabled    = false

      // FIXME: How can we do that in a locale-independent way.
    var contextMenu = NSTextView.defaultMenu()
    if let item = contextMenu?.itemWithTitle("Spelling and Grammar") { contextMenu?.removeItem(item) }
    if let item = contextMenu?.itemWithTitle("Substitutions")        { contextMenu?.removeItem(item) }
    if let item = contextMenu?.itemWithTitle("Layout Orientation")   { contextMenu?.removeItem(item) }
    codeTextView.menu = contextMenu

      // Apply the default style.
    codeTextView.typingAttributes = codeTextAttributes
//    resultTextView.defaultParagraphStyle = resultTextAttributes[NSParagraphStyleAttributeName] as? NSParagraphStyle
//    resultTextView.typingAttributes      = resultTextAttributes

      // Set up the delegate for the text storage.
    if let textStorage = codeTextView.layoutManager?.textStorage {
      codeStorageDelegate  = CodeStorageDelegate(textStorage: textStorage)
      textStorage.delegate = codeStorageDelegate
    }

      // Set up the delegate and data source for the result view.
    resultTableView.setDelegate(self)
    resultStorage = PlaygroundResultStorage()
    resultTableView.setDataSource(resultStorage)

      // Enable highlighting.
    codeTextView.enableHighlighting(tokeniseHaskell(kPlaygroundSource))
    if let backgroundColour = codeTextView.backgroundColor.shadowWithLevel(0.05) {
      resultTableView.backgroundColor = backgroundColour
    }
  }


  //MARK: -
  //MARK: Context module management

  /// Load a new version of the context module.
  ///
  func loadContextModuleIntoPlayground(moduleText: String!, file: String, importPaths: [String]) -> Bool {

      // Load the module text into GHC.
    return haskellSession.loadModuleFromString(moduleText, file: file, importPaths: importPaths)
  }


  //MARK: -
  //MARK: Processing diagnostics

  /// Load a new version of the context module.
  ///
  private func processIssue(contextDiagnosticsHandler: Issue -> Void) -> DiagnosticsHandler {
    return {[weak self] severity, filename, line, column, lines, endColumn, message
    in
    let issue = Issue(severity: severity,
                      filename: filename,
                      line: line,
                      column: column,
                      lines: lines,
                      endColumn: endColumn,
                      message: message)
    if filename == kPlaygroundSource {
      self?.issues = addIssueForFile(issue, self!.issues)
    } else {
      contextDiagnosticsHandler(issue)
    }}
  }


  //MARK: -
  //MARK: Playground execution

  /// Execute all commands in the playground from top to bottom.
  ///
  /// A command starts in the first column of the playground and extends over all immediately following lines whose
  /// first character is a whitespace (emulating Haskell's off-side rule).
  ///
  func execute() {
    let layoutManager = codeTextView.layoutManager
    let textContainer = codeTextView.textContainer
    let string        = codeTextView.textStorage!.string
    let gutter        = codeScrollView.verticalRulerView as TextGutterView

      // Invalidate old issues.
    gutter.updateIssues(.IssuesPending)
    issues = IssuesForFile(file: issues.file, issues: [:])

      // Mark all current results as being stale.
    resultStorage.invalidate()

    // Extracts one command, while advancing the current character index.
    //
    func extractCommandAtCharIndex(var charIndex: String.Index) -> (String.Index, String, Int) {
      let initialCharIndex = charIndex
      let lineRange        = string.lineRangeForRange(charIndex...charIndex)
      var command          = string[lineRange]
      charIndex            = lineRange.endIndex

        // Collect lines until you find one that has no white space in the first column.
        // FIXME: we need to use a proper Unicode whitespace test
      while string.endIndex > charIndex && (string[charIndex] == " " || string[charIndex] == "\t" || string[charIndex] == "\n") {
        let lineRange = string.lineRangeForRange(charIndex...charIndex)
        command      += string[lineRange]
        charIndex     = lineRange.endIndex
      }
      let span         = string.startIndex..<initialCharIndex
      let firstIndex   = string[span].utf16Count
      let indexLength  = string[initialCharIndex..<charIndex].utf16Count
      let glyphRange = layoutManager!.glyphRangeForCharacterRange(NSRange(location: firstIndex, length: indexLength),
                                                                  actualCharacterRange: nil)
      let rect       = layoutManager!.boundingRectForGlyphRange(glyphRange, inTextContainer:textContainer!)
//      return (charIndex, command, Int(floor(rect.size.height / fontHeight)))
      return (charIndex, command, Int(floor(rect.size.height / 15)))
    }

      // Traverse all commands.
    var firstIndexOfNextCommand: String.Index = string.startIndex
    var commandIndex                          = 0
    while string.endIndex > firstIndexOfNextCommand {

      let lineNumber                   = string.lineNumberAtLocation(firstIndexOfNextCommand)
      let (nextIndex, command, _lines) = extractCommandAtCharIndex(firstIndexOfNextCommand)
      firstIndexOfNextCommand          = nextIndex

      let evalResult = haskellSession.evalExprFromString(command, source: kPlaygroundSource, line: lineNumber)
      resultStorage.reportResult(evalResult, type: "", atCommandIndex: commandIndex)
      commandIndex++
    }

      // Display any diagnostics in the gutter.
    if issues.issues.isEmpty {
      gutter.updateIssues(.NoIssues)
    } else {
      gutter.updateIssues(.Issues(issues))
    }
  }
}


// MARK: -
// MARK: Syntax highlighting support

extension PlaygroundController {

  func tokeniseHaskell(file: String) -> HighlightingTokeniser {
    return { (line, column, text) in
      map(self.haskellSession.tokeniseHaskell(text, file: file, line: line, column: column)){ token in
        HighlightingToken(ghcToken: token) }
    }
  }

}


// MARK: -
// MARK: NSTextViewDelegate protocol methods (for the code view)

extension PlaygroundController: NSTextViewDelegate {
  //FIXME: This is provisionally the delegate for the REPL view while it is so simple.

  func textView(textView: NSTextView, doCommandBySelector selector: Selector) -> Bool {
    if textView != codeTextView {
      NSLog("%s: textView:doCommandBySelector from unexpected text view", __FUNCTION__)
      return false
    }

    if (selector == "insertNewline:") {

      self.execute()
      return false

    }
    return false
  }

}

// MARK: -
// MARK: NSTableViewDelegate protocol methods (for the result view)

extension PlaygroundController: NSTableViewDelegate {

  func tableViewSelectionDidChange(_notification: NSNotification) {
  }

  func tableViewColumnDidMove(_notification: NSNotification) {
  }

  func tableViewColumnDidResize(_notification: NSNotification) {
  }

  func tableViewSelectionIsChanging(_notification: NSNotification) {
  }
}
