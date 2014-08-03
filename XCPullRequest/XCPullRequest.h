//
//  XCPullRequest.h
//  XCPullRequest
//
//  Created by Kevin Bradley on 6/25/14.
//  Copyright (c) 2014 nito. All rights reserved.
//

NSString* const kXCPullRequestXCServer = @"xcServerGIT";

#import <AppKit/AppKit.h>
#import "XCPRModel.h"
#import "XCPRProjectSetting.h"
#import "XCPRCategories.h"

#define PATCH_EXTENSION @"gpatch"

@interface XCPullRequest : NSObject
{
    NSMenuItem *pullReq;
    NSTextField *commentField;
    NSString *pullReqId;
    NSInteger ourMenuIndex;
    NSString *ourMenuName;

}

@property (readwrite, assign) BOOL mergeBranchMode; //if yes then we attempt to merge the branch in rather than the patch, binary diffs, etc.

@property (nonatomic, strong) NSBundle *bundle;
- (NSString *)postJSON:(NSDictionary *)postDictionary;
- (void)postFile:(NSString *)theFile;

@end