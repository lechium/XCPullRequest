//
//  TSSCategories.h
//  TSSAgent
//
//  Created by Kevin Bradley on 6/22/13.
//  Copyright 2013 nito. All rights reserved.
//

static NSString *const kXCPullRequestBoundary =      @"D6FD4EDD-3853-4426-B9E3-47E2EE0D1671";

@interface NSDictionary (pullreq)

- (NSString *)stringFromDictionary;

@end

@interface NSArray (pullreq)

- (NSString *)stringFromArray;

@end



@interface NSString (pullreq)

- (id)dictionaryFromString;
+ (NSString *)uniqueID;
@end
