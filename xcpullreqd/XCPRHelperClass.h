//
//  XCPRHelperClass.h
//  XCPullRequestServer
//
//  Created by Kevin Bradley on 6/27/14.
//  Copyright (c) 2014 nito. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XCPRHelperClass : NSObject
{
    
}
@property (nonatomic, strong) NSString *type;
- (void)sendEmailFromPlist:(NSString *)inputFile;
- (void)processTarFile:(NSString *)tarFile;
- (void)processFile:(NSString *)theFile;
@end
