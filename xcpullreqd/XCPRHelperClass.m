//
//  XCPRHelperClass.m
//  XCPullRequestServer
//
//  Created by Kevin Bradley on 6/27/14.
//  Copyright (c) 2014 nito. All rights reserved.
//

#import "XCPRHelperClass.h"
#import <AppKit/AppKit.h>

@implementation XCPRHelperClass
@synthesize type;

- (NSString *)applicationSupportFolder
{
    NSString *supportFolder = [NSHomeDirectory() stringByAppendingPathComponent:@"XCPullRequests"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:supportFolder])
    {
        [[NSFileManager defaultManager]createDirectoryAtPath:supportFolder withIntermediateDirectories:TRUE attributes:nil error:nil];
    }
    return supportFolder;
}

- (void)processFile:(NSString *)theFile
{
    if ([[self type] isEqualToString:@"plist"])
    {
        NSLog(@"send email from plist!!");
        [self sendEmailFromPlist:theFile];
    } else if ([[self type] isEqualToString:@"tgz"])
    {
        [self processTarFile:theFile];
    }
}

- (void)processTarFile:(NSString *)tarFile
{
    NSString *newTarFile = [tarFile lastPathComponent];
    NSString *untarString = [NSString stringWithFormat:@"pwd ; pushd uploads ; /usr/bin/tar fxpz '%@'", newTarFile];
   
    int sysReturn = system([untarString UTF8String]);
	int actualReturn = WEXITSTATUS(sysReturn);
	NSLog(@"processTarFile finished with status: %i", actualReturn);
    if (actualReturn == 0)
    {
        NSString *newBundlePath = [[tarFile stringByDeletingPathExtension] stringByAppendingPathExtension:@"bundle"];
        NSLog(@"new bundle path: %@", newBundlePath);
         [self processBundle:newBundlePath];
    }
}

- (void)processBundle:(NSString *)bundlePath
{
    NSBundle *pullBundle = [NSBundle bundleWithPath:bundlePath];
    [self sendEmailFromBundle:pullBundle];
}

