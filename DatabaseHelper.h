//
//  DatabaseHelper.h
//  Timer
//
//  Created by Chris Monahan on 4/30/14.
//  Copyright 2014 Core Coding. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Note.h"
#import "Timesheet.h"

@interface DatabaseHelper : NSObject {
    
}

// CoreData objects
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

- (void)saveContext;

- (void)eraseAllContent;
- (NSArray *)grabAllEntries;
- (NSManagedObjectID *)addEntryWithDate:(NSDate *)date withTitle:(NSString *)title withClient:(NSString *)client;
- (void)addNote:(NSString *)activity ToTimesheet:(NSManagedObjectID *)object;
- (Timesheet *)getEntryFromObject:(NSManagedObjectID *)object;
- (unsigned int)getDurationFromCompletedTasksWithCurrentTasks:(NSArray *)databaseObjects;
- (void)updateSheet:(Timesheet *)sheet withEndDate:(NSDate *)theDate;

@end
