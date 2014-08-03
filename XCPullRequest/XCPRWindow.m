//
//  XCPRWindow.m
//  XCPullRequest
//
//  Created by Kevin Bradley on 7/30/14.
//  Copyright (c) 2014 nito. All rights reserved.
//

#import "XCPRWindow.h"

@implementation XCPRWindow

@synthesize ourBundle, companionMenuItem;

- (void)setRepresentedFilename:(NSString *)aString
{
    [super setRepresentedFilename:aString];
    //NSImage* img = [[NSImage alloc] initWithContentsOfFile:[ourBundle pathForResource:@"xcode-project_Icon" ofType:@"png"]];
    //NSLog(@"######## image: %@", img);
    //[[self standardWindowButton:NSWindowDocumentIconButton] setImage:img];
}

- (void)setRepresentedURL:(NSURL *)url
{
    [super setRepresentedURL:url];
   // NSImage* img = [[NSImage alloc] initWithContentsOfFile:[ourBundle pathForResource:@"xcode-project_Icon" ofType:@"png"]];
    //NSLog(@"######## image: %@", img);
    //[[self standardWindowButton:NSWindowDocumentIconButton] setImage:img];
}

@end
