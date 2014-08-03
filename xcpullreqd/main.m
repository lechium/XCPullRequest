//
//  main.m
//  pullreqd
//
//  Created by Kevin Bradley on 6/27/14.
//  Copyright (c) 2014 nito. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XCPRHelperClass.h"

int main(int argc, const char * argv[])
{
    
    @autoreleasepool {
        
        NSLog(@"argc: %i", argc);
        if (argc < 3) {
            NSLog(@"not enough arguments!");
            return -1;
        }
        
        NSString *path = [NSString stringWithUTF8String:argv[0]];
        NSString *option = [NSString stringWithUTF8String:argv[1]];
        NSString *type = [NSString stringWithUTF8String:argv[2]];
        
        NSLog(@"path: %@ options: %@ type: %@", path, option, type);
        XCPRHelperClass *helper = [[XCPRHelperClass alloc] init];
        [helper setType:type];
        [helper processFile:option];

        
    }
    return 0;
}

