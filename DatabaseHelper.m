//
//  Database.m
//  Timer
//
//  Created by Chris Monahan on 4/30/14.
//  Copyright 2014 Core Coding. All rights reserved.
//

#import "DatabaseHelper.h"

@implementation DatabaseHelper

@synthesize managedObjectContext = __managedObjectContext;
@synthesize managedObjectModel = __managedObjectModel;
@synthesize persistentStoreCoordinator = __persistentStoreCoordinator;

#pragma mark - Core Data stack

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext {
    if (__managedObjectContext != nil) {
        return __managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        __managedObjectContext = [[NSManagedObjectContext alloc] init];
        [__managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    
    return __managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel {
    if (__managedObjectModel != nil) {
        return __managedObjectModel;
    }
    
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Database" withExtension:@"momd"];
    __managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return __managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (__persistentStoreCoordinator != nil) {
        return __persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationSupportDirectory] URLByAppendingPathComponent:@"Timer.sqlite"];
    
    NSError *error = nil;
    __persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![__persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return __persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationSupportDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject];
}

- (void)saveContext {
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

- (void)eraseAllContent {
    NSURL *storeURL = [[self applicationSupportDirectory] URLByAppendingPathComponent:@"Timer.sqlite"];
    
    // If you encounter schema incompatibility errors during development, you can reduce their frequency by: Simply deleting the existing store:
    [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil];
}

- (NSArray *)grabAllEntries {
    // Test listing all FailedBankInfos from the store
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSManagedObjectContext *context = [self managedObjectContext];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Timesheet" inManagedObjectContext:context];
    [fetchRequest setEntity:entity];
    
    NSError *error;
    return [context executeFetchRequest:fetchRequest error:&error];
}

- (NSManagedObjectID *)addEntryWithDate:(NSDate *)date withTitle:(NSString *)title withClient:(NSString *)client {
    NSManagedObjectContext *context = [self managedObjectContext];
    Timesheet *timesheet = [NSEntityDescription insertNewObjectForEntityForName:@"Timesheet" inManagedObjectContext:context];
    timesheet.start = date;
    timesheet.title = title;
    timesheet.client = client;
    
    NSError *error;
    if (![context save:&error]) {
        NSLog(@"Whoops, couldn't save: %@", [error localizedDescription]);
    }
    
    return [timesheet objectID];
}

- (void)addNote:(NSString *)activity ToTimesheet:(NSManagedObjectID *)object {
    NSManagedObjectContext *context = [self managedObjectContext];
    Note *note = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:context];
    [note setActivity:activity];
    
    Timesheet *timesheet = [self getEntryFromObject:object];
    [timesheet addNotesObject:note];
    
    NSError *error;
    if (![context save:&error]) {
        NSLog(@"Whoops, couldn't save: %@", [error localizedDescription]);
    }
}

- (Timesheet *)getEntryFromObject:(NSManagedObjectID *)object {
    // Test listing all FailedBankInfos from the store
    NSManagedObjectContext *context = [self managedObjectContext];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Timesheet" inManagedObjectContext:context];

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:entity];

    NSError *error;
    Timesheet *sheet = (Timesheet *)[context existingObjectWithID:object error:&error];

    [sheet setEnd:[NSDate date]];
    if (![context save:&error]) {
        NSLog(@"Whoops, couldn't save: %@", [error localizedDescription]);
    }

    return sheet;
}

- (unsigned int)getDurationFromCompletedTasksWithCurrentTasks:(NSArray *)databaseObjects {
    unsigned int duration = 0;
    long lastStart = 0;
    long lastEnd = 0;
    
    // calculate day of year for today's date
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSUInteger dayOfYear = [gregorian ordinalityOfUnit:NSDayCalendarUnit inUnit:NSYearCalendarUnit forDate:[NSDate date]];

    // loop over previous tasks and add to the overall duration
    NSManagedObjectContext *context = [self managedObjectContext];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Timesheet" inManagedObjectContext:context];

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:entity];
    
    NSError *error;
    NSArray *fetchedObjects = [context executeFetchRequest:fetchRequest error:&error];
    for (Timesheet *sheet in fetchedObjects) {
        // now that we have valid dates we can calculate the day of year
        NSUInteger sheetDayOfYear = [gregorian ordinalityOfUnit:NSDayCalendarUnit inUnit:NSYearCalendarUnit forDate:sheet.start];
        
        // is this entry from today?
        if (dayOfYear == sheetDayOfYear) {
            // calculate start and end times in unix time
            long start = [sheet.start timeIntervalSince1970];
            long end = [sheet.end timeIntervalSince1970];

            // if this database object is still selected - use current date as end date regardless if it's null or has a date
            if ([databaseObjects containsObject:[sheet objectID]]) {
                //NSLog(@"found invalid sheet, start %@, end %@ - using current time for end - TODO - need to make sure task is active!", sheet.start, sheet.end);
                end = [[NSDate date] timeIntervalSince1970];
            }
            
            // this timestamp entry may still be open
            if (end == 0) {
                NSLog(@"found invalid sheet, start %@, end %@ - using current time for end", sheet.start, sheet.end);
               // end = [[NSDate date] timeIntervalSince1970];
            }
            
            // make sure we have a valid task start date and end date
            if (end < start) {
                NSLog(@"found invalid sheet, start %@, end %@", sheet.start, sheet.end);
                continue;
            }
            
            if (!lastStart && !lastEnd) {
                // we don't have entries yet, save current values
                lastStart = start;
                lastEnd = end;
            } else if (start >= lastStart && start <= lastEnd && end >= lastEnd) {
                // start date falls in the middle of the previous range, extend end time to new end time
                lastEnd = end;
            } else if (end >= lastStart && end <= lastEnd && start <= lastStart) {
                // end date falls in the middle of the previous range, use new start time
                lastStart = start;
            } else if (start <= lastStart && end >= lastEnd) {
                // start and end date extend beyond previous range, extend both
                lastStart = start;
                lastEnd = end;
            } else if (start >= lastStart && end <= lastEnd) {
                // start and end date fall in between previous range, don't do anything
            } else {
                duration += (long) lastEnd - (long) lastStart;
                lastStart = start;
                lastEnd = end;
            }
        }
    }

    // make sure we capture the last value from the loop
    duration += (long) lastEnd - (long) lastStart;
    
    return duration;
}

- (void)updateSheet:(Timesheet *)sheet withEndDate:(NSDate *)theDate {
    [sheet setEnd:theDate];

    NSError *error;
    NSManagedObjectContext *context = [self managedObjectContext];
    if (![context save:&error]) {
        NSLog(@"Whoops, couldn't save: %@", [error localizedDescription]);
    }
}

@end
