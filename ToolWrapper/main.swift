//
//  main.swift
//  ToolWrapper
//
//  Created by Manuel M T Chakravarty on 5/10/2014.
//  Copyright (c) 2014 Manuel M T Chakravarty. All rights reserved.
//

import Foundation

//NSLog("Arguments: %@", Process.arguments.description)

for i in 1..<Process.arguments.count {
  if Process.arguments[i] == "--print-file-name" && i + 1 < Process.arguments.count {
    print(Process.arguments[i + 1])
  }
}
