//
//  NetworkHelper.m
//  Timer
//
//  Created by Chris Monahan on 5/4/14.
//  Copyright (c) 2014 Core Coding. All rights reserved.
//

#import "NetworkHelper.h"
#include <SystemConfiguration/SCNetworkReachability.h>
#import <CoreFoundation/CoreFoundation.h>
#include <sys/sysctl.h>
#include <net/if_dl.h>
#include <net/route.h>
#include <netinet/if_ether.h>
#include <arpa/inet.h>
#include <err.h>
#include <netdb.h>
#import <ifaddrs.h>
#import <sys/socket.h>

NSString *kReachabilityChangedNotification = @"kNetworkReachabilityChangedNotification";

#pragma mark - NetworkHelper implementation

@implementation NetworkHelper {
//    BOOL _alwaysReturnLocalWiFiStatus; //default is NO
    SCNetworkReachabilityRef _reachabilityRef;
}

- (int)checkForMacAddress:(NSDictionary *)macToTasks {
    int mib[6];
    size_t needed;
    char *lim, *buf, *next;
    struct rt_msghdr *rtm;
    struct sockaddr_inarp *sin;
    struct sockaddr_dl *sdl;
    extern int h_errno;
    
    mib[0] = CTL_NET;
    mib[1] = PF_ROUTE;
    mib[2] = 0;
    mib[3] = AF_INET;
    mib[4] = NET_RT_FLAGS;
    mib[5] = RTF_LLINFO;
    
    if (sysctl(mib, 6, NULL, &needed, NULL, 0) < 0) err(1, "route-sysctl-estimate");
    if ((buf = malloc(needed)) == NULL) err(1, "malloc");
    if (sysctl(mib, 6, buf, &needed, NULL, 0) < 0) err(1, "actual retrieval of routing table");
    lim = buf + needed;
    
    for (next = buf; next < lim; next += rtm->rtm_msglen) {
        rtm = (struct rt_msghdr *)next;
        sin = (struct sockaddr_inarp *)(rtm + 1);
        sdl = (struct sockaddr_dl *)(sin + 1);
        
        if (sdl->sdl_alen) {
            NSString *macAddress = [NSString stringWithFormat:@"%x:%x:%x:%x:%x:%x", (u_char)LLADDR(sdl)[0], (u_char)LLADDR(sdl)[1], (u_char)LLADDR(sdl)[2], (u_char)LLADDR(sdl)[3], (u_char)LLADDR(sdl)[4], (u_char)LLADDR(sdl)[5]];
            
            for (NSString *key in [macToTasks allKeys]) {
                if ([key isEqualToString:macAddress]) {
                    return [[macToTasks objectForKey:key] intValue];
                }
            }
        }
    }
    
    return 0;
}

- (BOOL)isInternetConnection {
    BOOL returnValue = NO;
    
    struct sockaddr zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sa_len = sizeof(zeroAddress);
    zeroAddress.sa_family = AF_INET;
    
    SCNetworkReachabilityRef reachabilityRef = SCNetworkReachabilityCreateWithAddress(NULL, (const struct sockaddr*)&zeroAddress);
    if (reachabilityRef != NULL) {
        SCNetworkReachabilityFlags flags = 0;
        
        if (SCNetworkReachabilityGetFlags(reachabilityRef, &flags)) {
            BOOL isReachable = ((flags & kSCNetworkFlagsReachable) != 0);
            BOOL connectionRequired = ((flags & kSCNetworkFlagsConnectionRequired) != 0);
            returnValue = (isReachable && !connectionRequired) ? YES : NO;
        }
        
        CFRelease(reachabilityRef);
    }
    
    return returnValue;
}

#pragma mark - Supporting functions

//#define kShouldPrintReachabilityFlags 1

//static void PrintReachabilityFlags(SCNetworkReachabilityFlags flags, const char *comment) {
//#if kShouldPrintReachabilityFlags
//    
//    NSLog(@"Reachability Flag Status: %c %c%c%c%c%c%c%c %s\n",
//          //          (flags & kSCNetworkReachabilityFlagsIsWWAN)				? 'W' : '-',
//          (flags & kSCNetworkReachabilityFlagsReachable)            ? 'R' : '-',
//          
//          (flags & kSCNetworkReachabilityFlagsTransientConnection)  ? 't' : '-',
//          (flags & kSCNetworkReachabilityFlagsConnectionRequired)   ? 'c' : '-',
//          (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic)  ? 'C' : '-',
//          (flags & kSCNetworkReachabilityFlagsInterventionRequired) ? 'i' : '-',
//          (flags & kSCNetworkReachabilityFlagsConnectionOnDemand)   ? 'D' : '-',
//          (flags & kSCNetworkReachabilityFlagsIsLocalAddress)       ? 'l' : '-',
//          (flags & kSCNetworkReachabilityFlagsIsDirect)             ? 'd' : '-',
//          comment
//          );
//#endif
//}

static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {
#pragma unused (target, flags)
    NSCAssert(info != NULL, @"info was NULL in ReachabilityCallback");
    NSCAssert([(__bridge NSObject*) info isKindOfClass: [NetworkHelper class]], @"info was wrong class in ReachabilityCallback");
    
    NetworkHelper *noteObject = (__bridge NetworkHelper *)info;
    // Post a notification to notify the client that the network reachability changed.
    [[NSNotificationCenter defaultCenter] postNotificationName: kReachabilityChangedNotification object: noteObject];
}

