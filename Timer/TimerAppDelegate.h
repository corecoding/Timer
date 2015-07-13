//
//  TimerAppDelegate.h
//  Timer
//
//  Created by Chris Monahan on 4/26/14.
//  Copyright 2014 Core Coding. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DatabaseHelper.h"
#import "NetworkHelper.h"

@interface TimerAppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate, NSUserNotificationCenterDelegate> {
    DatabaseHelper *databaseHelper;
    NetworkHelper *networkHelper;
    IBOutlet NSMenu *statusMenu;
    NSStatusItem *statusBar;
    IBOutlet NSMenuItem *statusItem;
    NSTimer *refreshTimer;
    IBOutlet NSMenuItem *clearDatabaseItem;
    IBOutlet NSMenuItem *quitItem;
    BOOL menuOpen;
    NSDate *lastSleep;
    
    enum NSDateOutputType {
        NSDateOutputDecimal,
        NSDateOutputHuman,
        NSDateOutputExport
    };
}

@property (nonatomic, strong) DatabaseHelper *databaseHelper;
@property (nonatomic, strong) NetworkHelper *networkHelper;
@property (nonatomic) NetworkHelper *internetReachability;

- (IBAction)clearDatabaseClicked:(id)sender;
- (IBAction)exportClicked:(id)sender;
- (IBAction)addNoteClicked:(id)sender;

@end
