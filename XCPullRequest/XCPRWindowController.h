//
//  XCPRWindowController.h
//  XTrello
//
//  Created by Kevin Bradley on 7/14/14.
//  Copyright (c) 2014 nito. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "NoodleLineNumberView.h"
#import "NSColor+Hex.h"
#import "XCPRWindow.h"

@protocol XCPRWindowControllerDelegate <NSObject>

- (void)setMergeBranchMode:(BOOL)mbm;
- (BOOL)mergeBranchMode;
- (NSString *)emailDevsString;
- (NSString *)postJSON:(NSDictionary *)postDictionary;
- (NSString *)defaultServerAddress;
- (void)postFile:(NSString *)theFile;
- (NSBundle *)bundle;
- (void)windowDidClose;
@end

@interface XCPRWindowController : NSWindowController <NSWindowDelegate>
{
    IBOutlet NSTextView *patchTextView;
    IBOutlet NSScrollView *patchScrollView;
    NSTextField *rejectTextField;
    NSString *patchFileName;
    NSString *patchFilePath;
    NSString *submittersEmail;
    IBOutlet NSMenuItem *openWith;
    IBOutlet NSMenuItem *openWith2;
    NoodleLineNumberView	*lineNumberView;
    NSDictionary *plistDict;
    IBOutlet NSToolbarItem *mergeItem;
}
@property (nonatomic, assign) id delegate;

@property (readwrite, assign) BOOL patchEnabled;
@property (strong, nonatomic) NSString *lastSearchString;
@property (strong, nonatomic) NSString *lastReplacementString;
@property (strong, nonatomic) NSDictionary *lastSearchOptions;
-(IBAction)mergeToMaster:(id)sender;
-(IBAction)rejectPullRequest:(id)sender;
- (BOOL)openFile:(NSString *)filename;
@end
