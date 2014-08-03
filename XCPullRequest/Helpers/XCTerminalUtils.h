//
//  XCTerminalUtils.h
//  XCPullRequest
//
//  Created by Kevin Bradley on 7/26/14.
//  Copyright (c) 2014 nito. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XCTerminalUtils : NSObject

+ (NSString *)currentUserEmail;
+ (NSString *)currentUserName;
+ (NSString *)currentGITBranch;
+ (NSArray *)returnFromGITWithArguments:(NSArray *)gitArguments;
+ (void)createGITPatch:(NSString *)outputFile withArguments:(NSArray *)commandArguments;
+ (NSArray *)returnFromCommand:(NSString *)commandBinary withArguments:(NSArray *)commandArguments inPath:(NSString *)thePath;
+ (NSArray *)returnForProcess:(NSString *)call;
+ (NSString *)stringReturnForProcess:(NSString *)call;

@end
