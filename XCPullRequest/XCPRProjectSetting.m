//
//  XCPRProjectSetting
//  XToDo
//
//  Created by shuice on 2014-03-08.
//  Copyright (c) 2014. All rights reserved.
//

#import "XCPRProjectSetting.h"
#import "XCPRModel.h"

@implementation XCPRProjectSetting

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.includeDirs ? self.includeDirs : @[]  forKey:@"includeDirs"];
    [aCoder encodeObject:self.excludeDirs ? self.excludeDirs : @[]  forKey:@"excludeDirs"];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        self.includeDirs = [aDecoder decodeObjectForKey:@"includeDirs"];
        self.excludeDirs = [aDecoder decodeObjectForKey:@"excludeDirs"];
    }
    return self;
}

+ (XCPRProjectSetting *) defaultProjectSetting
{
    XCPRProjectSetting *projectSetting = [[XCPRProjectSetting alloc] init];
    projectSetting.includeDirs = @[[XCPRModel rootPathMacro]];
    projectSetting.excludeDirs = @[[XCPRModel addPathSlash:[[XCPRModel rootPathMacro] stringByAppendingPathComponent:@"Pods"]]];
    return projectSetting;
}

- (NSString *)firstIncludeDir
{
    NSString *firstDir = [self.includeDirs count] ? [self.includeDirs objectAtIndex:0] : @"";
    if ([firstDir length] == 0)
    {
        firstDir = [XCPRModel rootPathMacro];
    }
    return firstDir;
}

@end
