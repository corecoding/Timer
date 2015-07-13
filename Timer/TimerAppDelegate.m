//
//  TimerAppDelegate.m
//  Timer
//
//  Created by Chris Monahan on 4/26/14.
//  Copyright 2014 Core Coding. All rights reserved.
//

#import "TimerAppDelegate.h"
#import "Note.h"
#import "Timesheet.h"

@implementation TimerAppDelegate

@synthesize databaseHelper, networkHelper;

//- (void)test1:(NSNotification *)note {
//    NSLog(@"NSWorkspaceSessionDidResignActiveNotification");
//}
//
//- (void)test2:(NSNotification *)note {
//    NSLog(@"NSWorkspaceSessionDidBecomeActiveNotification");
//}

#pragma mark Main Operations

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSLog(@"applicationDidFinishLaunching");

    // initialize the database helper
    if (!databaseHelper) {
        databaseHelper = [[DatabaseHelper alloc] init];
    }

    // initialize the network helper
    if (!networkHelper) {
        networkHelper = [[NetworkHelper alloc] init];
    }

    // register on NSWorkspace's notification center not default notification center
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(computerWake:) name:NSWorkspaceDidWakeNotification object:NULL];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(computerSleep:) name:NSWorkspaceWillSleepNotification object:NULL];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(computerSleep:) name:NSWorkspaceWillPowerOffNotification object:NULL];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(computerWake:) name:NSWorkspaceScreensDidWakeNotification object:NULL];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(computerSleep:) name:NSWorkspaceScreensDidSleepNotification object:NULL];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];

//    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(test1:) name:NSWorkspaceSessionDidResignActiveNotification object:NULL];
//    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(test2:) name:NSWorkspaceSessionDidBecomeActiveNotification object:NULL];

    // only check arp when internet is available
    [self checkPhysicalLocationWithCount:0];

    menuOpen = NO;
    [self updateMenu];
    [self startTimerWithDuration:60];
}

- (void)awakeFromNib {
    [statusMenu setDelegate:self];
    statusBar = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];

    [self updateStatusIcons];
    
    [statusBar setMenu:statusMenu];
    [statusBar setHighlightMode:YES];

    NSDictionary *tasks = @{ @"01Development": @"",
                             @"02Administration": @"",
                             @"03I.T. Support": @"",
                             @"04Personal": @"",
                             @"05-": @"",
                             @"06Client": @[ @"Internal",
                                             @"Company 1",
                                             @"Company 2",
                                             @"Company 3"
                                           ],
                            };
    
    NSArray *keys = [tasks allKeys];
    keys = [keys sortedArrayUsingComparator:^(id a, id b) {
        return [a compare:b options:NSNumericSearch];
    }];
    
    for (int i=0; i<[keys count]; i++) {
        NSString *title = [keys[i] substringWithRange:NSMakeRange(2, [keys[i] length] - 2)];
        NSMenuItem *task;

        if ([title isEqualToString:@"-"]) {
            // insert divider
            task = [NSMenuItem separatorItem];
        } else {
            // add menu item
            task = [[NSMenuItem alloc] initWithTitle:title action:@selector(taskClicked:) keyEquivalent:@""];
            [task setRepresentedObject:[[NSDictionary alloc] initWithObjectsAndKeys:@"task", @"type", title, @"title", @"", @"objectId", nil]];
        }
        
        id object = [tasks objectForKey:keys[i]];
        if ([object isKindOfClass:[NSArray class]]) {
            // make sure the menu item can't be clicked
            [task setAction:nil];

            // add subtasks for this menu item
            NSArray *subTasks = object;
            NSMenu *subMenu = [[NSMenu alloc] init];
            for (int x=0; x<[subTasks count]; x++) {
                NSMenuItem *subTask = [[NSMenuItem alloc] initWithTitle:subTasks[x] action:@selector(taskClicked:) keyEquivalent:@""];
                [subTask setRepresentedObject:[[NSDictionary alloc] initWithObjectsAndKeys:@"client", @"type", subTasks[x], @"title", @"", @"objectId", nil]];
                
                // default first item
                if (x == 0) {
                    [subTask setState:NSOnState];

                    // set title of sub menu item to main menu (smaller red font)
                    [task setAttributedTitle:[self getAttributedStringFromTitle:title andSubtitle:subTasks[x]]];
                    
                    NSDate *theDate = [NSDate date];
                    [subTask setTag:[theDate timeIntervalSince1970]]; // CPM used to have -1, can remove comment 1 of 2
                }
                
                [subMenu addItem:subTask];
            }
            
            [task setSubmenu:subMenu];
        }
        
        [task setTarget:self];
        [statusMenu insertItem:task atIndex:i + 2];
    }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    NSLog(@"applicationShouldTerminate");

    // turn off all existing tasks
    [self turnOffAllTasks];
    
    // cancel timer
    [self stopTimer];

    // make sure the database is saved
    [databaseHelper saveContext];

    // unregister observers
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self name:NSWorkspaceDidWakeNotification object:NULL];
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self name:NSWorkspaceWillSleepNotification object:NULL];
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self name:NSWorkspaceWillPowerOffNotification object:NULL];
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self name:NSWorkspaceScreensDidWakeNotification object:NULL];
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self name:NSWorkspaceScreensDidSleepNotification object:NULL];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];

    return NSTerminateNow;
}