//+ (instancetype)reachabilityWithHostName:(NSString *)hostName
//{
//	NetworkHelper* returnValue = NULL;
//	SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, [hostName UTF8String]);
//	if (reachability != NULL)
//	{
//		returnValue= [[self alloc] init];
//		if (returnValue != NULL)
//		{
//			returnValue->_reachabilityRef = reachability;
//			returnValue->_alwaysReturnLocalWiFiStatus = NO;
//		}
//	}
//	return returnValue;
//}

+ (instancetype)reachabilityWithAddress:(const struct sockaddr_in *)hostAddress {
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)hostAddress);
    
    NetworkHelper *returnValue = NULL;
    if (reachability != NULL) {
        returnValue = [[self alloc] init];
        if (returnValue != NULL) {
            returnValue->_reachabilityRef = reachability;
//            returnValue->_alwaysReturnLocalWiFiStatus = NO;
        }
    }
    
    return returnValue;
}

+ (instancetype)reachabilityForInternetConnection {
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    
    return [self reachabilityWithAddress:&zeroAddress];
}

//+ (instancetype)reachabilityForLocalWiFi
//{
//	struct sockaddr_in localWifiAddress;
//	bzero(&localWifiAddress, sizeof(localWifiAddress));
//	localWifiAddress.sin_len = sizeof(localWifiAddress);
//	localWifiAddress.sin_family = AF_INET;
//
//	// IN_LINKLOCALNETNUM is defined in <netinet/in.h> as 169.254.0.0.
//	localWifiAddress.sin_addr.s_addr = htonl(IN_LINKLOCALNETNUM);
//
//	NetworkHelper* returnValue = [self reachabilityWithAddress: &localWifiAddress];
//	if (returnValue != NULL)
//	{
//		returnValue->_alwaysReturnLocalWiFiStatus = YES;
//	}
//
//	return returnValue;
//}

#pragma mark - Start and stop notifier

- (BOOL)startNotifier {
    BOOL returnValue = NO;
    SCNetworkReachabilityContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
    
    if (SCNetworkReachabilitySetCallback(_reachabilityRef, ReachabilityCallback, &context)) {
        if (SCNetworkReachabilityScheduleWithRunLoop(_reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)) {
            returnValue = YES;
        }
    }
    
    return returnValue;
}

- (void)stopNotifier {
    if (_reachabilityRef != NULL) {
        SCNetworkReachabilityUnscheduleFromRunLoop(_reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    }
}

- (void)dealloc {
    [self stopNotifier];
    if (_reachabilityRef != NULL) {
        CFRelease(_reachabilityRef);
    }
}

#pragma mark - Network Flag Handling

//- (NetworkStatus)localWiFiStatusForFlags:(SCNetworkReachabilityFlags)flags
//{
//	PrintReachabilityFlags(flags, "localWiFiStatusForFlags");
//	NetworkStatus returnValue = NotReachable;
//
//	if ((flags & kSCNetworkReachabilityFlagsReachable) && (flags & kSCNetworkReachabilityFlagsIsDirect))
//	{
//		returnValue = ReachableViaWiFi;
//	}
//
//	return returnValue;
//}

- (NetworkStatus)networkStatusForFlags:(SCNetworkReachabilityFlags)flags {
    //PrintReachabilityFlags(flags, "networkStatusForFlags");
    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0) {
        // The target host is not reachable.
        return NotReachable;
    }
    
    NetworkStatus returnValue = NotReachable;
    
    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0) {
        /*
         If the target host is reachable and no connection is required then we'll assume (for now) that you're on Wi-Fi...
         */
        returnValue = ReachableViaWiFi;
    }
    
    if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) || (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0)) {
        /*
         ... and the connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs...
         */
        
        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0) {
            /*
             ... and no [user] intervention is needed...
             */
            returnValue = ReachableViaWiFi;
        }
    }
    
    //	if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN)
    //		/*
    //         ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.
    //         */
    //		returnValue = ReachableViaWWAN;
    //	}
    
    return returnValue;
}

//- (BOOL)connectionRequired {
//    NSAssert(_reachabilityRef != NULL, @"connectionRequired called with NULL reachabilityRef");
//    SCNetworkReachabilityFlags flags;
//    
//    if (SCNetworkReachabilityGetFlags(_reachabilityRef, &flags)) {
//        return (flags & kSCNetworkReachabilityFlagsConnectionRequired);
//    }
//    
//    return NO;
//}

- (NetworkStatus)currentReachabilityStatus {
    NSAssert(_reachabilityRef != NULL, @"currentNetworkStatus called with NULL SCNetworkReachabilityRef");
    NetworkStatus returnValue = NotReachable;
    SCNetworkReachabilityFlags flags;
    
    if (SCNetworkReachabilityGetFlags(_reachabilityRef, &flags)) {
        //		if (_alwaysReturnLocalWiFiStatus)
        //		{
        //			returnValue = [self localWiFiStatusForFlags:flags];
        //		}
        //		else
        //		{
        returnValue = [self networkStatusForFlags:flags];
        //		}
    }
    
    return returnValue;
}

@end