- (NSString *)fancyPatchName:(NSBundle *)theBundle
{
    //   NSString *email = [[theBundle infoDictionary] objectForKey:@"Email"];
    // NSString *appendedName = [NSString stringWithFormat:@"%@_%@", [[[theBundle bundlePath] lastPathComponent] stringByDeletingPathExtension], email ];
    return [[[[theBundle bundlePath] lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"gpatch"];
}
- (NSString *)webRoot
{
    return @"/Library/Server/Web/Data/Sites/Default/";
}



- (NSString *)emailAdminsString
{
    NSArray *adminArray = [NSArray arrayWithContentsOfFile:[[self webRoot] stringByAppendingPathComponent:@"pull_admins.plist"]];
   // NSString *emailAdminsFile = [NSString stringWithContentsOfFile:[[self webRoot] stringByAppendingPathComponent:@"pull_admins.plist"] encoding:NSUTF8StringEncoding error:nil];
    // NSString *emailAdminsFile = [NSString stringWithContentsOfURL:[NSURL URLWithString:@"http://macgitserver/pull_admins"] encoding:NSUTF8StringEncoding error:nil];
  //  NSArray *adminArray = [emailAdminsFile componentsSeparatedByString:@"\n"];
    if ([adminArray count] == 0)
    {
        return @"nowhere@email.com";
    }
    NSMutableString *finalString = [[NSMutableString alloc] init];
    int adminNumber = 0;
    for (NSString *admin in adminArray)
    {
        if (adminNumber == 0)
        {
            [finalString appendFormat:@"%@ -c ", admin];
            
        } else if ([adminArray count] != (adminNumber + 1)){
            
            [finalString appendFormat:@"%@,", admin];
            
        } else {
            
            [finalString appendFormat:@"%@", admin];
            
        } 
        adminNumber++;
    }
    return finalString;
}

- (void)sendEmailFromPlist:(NSString *)inputFile
{
    NSDictionary *projectDict = [NSDictionary dictionaryWithContentsOfFile:inputFile];
   // NSString *hostName = [[NSHost currentHost] localizedName];
    NSLog(@"sendEmailFromPlist: %@", inputFile);
    NSString *rootPath = @"/private/var/tmp";
    NSString *projectName = projectDict[@"ProjectName"];
    NSString *projectBranch = projectDict[@"ProjectBranch"];
    NSString *commitComment = projectDict[@"Comment"];
    NSString *emailOutputPath = [rootPath stringByAppendingPathComponent:@"body.txt"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:emailOutputPath])
    {
        [[NSFileManager defaultManager] removeItemAtPath:emailOutputPath error:nil];
    }
    NSMutableString *emailBody = [[NSMutableString alloc] init];
    if (commitComment.length > 0)
    {
        [emailBody appendFormat:@"Hello,\n\n\t%@ has %@ your pull request from the branch '%@' on the project '%@'\n\nWith the following comment:\n\n '%@'\n\n", projectDict[@"ResponseUser"], projectDict[@"Status"], projectBranch, projectName, commitComment];
    } else {
        [emailBody appendFormat:@"Hello,\n\n\t%@ has %@ your pull request from the branch '%@' on the project '%@'\n\n", projectDict[@"ResponseUser"], projectDict[@"Status"], projectBranch, projectName];
    }
  //  [emailBody appendString:@"Please review at your earliest convenience. Thanks!\n\n"];
    NSError *writeFile = nil;
    [emailBody writeToFile:emailOutputPath atomically:TRUE encoding:NSUTF8StringEncoding error:&writeFile];
  //  NSLog(@"emailBody written with error: %@", writeFile);
    NSString *systemMailHack = [NSString stringWithFormat:@"cat \'%@\' | mail -s \"Pull Request for %@ %@\" %@",  emailOutputPath, projectName, projectDict[@"Status"], projectDict[@"Email"]];
    system([systemMailHack UTF8String]);
}

- (void)sendEmailFromBundle:(NSBundle *)inputBundle
{
    NSString *hostName = [[NSHost currentHost] localizedName];
    NSLog(@"sendEmailFromBundle: %@", [inputBundle bundlePath]);
    NSString *emailAdmins = [self emailAdminsString];
    NSDictionary *sourceControlDict = [inputBundle infoDictionary];
    NSString *patchPath = [inputBundle pathForResource:@"patch" ofType:@"gpatch"];
    NSString *rootPath = @"/private/var/tmp";
    NSString *projectName = sourceControlDict[@"ProjectName"];
    NSString *projectBranch = sourceControlDict[@"ProjectBranch"];
    NSString *commitComment = sourceControlDict[@"Comment"];
    NSString *emailOutputPath = [rootPath stringByAppendingPathComponent:@"body.txt"];
    NSMutableString *emailBody = [[NSMutableString alloc] init];
    [emailBody appendFormat:@"Hello,\n\n\tThe following pull request has been submitted for review on the branch '%@' on the project '%@'\n\nWith the following comment:\n\n '%@'\n\n", projectBranch, projectName, commitComment];
    [emailBody appendString:@"Please review at your earliest convenience. Thanks!\n\n"];
    NSError *writeFile = nil;
    [emailBody writeToFile:emailOutputPath atomically:TRUE encoding:NSUTF8StringEncoding error:&writeFile];
 //   NSLog(@"emailBody written with error: %@", writeFile);
    NSString *systemMailHack = [NSString stringWithFormat:@"(cat \'%@\'; uuencode \'%@\' %@) | mail -s \"%@ Pull Request for %@\" %@",  emailOutputPath, patchPath, [self fancyPatchName:inputBundle], hostName, projectName, emailAdmins];
   //  NSLog(@"systemMailHack %@", systemMailHack);
    system([systemMailHack UTF8String]);
}


@end
