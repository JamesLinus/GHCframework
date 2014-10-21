//
//  PlaygroundResultStorage.swift
//  HaskellForMac
//
//  Created by Manuel M T Chakravarty on 19/10/2014.
//  Copyright (c) 2014 Manuel M T Chakravarty. All rights reserved.
//
//  This class is the view model for the results displayed in a playground and serves as the data source of the table
//  view displaying the results.

import Cocoa

// Table view cell identifiers
//
let kTypeCell  = "TypeCell"
let kValueCell = "ValueCell"

/// Represents the result for a single command.
///
private struct Result {
  // FIXME: for now, it's all strings, but we want to be more flexible in the future.

  let value:  String
  let type:   String
  let height: CGFloat       // cell height — FIXME: this should be computed from the text view's layout manager instead of being chached
  let stale:  Bool          // a result is stale while it is being recomputed
}

class PlaygroundResultStorage: NSObject {

  // The results for all commands in the playground if successfully computed.
  //
  // NB: The length of the array always equals the number of commands in the playground.
  //
  private var results: [Result?] = []

  /// Type of callback to advise results view that all rows need to be redisplayed.
  ///
  typealias Redisplay = () -> ()

  /// Type of callback to advise results view that the row for the given command index needs to be redisplayed.
  ///
  typealias RedisplayRow = Int -> ()

  private let redisplay:    Redisplay
  private let redisplayRow: RedisplayRow

  init(redisplay: Redisplay, redisplayRow: RedisplayRow) {
    self.redisplay    = redisplay
    self.redisplayRow = redisplayRow
  }

  /// Reports a result at a specific index. Allocates new results slots if needed.
  ///
  func reportResult(result: String, type: String, height: CGFloat, atCommandIndex idx: Int) {

      // Extend the array to include the reported index if necessary.
    if idx >= results.endIndex {
      for i in results.endIndex...idx { results.append(nil) }
    }
    results[idx] = Result(value: result, type: type, height: height, stale: false)
    redisplayRow(idx)
  }

  /// Discard all entries from the given index on.
  ///
  func pruneAt(idx: Int) {
    if idx < results.endIndex {
      results.removeRange(idx..<results.endIndex)
    }
    redisplay()
  }

  /// Marks all current results as stale.
  ///
  func invalidate() {
    results = results.map{ result in
      if let result = result {
        return Result(value: result.value, type: result.type, height: result.height, stale: true)
      } else { return nil }
    }
    redisplay()
  }
}


// MARK: -
// MARK: NSTableViewDelegate & NSTableViewDataSource protocol methods (for the result view)

extension PlaygroundResultStorage: NSTableViewDataSource {

  func numberOfRowsInTableView(_tableView: NSTableView) -> Int {
    return results.count
  }
}

extension PlaygroundResultStorage: NSTableViewDelegate {
    
  func tableView(tableView: NSTableView, viewForTableColumn column: NSTableColumn, row: Int) -> NSTableCellView? {

    if let result = results[row] {

      let identifier = column.identifier
      switch identifier {
      case "TypeCell":
        if let cell = tableView.makeViewWithIdentifier(identifier, owner: self) as? NSTableCellView {
          cell.textField?.stringValue = result.type
          cell.textField?.textColor   = result.stale ? NSColor.disabledControlTextColor() : NSColor.controlTextColor()
          return cell
        } else { return nil }
      case "ValueCell":
        if let cell = tableView.makeViewWithIdentifier(identifier, owner: self) as? NSTableCellView {
          cell.textField?.stringValue = result.value
          cell.textField?.textColor   = result.stale ? NSColor.disabledControlTextColor() : NSColor.controlTextColor()
          return cell
        } else { return nil }
      default:
        return nil
      }

    } else { return nil }
  }

  func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
    if let result = results[row] {
      return result.height
    } else { return 0 }
  }

//  func tableViewSelectionDidChange(_notification: NSNotification) {
//  }
//
//  func tableViewColumnDidMove(_notification: NSNotification) {
//  }
//
//  func tableViewColumnDidResize(_notification: NSNotification) {
//  }
//
//  func tableViewSelectionIsChanging(_notification: NSNotification) {
//  }
}