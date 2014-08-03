//
//  XCTerminalUtils.m
//  XCPullRequest
//
//  Created by Kevin Bradley on 7/26/14.
//  Copyright (c) 2014 nito. All rights reserved.
//

#import "XCTerminalUtils.h"
#import "XCPRModel.h"

@implementation XCTerminalUtils

+ (NSString *)currentUserEmail
{
    return [[self returnFromGITWithArguments:[NSArray arrayWithObjects:@"config", @"--get", @"user.email", nil]] objectAtIndex:0];
}

+ (NSString *)currentUserName
{
    return [[self returnFromGITWithArguments:[NSArray arrayWithObjects:@"config", @"--get", @"user.name", nil]] objectAtIndex:0];
}

+ (NSString *)currentGITBranch
{
    NSString *currentBranch = nil;
    NSArray *branchArray = [self returnFromGITWithArguments:[NSArray arrayWithObjects:@"branch", @"--list", nil]];
    for (NSString *branchItem in branchArray)
    {
        if ([branchItem rangeOfString:@"*"].location != NSNotFound)
            currentBranch = [branchItem substringFromIndex:2];
    }
    return currentBranch;
}

+ (NSString *)stringReturnForProcess:(NSString *)call
{
    NSArray *returnForProc = [self returnForProcess:call];
    return [returnForProc componentsJoinedByString:@"\n"];
}

+ (NSArray *)returnFromGITWithArguments:(NSArray *)gitArguments
{
    NSString *rootPath = [XCPRModel currentRootPath];
    if (rootPath == nil) rootPath = @"/";
    return [self returnFromCommand:@"/usr/bin/git" withArguments:gitArguments inPath:rootPath];
}

+ (void)createGITPatch:(NSString *)outputFile withArguments:(NSArray *)commandArguments
{
    NSPipe *pipe = [[NSPipe alloc] init];
	NSFileHandle *hdhandle = [pipe fileHandleForReading];
    NSTask *mnt = [[NSTask alloc] init];
    [mnt setCurrentDirectoryPath:[XCPRModel currentRootPath]];
    [mnt setLaunchPath:@"/usr/bin/git"];
    [mnt setArguments:commandArguments];
	[mnt setStandardOutput:pipe];
	[mnt setStandardError:pipe];
	[mnt launch];
	NSData *outData = [hdhandle readDataToEndOfFile];
	[mnt waitUntilExit];
	NSFileHandle *aFileHandle = [NSFileHandle fileHandleForWritingAtPath:outputFile];            //telling aFilehandle what file write to
    [aFileHandle truncateFileAtOffset:[aFileHandle seekToEndOfFile]];          //setting aFileHandle to write at the end of the file
    [aFileHandle writeData:outData];                        //actually write the data
	[aFileHandle synchronizeFile];
	[aFileHandle closeFile];
	mnt = nil;
	pipe = nil;
	
}

+ (NSArray *)returnFromCommand:(NSString *)commandBinary withArguments:(NSArray *)commandArguments inPath:(NSString *)thePath
{
    NSTask *mnt = [[NSTask alloc] init];
    NSPipe *pip = [[NSPipe alloc] init];;
    NSFileHandle *handle = [pip fileHandleForReading];
    NSData *outData;
    [mnt setCurrentDirectoryPath:thePath];
    [mnt setLaunchPath:commandBinary];
    [mnt setArguments:commandArguments];
    [mnt setStandardError:pip];
    [mnt setStandardOutput:pip];
    [mnt launch];
    
    NSString *temp;
    NSMutableArray *lineArray = [[NSMutableArray alloc] init];
    while((outData = [handle readDataToEndOfFile]) && [outData length])
    {
        temp = [[NSString alloc] initWithData:outData encoding:NSASCIIStringEncoding];
        [lineArray addObjectsFromArray:[temp componentsSeparatedByString:@"\n"]];
    }
    temp = nil;
    if ([lineArray count] ==0)
    {
        return [NSArray arrayWithObject:@""]; //idiot proofing
    }
    return lineArray;
}

+ (NSArray *)returnForProcess:(NSString *)call
{
    if (call==nil)
        return 0;
    char line[200];
    
    FILE* fp = popen([call UTF8String], "r");
    NSMutableArray *lines = [[NSMutableArray alloc]init];
    if (fp)
    {
        while (fgets(line, sizeof line, fp))
        {
            NSString *s = [NSString stringWithCString:line encoding:NSUTF8StringEncoding];
            s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            [lines addObject:s];
        }
    }
    pclose(fp);
    return lines;
}

@end
