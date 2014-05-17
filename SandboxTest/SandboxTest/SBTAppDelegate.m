//
//  SBTAppDelegate.m
//  SandboxTest
//
//  Created by Manuel M T Chakravarty on 15/05/2014.
//  Copyright (c) 2014 Manuel M T Chakravarty. All rights reserved.
//

#include <spawn.h>

#import "SBTAppDelegate.h"

//#define CLANG "/usr/bin/clang"
#define CLANG "/Library/Developer/CommandLineTools/usr/bin/clang"

#define C_SOURCE "test.c"


@implementation SBTAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  [panel setCanChooseDirectories:YES];
  [panel setAllowsMultipleSelection:YES];
  [panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
    if (result == NSFileHandlingPanelOKButton) {	// Only if not cancelled
      NSURL *url = [panel URL];
      chdir([[url path] UTF8String]);
    }
    else
      chdir("/Users/chak/tmp");

    char *argv[] = {CLANG, "-c", C_SOURCE, NULL};
    int err = posix_spawn(NULL, CLANG, NULL, NULL, argv, NULL);
    if (err)
      NSLog(@"unable to spawn clang: error code %d", err);

  }];
}

@end
