//
//  Note.h
//  Timer
//
//  Created by Chris Monahan on 8/25/14.
//  Copyright 2014 Core Coding. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Timesheet;

@interface Note : NSManagedObject

@property (nonatomic, retain) Timesheet *timesheet;
@property (nonatomic, retain) NSString *activity;

@end
