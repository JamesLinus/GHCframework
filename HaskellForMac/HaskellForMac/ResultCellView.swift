//
//  ResultCellView.swift
//  HaskellForMac
//
//  Created by Manuel M T Chakravarty on 7/01/2015.
//  Copyright (c) 2015 Manuel M T Chakravarty. All rights reserved.
//
//  Cell views of the single-column table view used to display playground results inline.
//
//  Each cell consists of a result type and either a textual or graphical result value.

import Cocoa
import SpriteKit

// FIXME: The corresponding emil is not properly bridged to Swift yet.
let NSStackViewVisibilityPriorityMustHold: Float              = 1000
let NSStackViewVisibilityPriorityDetachOnlyIfNecessary: Float = 900
let NSStackViewVisibilityPriorityNotVisible: Float            = 0

class ResultCellView: NSTableCellView {

  // The entire view area of the cell is occupied by a stack view.
  //
  @IBOutlet private weak var stackView:       NSStackView!
  @IBOutlet private weak var resultString:    NSTextField!
  @IBOutlet private weak var resultSceneView: NSView!
  @IBOutlet private weak var resultImage:     NSImageView!
  @IBOutlet private weak var resultType:      NSTextField!

  /// The red colour used to highlight exceptional results.
  ///
  private let exceptionRedColor = NSColor(deviceRed: 180/256, green: 35/256, blue: 18/256, alpha: 1)

  /// Displays a string result and its type. If the string result is the empty string, its view is supressed.
  ///
  func configureTextualResult(result: String, type: String, stale: Bool) {

    resultString.stringValue = result
    resultType.stringValue   = type
    if result.isEmpty {
      stackView.setVisibilityPriority(NSStackViewVisibilityPriorityNotVisible, forView: resultString)
      stackView.setVisibilityPriority(NSStackViewVisibilityPriorityNotVisible, forView: resultSceneView)
      stackView.setVisibilityPriority(NSStackViewVisibilityPriorityNotVisible, forView: resultImage)
      stackView.setVisibilityPriority(NSStackViewVisibilityPriorityMustHold,   forView: resultType)
    } else {
      stackView.setVisibilityPriority(NSStackViewVisibilityPriorityMustHold,              forView: resultString)
      stackView.setVisibilityPriority(NSStackViewVisibilityPriorityNotVisible,            forView: resultSceneView)
      stackView.setVisibilityPriority(NSStackViewVisibilityPriorityNotVisible,            forView: resultImage)
      stackView.setVisibilityPriority(NSStackViewVisibilityPriorityDetachOnlyIfNecessary, forView: resultType)
    }
    configureAppearance(result, stale: stale)
  }

  /// Displays a graphical result and its type.
  ///
  func configureImageResult(result: NSImage, type: String, stale: Bool) {

    resultImage.image      = result
    resultType.stringValue = type
    stackView.setVisibilityPriority(NSStackViewVisibilityPriorityNotVisible,            forView: resultString)
    stackView.setVisibilityPriority(NSStackViewVisibilityPriorityNotVisible,            forView: resultSceneView)
    stackView.setVisibilityPriority(NSStackViewVisibilityPriorityMustHold,              forView: resultImage)
    stackView.setVisibilityPriority(NSStackViewVisibilityPriorityDetachOnlyIfNecessary, forView: resultType)
    configureAppearance(nil, stale: stale)
  }

  /// Displays a graphical as a SpriteKit scene and its type.
  ///
  func configureSceneResult(scene: SKScene, type: String, stale: Bool) {

      // Ensure the scene size is valid.
    var sceneSize = scene.size
    if !isfinite(sceneSize.width)  || sceneSize.width  < 15 { sceneSize.width  = 15 }
    if !isfinite(sceneSize.height) || sceneSize.height < 15 { sceneSize.height = 15 }
    scene.size = sceneSize

    scene.scaleMode = .AspectFit
    var resultSKView = SKView(frame: CGRect(origin: CGPointZero, size: CGSize(width: 30, height: 15)))
    resultSKView.translatesAutoresizingMaskIntoConstraints = false
    for view in resultSceneView.subviews { view.removeFromSuperview() }
    resultSceneView.addSubview(resultSKView)
    let constraintsH = NSLayoutConstraint.constraintsWithVisualFormat("|[resultSKView]|",
                                                                      options: nil,
                                                                      metrics: [:],
                                                                      views: ["resultSKView": resultSKView])
    let constraintsV = NSLayoutConstraint.constraintsWithVisualFormat("V:|[resultSKView]|",
                                                                      options: nil,
                                                                      metrics: [:],
                                                                      views: ["resultSKView": resultSKView])
    resultSceneView.addConstraints(constraintsH + constraintsV)
    resultSKView.presentScene(scene)
    resultSKView.asynchronous = false     // Stay in sync with Core Animation
    scene.paused              = true      // Don't advance the scene
      // Give the 'SKView' an opportunity to update before pausing it.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_SEC / 10)), dispatch_get_main_queue(), {
      resultSKView.paused =  true
    })

    resultType.stringValue = type
    stackView.setVisibilityPriority(NSStackViewVisibilityPriorityNotVisible,            forView: resultString)
    stackView.setVisibilityPriority(NSStackViewVisibilityPriorityMustHold,              forView: resultSceneView)
    stackView.setVisibilityPriority(NSStackViewVisibilityPriorityNotVisible,            forView: resultImage)
    stackView.setVisibilityPriority(NSStackViewVisibilityPriorityDetachOnlyIfNecessary, forView: resultType)
    configureAppearance(nil, stale: stale)
  }
  
  // FIXME: Images and scenes should also be drawn faded out when they are stale!
  private func configureAppearance(stringResult: String?, stale: Bool) {
    let isException      = stringResult != nil && stringResult!.hasPrefix("** Exception: ")
    let isNote           = stringResult != nil &&
                           stringResult!.startIndex < stringResult!.endIndex &&
                           stringResult![stringResult!.startIndex] == "«" &&
                           stringResult![advance(stringResult!.endIndex, -1)] == "»"
    let defaultTextColor = stale ? NSColor.disabledControlTextColor() : NSColor.controlTextColor()
    let valueTextColor   = isException
                             ? (stale ? self.exceptionRedColor.highlightWithLevel(0.5) : self.exceptionRedColor)
                             : (isNote ? NSColor.disabledControlTextColor() : defaultTextColor)

    resultString.textColor = valueTextColor
    resultType.textColor   = defaultTextColor
  }
}