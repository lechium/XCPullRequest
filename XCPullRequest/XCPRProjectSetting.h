//
//  XCPRProjectSetting
//  XToDo / XCPullRequest
//
//  Created by shuice on 2014-03-08.
//  Updated by Kevin Bradley
//  Copyright (c) 2014. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface XCPRProjectSetting : NSObject<NSCoding>
@property NSArray  *includeDirs;
@property NSArray  *excludeDirs;
+ (XCPRProjectSetting *) defaultProjectSetting;
- (NSString *) firstIncludeDir;
@end