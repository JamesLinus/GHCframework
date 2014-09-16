//
//  TextGutterView.swift
//  HaskellForMac
//
//  Created by Manuel M T Chakravarty on 5/08/2014.
//  Copyright (c) 2014 Manuel M T Chakravarty. All rights reserved.
//
//  This totally guts the drawing functionality of 'NSRuleView' and replaces it with a vertical ruler of line numbers.
//  The benefit we get out of subclassing 'NSRuleView' is the integration with the enclosing scroll view and the
//  scrolled content.

import Cocoa


class TextGutterView: NSRulerView {

  // All issues currently flagged for the file annotated by this gutter.
  //
  private var issues: Issues = [:]

  // Whether the issues set is current or invalidated (i.e., new ones are being computed).
  //
  private var markIssuesAsInvalid: Bool = false
  
  // Text attributes for line numbers
  //
  private let textAttributes = [NSFontAttributeName:            NSFont.systemFontOfSize(NSFont.smallSystemFontSize()),
                                NSForegroundColorAttributeName: NSColor(deviceWhite: 0.5, alpha: 1)]

  // Background colours for issues
  //
  private let errorBgColour           = NSColor(red: 1, green: 0.4, blue: 0,   alpha: 0.5)
  private let disabledErrorBgColour   = NSColor(red: 1, green: 0.4, blue: 0,   alpha: 0.2)
  private let warningBgColour         = NSColor(red: 1, green: 1,   blue: 0.3, alpha: 0.5)
  private let disabledWarningBgColour = NSColor(red: 1, green: 1,   blue: 0.3, alpha: 0.2)

  private let errorSymbol   = "⛔️"
  private let warningSymbol = "❕"

  // Gap between the line numbers and the bounding box of the ruler.
  //
  private let margin: CGFloat = 3

  /// The text attributes to be applied to all text in the code and result text views. (Currently, they are fixed.)
  //
  // FIXME: Unify with 'TextEditorController.swift'
  private let diagnosticsTextAttributes: NSDictionary = { () in
    let menlo12 = NSFont(name: "Menlo-Regular", size:12)
    return [NSFontAttributeName: menlo12]
  }()

  // Objects from the diagnostics popover nib.
  //
  @IBOutlet private var popover:           NSPopover?           // referenced to retain
  @IBOutlet private var popoverController: NSViewController!    // referenced to retain
  @IBOutlet private var popoverTextView:   NSTextView!          // This is where the diagnostics goes.


  // MARK: -
  // MARK: Initialisation

  override init(scrollView: NSScrollView!, orientation: NSRulerOrientation) {
    if orientation == .HorizontalRuler {
      NSLog("%s: 'TextGutterView' does not support a horizontal orientation", __FUNCTION__)
    }

    super.init(scrollView: scrollView, orientation: orientation)

    self.clientView = scrollView.documentView as NSView
  }

  required init(coder: NSCoder) {
    super.init(coder: coder)
  }


  // MARK: -
  // MARK: Notifications

  /// Notify the gutter of a new set of issues for the associated file. (This invalidated all previous issues.)
  ///
  func updateIssues(notification: IssueNotification) {
    switch notification {
    case .NoIssues:                  markIssuesAsInvalid = false; issues = [:]
    case .IssuesPending:             markIssuesAsInvalid = true
    case .Issues(let issuesForFile): markIssuesAsInvalid = false; issues = issuesForFile.issues
    }
    needsDisplay = true
  }


  // MARK: -
  // MARK: Custom drawing

  override func viewWillDraw() {
    ruleThickness = ("9999" as NSString).sizeWithAttributes(textAttributes).width + margin * 2;
      // setting 'ruleThickness' in init leads to a loop
  }

  override func drawHashMarksAndLabelsInRect(rect: NSRect) {
    let textView      = self.clientView as NSTextView
    let layoutManager = textView.layoutManager
    let textContainer = textView.textContainer
    let string        = textView.textStorage.string
    let visibleRect   = self.scrollView.documentVisibleRect

      // All visible glyphs and all visible characters
    let glyphRange    = layoutManager.glyphRangeForBoundingRectWithoutAdditionalLayout(visibleRect,
                                                                                       inTextContainer: textContainer)
    let charRange     = layoutManager.characterRangeForGlyphRange(glyphRange, actualGlyphRange: nil)

      // Line number of first visible line
    let firstLineNumber = string.lineNumberAtLocation(charRange.location)

      // Remove the diagnostics popover if it is visible.
    if popover != nil && popover!.shown {
      popover!.close()
    }

      // Iterate through the line numbers of all visible lines
      //
      // NB: The line number of the first visible line may not be visble (if the line wraps), but clipping handles that
      //     for us.
    var lineNumber = firstLineNumber
    var charIndex  = charRange.location
    while charIndex < NSMaxRange(charRange) {

      let lineRange = (string as NSString).lineRangeForRange(NSRange(location: charIndex, length: 0))

        // Draw the number for the current line
      let (gutterRect, middleline) = gutterRectForCharRange(lineRange)
      drawLineNumber(lineNumber, rect: gutterRect, middleline: middleline)

        // Advance to next line
      lineNumber++
      charIndex = NSMaxRange(lineRange)
    }

      // Make sure to add an extra line number if we have an empty last line.
    if (string as NSString).length == NSMaxRange(charRange)
        && (string as NSString).length > 0
        && string[advance(string.endIndex, -1)] == "\n" {
      let rect = layoutManager.extraLineFragmentRect
      if rect != NSZeroRect {
        drawLineNumber(
          lineNumber,
          rect: NSRect(x: 0, y: rect.origin.y - visibleRect.origin.y, width: ruleThickness, height: rect.size.height),
          middleline: rect.size.height / 2)
      }
    }
  }

