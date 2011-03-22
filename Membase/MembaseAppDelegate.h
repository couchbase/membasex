//
//  MembaseAppDelegate.h
//  Membase
//
//  Created by Dustin Sallings on 3/22/11.
//  Copyright 2011 NorthScale. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MembaseAppDelegate : NSObject <NSApplicationDelegate> {
@private
    NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
