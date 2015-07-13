//
//  Timesheet.h
//  Timer
//
//  Created by Chris Monahan on 4/29/14.
//  Copyright 2014 Core Coding. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Note;

@interface Timesheet : NSManagedObject

@property (nonatomic, retain) NSSet *notes;
@property (nonatomic, retain) NSDate *start;
@property (nonatomic, retain) NSDate *end;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *client;

@end

@interface Timesheet (CoreDataGeneratedAccessors)

- (void)addNotesObject:(Note *)value;
- (void)removeNotesObject:(Note *)value;
- (void)addNotes:(NSSet *)values;
- (void)removeNotes:(NSSet *)values;

@end
