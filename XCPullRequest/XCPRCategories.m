//
//  TSSCategories.m
//  TSSAgent
//
//  Created by Kevin Bradley on 6/22/13.
//  Copyright 2013 nito. All rights reserved.
//

#import "XCPRCategories.h"

@implementation NSDictionary (pullreq)

- (NSString *)stringFromDictionary
{
	NSString *error = nil;
	NSData *xmlData = [NSPropertyListSerialization dataFromPropertyList:self format:NSPropertyListXMLFormat_v1_0 errorDescription:&error];
	NSString *s=[[NSString alloc] initWithData:xmlData encoding: NSUTF8StringEncoding];
	return s;
}

@end

@implementation NSArray (pullreq)

- (NSString *)stringFromArray
{
	NSString *error = nil;
	NSData *xmlData = [NSPropertyListSerialization dataFromPropertyList:self format:NSPropertyListXMLFormat_v1_0 errorDescription:&error];
	NSString *s=[[NSString alloc] initWithData:xmlData encoding: NSUTF8StringEncoding];
	return s;
}

@end


@implementation NSString (pullreq)

/*
 
 we use this to convert a raw dictionary plist string into a proper NSDictionary
 
 */

- (id)dictionaryFromString
{
	NSString *error = nil;
	NSPropertyListFormat format;
	NSData *theData = [self dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
	id theDict = [NSPropertyListSerialization propertyListFromData:theData
												  mutabilityOption:NSPropertyListImmutable
															format:&format
												  errorDescription:&error];
	return theDict;
}

+ (NSString *)uniqueID
{
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    CFStringRef uuidString = CFUUIDCreateString(NULL, uuid);
    NSString *cleanupString = (__bridge NSString*)uuidString;
    CFRelease(uuid);
    CFRelease(uuidString);
    return cleanupString;
}


@end