# pragma mark Task Management

- (IBAction)clearDatabaseClicked:(id)sender {
    [self turnOffAllTasks];

    [databaseHelper eraseAllContent];
    
    // initialize the database helper
    databaseHelper = nil;
    if (!databaseHelper) {
        databaseHelper = [[DatabaseHelper alloc] init];
    }
    
    // only check arp when internet is available
    [self checkPhysicalLocationWithCount:0];
}

- (IBAction)exportClicked:(id)sender {
    NSLog(@"Exporting timesheet for %@...", NSFullUserName());
    
    // determine employee initials
    NSMutableString *employeeInitials = [NSMutableString string];
    NSArray *words = [NSFullUserName() componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    for (NSString *word in words) {
        if ([word length] > 0) {
            NSString *firstLetter = [word substringToIndex:1];
            [employeeInitials appendString:[firstLetter uppercaseString]];
        }
    }
    
    NSString *billing = @"N";//
    NSString *companyCode = @"SOTG";
    
    NSMutableString *csv = [NSMutableString stringWithString:@"Date,Empl Initials,Project or Task Name,NO1,NO2,Billing Status,Start Time,End Time,Total Time,Notes or Comments,Company Code,Project Type"];
    
    NSArray *fetchedObjects = [databaseHelper grabAllEntries];
    for (Timesheet *sheet in fetchedObjects) {
        NSMutableString *notes = [[NSMutableString alloc] init];
        NSArray *notez = sheet.notes.allObjects;
        for (Note *note in notez) {
            if ([note activity] != nil) {
                NSLog(@"note %@", [note activity]);
                if ([notes length] > 0) {
                    [notes appendString:@", "];
                }

                [notes appendString:[note activity]];
            }
        }
        
        if (sheet.start != nil && sheet.end != nil) {
            NSLog(@"TODO - put the clients and 'titles' into their own databases and remove these hardcoded values");
            NSString *projectType = @"Admin";
            NSString *project = sheet.title;
            if ([project isEqualToString:@"Development"]) {
                project = @"Application Enhancement";
                projectType = @"D";
            } else if ([project isEqualToString:@"I.T. Support"]) {
                project = @"";
                projectType = @"IT";
            } else if ([project isEqualToString:@"Administration"]) {
                project = @"";
                projectType = @"Admin";
            }
            
            // calculate duration
            int duration = [sheet.end timeIntervalSince1970] - [sheet.start timeIntervalSince1970];
            NSString *humanReadable = [self formattedStringForDuration:duration returnIn:NSDateOutputExport];

            [csv appendFormat:@"\n%@,%@,%@,,,%@,%@,%@,%@,\"%@\",%@,%@", [self convertToDate:sheet.start], employeeInitials, project, billing, [self convertToTime:sheet.start], [self convertToTime:sheet.end], humanReadable, notes, companyCode, projectType];
        }
    }

    NSError *error;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *csvFileName = [NSString stringWithFormat:@"%@/timesheet.csv", [paths firstObject]];
    if ([csv writeToFile:csvFileName atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        [[NSWorkspace sharedWorkspace] openFile:csvFileName withApplication:@"Microsoft Excel"];
    } else {
        NSLog(@"Error %@ while writing to file %@", [error localizedDescription], csvFileName);
    }
}

- (IBAction)taskClicked:(id)sender {
    NSDictionary *senderData = [sender representedObject];

    // turn off all existing tags
    BOOL turnedOffItem = NO;
    for (NSMenuItem *item in [statusMenu itemArray]) {
        NSDictionary *itemData = [item representedObject];
        if (!itemData) continue;
        
//        NSLog(@"looping %@ %@", [itemData objectForKey:@"title"], ([item hasSubmenu])?@"yes":@"no");
//        NSLog(@"%@ %d", [itemData objectForKey:@"type"], item.tag);
 
        if (item.tag > 0 && item != sender) {
            // turn off previous development modes, or all clients
            if ([[senderData objectForKey:@"type"] isEqualToString:[itemData objectForKey:@"type"]]) {
                [self turnOffTask:item withEndDate:[NSDate date] displayAlert:NO updateMenuBar:YES];
                turnedOffItem = YES;
            }
        }
        
        if ([item hasSubmenu]) {
            for (NSMenuItem *subItem in [[item submenu] itemArray]) {
                NSDictionary *subItemData = [subItem representedObject];

                //NSLog(@"%@", subItem);
                
                if (subItem.tag > 0 && subItem != sender) {
                    // turn off previous development modes, or all clients
                    if ([[senderData objectForKey:@"type"] isEqualToString:[subItemData objectForKey:@"type"]]) {
                        [self turnOffTask:subItem withEndDate:[NSDate date] displayAlert:NO updateMenuBar:YES];
                        turnedOffItem = YES;
                    }
                }
            }
        }
    }

    if ([sender state] == NSOnState) {
        // make sure one item is always on
        if (turnedOffItem) {
            [self turnOffTask:sender withEndDate:[NSDate date] displayAlert:YES updateMenuBar:YES];
        }
    } else {
        [self turnOnTask:sender withStartDate:[NSDate date] displayAlert:YES updateMenuBar:YES];
    }
}

- (void)turnOffTask:(id)sender withEndDate:(NSDate *)endDate displayAlert:(BOOL)showAlert updateMenuBar:(BOOL)updateMenu {
    NSDictionary *itemData = [sender representedObject];

    NSString *type = [itemData objectForKey:@"type"];
    NSLog(@"unclicked %@ - %@", type, [itemData objectForKey:@"title"]);

    [sender setTag:0];
    [sender setState:NSOffState];

    if ([type isEqualToString:@"task"]) {
        NSString *title = [itemData objectForKey:@"title"];
        
        // remove attributed text
        [sender setTitle:title];
        [sender setAttributedTitle:nil];
        
        Timesheet *sheet = [databaseHelper getEntryFromObject:[itemData objectForKey:@"objectId"]];
        [databaseHelper updateSheet:sheet withEndDate:endDate];
        
        NSLog(@"ID: %@, Start: %@, End: %@", sheet.objectID, sheet.start, sheet.end);

        if (showAlert) {
            int duration = (int) ((long) [[NSDate date] timeIntervalSince1970] - (long) [sheet.start timeIntervalSince1970]);
            [self displayNotificationMessage:[NSString stringWithFormat:@"%@ (%@)", title, [self formattedStringForDuration:duration returnIn:NSDateOutputHuman]] withTitle:@"Stopped Task"];
        }

        if (updateMenu) {
            [self updateStatusIcons];
            [self updateMenu];
        }
    } else if ([type isEqualToString:@"client"]) {
    }
}

- (void)turnOnTask:(id)sender withStartDate:(NSDate *)startDate displayAlert:(BOOL)showAlert updateMenuBar:(BOOL)updateMenu {
    NSDictionary *itemData = [sender representedObject];
    NSString *title = [itemData objectForKey:@"title"];
    
    NSString *type = [itemData objectForKey:@"type"];
    NSLog(@"clicked %@ - %@", type, title);

    [sender setTag:[startDate timeIntervalSince1970]]; // CPM used to have -1, can remove comment 2 of 2
    [sender setState:NSOnState];

    if ([type isEqualToString:@"task"]) {
        if (showAlert) {
            [self displayNotificationMessage:title withTitle:@"Started Task"];
        }
        
        NSManagedObjectID *objectId = [databaseHelper addEntryWithDate:startDate withTitle:title withClient:@""];
        [sender setRepresentedObject:[[NSDictionary alloc] initWithObjectsAndKeys:type, @"type", title, @"title", objectId, @"objectId", nil]];
        
        if (updateMenu) {
            [self updateStatusIcons];
            [self updateMenu];
        }
    } else if ([type isEqualToString:@"client"]) {
        // grab client dropdown menu item, there has to be a cleaner way to do this, maybe grab parent item based off sub item clicked?
        NSMenuItem *item = [[statusMenu itemArray] objectAtIndex:7];
        
        // set title of sub menu item to main menu (smaller red font
        [item setAttributedTitle:[self getAttributedStringFromTitle:@"Client" andSubtitle:title]];
        
        // reset current developer item because the client was changed
        for (NSMenuItem *item in [statusMenu itemArray]) {
            NSDictionary *itemData = [item representedObject];
            
            if (itemData && item.tag > 0) {
                [self turnOffTask:item withEndDate:[NSDate date] displayAlert:NO updateMenuBar:YES];
                [self turnOnTask:item withStartDate:startDate displayAlert:NO updateMenuBar:YES];
            }
        }
    }
}

- (void)menuWillOpen:(NSMenu *)menu {
    //NSLog(@"menu opened");
    menuOpen = YES;
    
    [self stopTimer];
    [self startTimerWithDuration:1];
    
    // was the menu clicked with the right or left mouse button?
    int button = (int) [NSEvent pressedMouseButtons];
    
    // only show clear database on right click - for some reason, the first right click registers as 0
    [clearDatabaseItem setHidden:!(button == 2)];
    [quitItem setHidden:!(button == 2)];
    
    [self updateMenu];
}

- (void)menuDidClose:(NSMenu *)menu {
    //NSLog(@"menu closed");
    menuOpen = NO;
    [self stopTimer];
    [self startTimerWithDuration:60];
}

- (void)turnOffAllTasks {
    // sleep all current tasks
    for (NSMenuItem *item in [statusMenu itemArray]) {
        if (item.tag > 0 && [item state] == NSOnState) {
            [self turnOffTask:item withEndDate:[NSDate date] displayAlert:NO updateMenuBar:YES];
        }
    }
}

- (void)computerWake:(NSNotification *)note {
    NSLog(@"computerWake: %@", [note name]);

    [self updateMenu];

    // only turn off previous task timers when the computer has been asleep longer than ten minutes
    if (lastSleep != nil) {
        int duration = (int) ((long) [[NSDate date] timeIntervalSince1970] - (long) [lastSleep timeIntervalSince1970]);
        NSLog(@"slept for %i seconds", duration);
        if (duration > 60 * 10) {
            NSLog(@"turning off tasks");
            // retroactively turn all current tasks
            for (NSMenuItem *item in [statusMenu itemArray]) {
                if (item.tag > 0 && [item state] == NSOnState) {
                    [self turnOffTask:item withEndDate:lastSleep displayAlert:NO updateMenuBar:YES];
                }
            }

            // see if we are at the office and if so, turn on the Development task
            [self checkPhysicalLocationWithCount:0];
        }
    
        lastSleep = nil;
    }
}

- (void)computerSleep:(NSNotification *)note {
    NSLog(@"computerSleep: %@", [note name]);
    
    // remember the the time the computer slept
    if (lastSleep == nil) {
        lastSleep = [NSDate date];
    }

    // loop through all tasks
    for (NSMenuItem *item in [statusMenu itemArray]) {
        // only process active tasks
        if (item.tag > 0 && [item state] == NSOnState) {
            NSDictionary *itemData = [item representedObject];

            // only process tasks for now
            NSString *type = [itemData objectForKey:@"type"];
            if ([type isEqualToString:@"task"]) {
                // update database with time of sleep
                Timesheet *sheet = [databaseHelper getEntryFromObject:[itemData objectForKey:@"objectId"]];
                [databaseHelper updateSheet:sheet withEndDate:lastSleep];
            } else if ([type isEqualToString:@"client"]) {
            }
        }
    }

    // make sure the database is saved as sometimes macs fail to wake the screen, in which case the computer has to be shut down forcefully
    [databaseHelper saveContext];
}

#pragma mark - Network Helpers

- (void)checkPhysicalLocationWithCount:(int)count {
    if ([networkHelper isInternetConnection]) {
        [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(checkNetworkWithCount:) userInfo:[NSNumber numberWithInteger:(count + 1)] repeats:NO];
    } else {
        NSLog(@"turning reachability on");
        self.internetReachability = [NetworkHelper reachabilityForInternetConnection];
        [self.internetReachability startNotifier];
    }
}

- (void)reachabilityChanged:(NSNotification *)note {
    //NetworkHelper *curReach = [note object];
    
    NSLog(@"connection change detected");
    
    if ([networkHelper isInternetConnection]) {
        [self.internetReachability stopNotifier];
        self.internetReachability = nil;
        
        NSLog(@"turning reachability off, checking location");
        [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(checkNetworkWithCount:) userInfo:[NSNumber numberWithInteger:1] repeats:NO];
    }
}

- (void)checkNetworkWithCount:(NSTimer *)theTimer {
    // skip network detection if the user has already picked a task
    for (NSMenuItem *item in [statusMenu itemArray]) {
        if (item.tag > 0) {
            NSLog(@"skipping");
            return;
        }
    }

    // only run three network checks
    int count = [[theTimer userInfo] intValue];
    NSLog(@"checkNetworkWithCount attempt %i", count);

    // TODO - make this a dialog boxx
    NSDictionary *macToTasks = @{ @"aa:bb:cc:dd:ee:ff": @"2", // work router
                                  @"aa:bb:cc:dd:ee:ff": @"5" }; // home router
    
    int found = [networkHelper checkForMacAddress:macToTasks];
    if (found > 0) {
        NSLog(@"identified location");
        
        NSMenuItem *item = [[statusMenu itemArray] objectAtIndex:found];
        if ([item tag] == 0) {
            [self taskClicked:item];
        }
    } else {
        if (count >= 3) {
            NSLog(@"giving up, can't determine location");
            return;
        } else {
            NSLog(@"cannot determine location");
        }

        [self checkPhysicalLocationWithCount:count];
    }
}

#pragma mark Internal Helpers

- (NSString *)convertToTime:(NSDate *)dateTime {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"h:mm a";
    return [df stringFromDate:dateTime];
}

- (NSString *)convertToDate:(NSDate *)dateTime {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"MM/dd/yy";
    return [df stringFromDate:dateTime];
}

- (void)displayNotificationMessage:(NSString *)message withTitle:(NSString *)title {
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.soundName = NSUserNotificationDefaultSoundName;
    notification.informativeText = message;
    notification.title = title;
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

- (NSString *)formattedStringForDuration:(int)duration returnIn:(enum NSDateOutputType)format {
    int hours = floor(duration / (60 * 60));
    int minutes = floor((duration / 60) - hours * 60);
    int seconds = floor(duration - (minutes * 60) - (hours * 60 * 60));
    
    NSString *readable = @"";
    
    switch (format) {
        case NSDateOutputDecimal:
            readable = [NSString stringWithFormat:@"%.02f", hours + ((float) minutes / 60) + ((float) seconds / 3600)];
            break;
        case NSDateOutputHuman:
            if (hours > 0) {
                readable = [NSString stringWithFormat:@"%@ %ih", readable, hours];
            }
            
            if (minutes > 0) {
                readable = [NSString stringWithFormat:@"%@ %im", readable, minutes];
            }
            
            if (seconds > 0 && [readable length] == 0) {
                readable = [NSString stringWithFormat:@"%@ %is", readable, seconds];
            }
            break;
        case NSDateOutputExport:
            readable = [NSString stringWithFormat:@"%.02i:%.02i", hours, minutes];
            break;
    }
    
    return [readable stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (void)startTimerWithDuration:(int)interval {
    // run a timer in the background
    refreshTimer = [NSTimer timerWithTimeInterval:interval target:self selector:@selector(updateMenu) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:refreshTimer forMode:NSRunLoopCommonModes];
}

- (void)stopTimer {
    [refreshTimer invalidate];
    refreshTimer = nil;
}

#pragma mark Screen Helpers

- (void)updateMenu {
    NSLog(@"******************************************** menu updated");
    
    // calculate day of year for today's date
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSUInteger dayOfYear = [gregorian ordinalityOfUnit:NSDayCalendarUnit inUnit:NSYearCalendarUnit forDate:[NSDate date]];
    
    NSMutableArray *databaseObjects = [[NSMutableArray alloc] init];
    
    for (NSMenuItem *item in [statusMenu itemArray]) {
        if (item.tag > 0) {
            // add object from menu to array to pass to database
            NSDictionary *itemData = [item representedObject];
            [databaseObjects addObject:[itemData objectForKey:@"objectId"]];
            
            // calculate day of year for tasks date
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:item.tag];
            NSUInteger taskDayOfYear = [gregorian ordinalityOfUnit:NSDayCalendarUnit inUnit:NSYearCalendarUnit forDate:date];

            // working through midnight? we have to stop the current task and restart tomorrow
            if (dayOfYear > taskDayOfYear) {
                NSLog(@"And the clock strikes 12, get some sleep!");

                // grab task start timestamp and set end time to midnight
                NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
                NSDateComponents *components = [calendar components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit) fromDate:date];
                [components setHour:23];
                [components setMinute:59];
                [components setSecond:59];

                // calculate 1 second prior to midnight
                NSDate *stopDate = [[NSCalendar currentCalendar] dateFromComponents:components];

                // calculate midnight
                NSDate *startDate = [NSDate dateWithTimeInterval:1.0 sinceDate:stopDate];

                int diff = (int) ((long) [stopDate timeIntervalSince1970] - (long) [startDate timeIntervalSince1970]);
                if (diff > 0) {
                    // stop all tasks before midnight and start back up at midnight
                    [self turnOffTask:item withEndDate:stopDate displayAlert:NO updateMenuBar:NO];
                    [self turnOnTask:item withStartDate:startDate displayAlert:NO updateMenuBar:NO];
                } else {
                    NSLog(@"BIG TIME ERROR - app wants to set end time prior to start time - start %@, stop %@", startDate, stopDate);
                }
            }
            
            // only update task timers when menu is open
            if (menuOpen) {
                NSDictionary *itemData = [item representedObject];
                NSString *title = [itemData objectForKey:@"title"];
                
                int duration = (int) ((long) [[NSDate date] timeIntervalSince1970] - (long) [item tag]);
                NSString *time = [self formattedStringForDuration:duration returnIn:NSDateOutputHuman];
                
                // show duration in red smaller font
                [item setAttributedTitle:[self getAttributedStringFromTitle:title andSubtitle:time]];
            }
        }
        
        //[statusMenu removeItem:item];
    }

    // calculate time for previous and current running tasks
    unsigned int duration = [databaseHelper getDurationFromCompletedTasksWithCurrentTasks:databaseObjects];

    NSLog(@"duration end %i", duration);

    // update the status text when menu is open
    if (menuOpen) {
        [statusItem setTitle:[NSString stringWithFormat:@"Time today %@", [self formattedStringForDuration:duration returnIn:NSDateOutputHuman]]];
    }
    
    [statusBar setTitle:[self formattedStringForDuration:duration returnIn:NSDateOutputDecimal]];
}
                                
- (IBAction)addNoteClicked:(id)sender {
    NSString *activity = [self input:@"Describe the work that you performed:"];
    NSLog(@"Add Note dialog returned: %@", activity);
    
    // apply note to all active timesheets
    for (NSMenuItem *item in [statusMenu itemArray]) {
        if (item.tag > 0) {
            NSDictionary *itemData = [item representedObject];
            [databaseHelper addNote:activity ToTimesheet:[itemData objectForKey:@"objectId"]];
        }
    }
}

- (NSString *)input:(NSString *)prompt {
    BOOL running = NO;
    for (NSMenuItem *item in [statusMenu itemArray]) {
        if (item.tag > 0) {
            running = YES;
        }
    }
    
    if (running) {
        NSAlert *alert = [NSAlert alertWithMessageText:prompt defaultButton:@"OK" alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:@""];
        
        NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
        [alert setAccessoryView:input];
        
        [[[statusBar view] window] makeFirstResponder:input];
        [input becomeFirstResponder];
        
        [[[statusBar view] window] becomeFirstResponder];
        
        NSInteger button = [alert runModal];
        if (button == NSAlertDefaultReturn) {
            [input validateEditing];
            return [input stringValue];
        } else if (button == NSAlertAlternateReturn) {
            return nil;
        } else {
            //NSAssert1(NO, @"Invalid input dialog button %d", button);
            return nil;
        }
    }
    
    return nil;
}

- (void)updateStatusIcons {
    BOOL running = NO;
    for (NSMenuItem *item in [statusMenu itemArray]) {
        if (item.tag > 0) {
            running = YES;
        }
    }
    
    if (running) {
        [statusBar setImage:[NSImage imageNamed:@"Running"]];
        [statusBar setAlternateImage:[NSImage imageNamed:@"RunningSelected"]];
    } else {
        [statusBar setImage:[NSImage imageNamed:@"Idle"]];
        [statusBar setAlternateImage:[NSImage imageNamed:@"IdleSelected"]];
    }
}

- (NSMutableAttributedString *)getAttributedStringFromTitle:(NSString *)title andSubtitle:(NSString *)subtitle {
    NSString *title2 = [NSString stringWithFormat:@"%@  %@", title, subtitle];
    NSMutableAttributedString *str = [[NSMutableAttributedString alloc] initWithString:title2];
    [str setAttributes:@{ NSForegroundColorAttributeName :[NSColor redColor] } range:NSMakeRange([title length] + 2, [subtitle length])];
    [str setAttributes:@{ NSFontAttributeName : [NSFont menuBarFontOfSize:14] } range:NSMakeRange(0, [title length] )];
    return str;
}

@end