  // Computes the rect of the gutter area associated with the given character range (as well as the middle lines of the
  // first text line) — the overall range may span multiple text lines due to line wrapping.
  //
  private func gutterRectForCharRange(charRange: NSRange) -> (NSRect, CGFloat) {
    let textView      = self.clientView as NSTextView
    let layoutManager = textView.layoutManager
    let textContainer = textView.textContainer
    let string        = textView.textStorage.string
    let visibleRect   = self.scrollView.documentVisibleRect

      // Draw the number for the current line
    let firstIndex = layoutManager.glyphIndexForCharacterAtIndex(charRange.location)
    let firstRect  = layoutManager.lineFragmentRectForGlyphAtIndex(firstIndex,
                                                                   effectiveRange: nil)
    let lastIndex  = (charRange.length == 0) ? firstIndex
                                             : layoutManager.glyphIndexForCharacterAtIndex(NSMaxRange(charRange) - 1)
    let lastRect   = layoutManager.lineFragmentRectForGlyphAtIndex(lastIndex,
                                                                   effectiveRange: nil)
    return (NSRect(x: 0,
                   y: firstRect.origin.y - visibleRect.origin.y,
                   width: ruleThickness,
                   height: lastRect.origin.y - firstRect.origin.y + lastRect.size.height),
            firstRect.size.height / 2)
  }

  // Draws the given number in the gutter, such that the glyphs' is vertically centred around the given middle line.
  // The middle line is centred with the first row of the line and is relative to the rect, which specifies the extent
  // of the gutter area belonging to this line (for background drawing).
  //
  private func drawLineNumber(lineNumber: UInt, rect: NSRect, middleline: CGFloat) {

      // Draw the background.
    let lineIssuesOpt = issues[lineNumber]
    let maxSeverity   = (lineIssuesOpt == nil) ? nil : maxSeverityOfIssues(lineIssuesOpt!)
    if let severity = maxSeverity {

      switch severity {
      case .Error:   (markIssuesAsInvalid ? disabledErrorBgColour   : errorBgColour  ).setFill()
      case .Warning: (markIssuesAsInvalid ? disabledWarningBgColour : warningBgColour).setFill()
      case .Other:   return
      }
      NSBezierPath(rect: rect).fill()

    }

      // Draw the number.
    let numberString = lineNumber.description as NSString
    let size         = numberString.sizeWithAttributes(textAttributes)
    numberString.drawAtPoint(NSPoint(x: NSMaxX(rect) - margin - size.width,
                                     y: rect.origin.y + middleline - size.height / 2),
                             withAttributes: textAttributes)

      // Draw an issue symbol if any.
    if let severity = maxSeverity {

      var symbol: String
      switch severity {
      case .Error:   symbol = errorSymbol
      case .Warning: symbol = warningSymbol
      case .Other:   return
      }
      symbol.drawAtPoint(NSPoint(x: rect.origin.x,
                                 y: rect.origin.y + middleline - size.height / 2),
                                 withAttributes: textAttributes)
    }
  }
}


// MARK: -
// MARK: 'NSView' delegate methods

extension TextGutterView {
  override func mouseDown(event: NSEvent!) {
    let textView      = self.clientView as NSTextView
    let layoutManager = textView.layoutManager
    let textContainer = textView.textContainer
    let string        = textView.textStorage.string
    let visibleRect   = self.scrollView.documentVisibleRect

      // Determine the line corresponding to the mouse down event.
    let rulerLoc   = self.convertPoint(event.locationInWindow, fromView: nil)
    let textLoc    = NSPoint(x: 0, y: visibleRect.origin.y + rulerLoc.y)
    let glyphIndex = layoutManager.glyphIndexForPoint(textLoc, inTextContainer: textContainer)
    let charIndex  = layoutManager.characterIndexForGlyphAtIndex(glyphIndex)
    let lineNumber = string.lineNumberAtLocation(charIndex)

      // If there is an issue at this line, display the error message in a popup view.
    if let issues = issues[lineNumber] {

      var objs: NSArray?
      let (gutterRect, _) = gutterRectForCharRange(NSRange(location: charIndex, length: 0))
      let bundle     = NSBundle.mainBundle()
      if !bundle.loadNibNamed("DiagnosticsPopover", owner: self, topLevelObjects: nil) {
        NSLog("%@: could not load popover NIB", __FUNCTION__)
      } else {

        let msg = NSAttributedString(string: issues.map{$0.message}.reduce(""){$0 + $1},
                                     attributes: diagnosticsTextAttributes)
        popoverTextView.textStorage.insertAttributedString(msg, atIndex: 0)
        let textSize    = msg.size
        let insetSize   = NSSize(width: 0, height: 10)
        let height      = textSize.height + insetSize.height
        let contentSize = NSSize(width: textSize.width + insetSize.width + 14, height: height > 100 ? 100 : height)
        popoverTextView.textContainerInset = insetSize
        popover?.contentSize               = contentSize
        popover?.behavior                  = .Semitransient
        popover?.showRelativeToRect(gutterRect, ofView:self, preferredEdge: 4/*NSMaxYEdge*/)
      }
    }
  }
}