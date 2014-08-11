//
//  XCPullRequest.m
//  XCPullRequest
//
//  Created by Kevin Bradley on 6/25/14.
//    Copyright (c) 2014 nito. All rights reserved.
//

#import "XCPullRequest.h"
#import "JRSwizzle.h"
#import <objc/runtime.h>
#import "XCPRWindowController.h"
#import "XCPRWindow.h"
static XCPullRequest *sharedPlugin;

@interface DVTLayoutView_ML : NSView
- (void)setFrameSize:(CGSize)arg1;
@end

@interface DVTControllerContentView : DVTLayoutView_ML
@property(nonatomic) CGSize minimumContentViewFrameSize;
@property(nonatomic) CGSize maximumContentViewFrameSize;
@end

@interface IDEPreferencesController : NSWindowController
+ (id)defaultPreferencesController;
- (void)showPreferencesPanel:(id)arg1;
- (id)toolbarSelectableItemIdentifiers:(id)arg1;
- (id)toolbarDefaultItemIdentifiers:(id)arg1;
- (id)toolbarAllowedItemIdentifiers:(id)arg1;
- (void)selectPreferencePaneWithIdentifier:(id)arg1;
@end


@interface XCPullRequest()


@property (nonatomic, strong) XCPRWindowController* windowController;
@end
@implementation XCPullRequest
@synthesize bundle, mergeBranchMode;
/*
 
 <?xml version="1.0" encoding="UTF-8"?>
 <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
 <plist version="1.0">
 <dict>
 <key>CFBundleTypeExtensions</key>
 <array>
 <string>gpatch</string>
 </array>
 <key>CFBundleTypeIconFile</key>
 <string>GPR2</string>
 <key>CFBundleTypeName</key>
 <string>Pull Request File</string>
 </dict>
 </plist>
 
 
 */

- (BOOL)gpatchAvailable
{
    ///System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -dump | grep gpatch -c
    BOOL itsAvailable = [[XCTerminalUtils stringReturnForProcess:@"/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -dump | grep gpatch -c"] boolValue];
    //NSLog(@"##### gpatch grep check: %i", itsAvailable);
    return itsAvailable;
}

- (void)updateXcodePlist
{
    NSFileManager *man = [NSFileManager defaultManager];
    NSDictionary *lastObject = [[[NSBundle mainBundle] infoDictionary][@"CFBundleDocumentTypes"] lastObject];
    if ([lastObject[@"CFBundleTypeName"] isEqualToString:@"Pull Request File"])
    {
        NSLog(@"no update needed!! gpatch key already exists!");
        return;
    }
    
    NSString *ogInfoPlist = [[[NSBundle mainBundle]bundlePath] stringByAppendingPathComponent:@"Contents/Info.plist"];
    //NSLog(@"og info plist: %@", ogInfoPlist);
    NSDictionary *infoDict = [NSDictionary dictionaryWithContentsOfFile:ogInfoPlist];
    
    NSString *infoPlistBackup = [ogInfoPlist stringByAppendingPathExtension:@"og"];
    [[NSFileManager defaultManager] copyItemAtPath:ogInfoPlist toPath:infoPlistBackup error:nil];
    
    NSMutableDictionary *mutableInfoDict = [infoDict mutableCopy];
    NSMutableArray *docTypes = [mutableInfoDict[@"CFBundleDocumentTypes"] mutableCopy];
    NSArray *extensions = @[@"gpatch"];
    NSDictionary *gpatchDict = @{@"CFBundleTypeExtensions": extensions,@"CFBundleTypeIconFile": @"AppDataDocument", @"CFBundleTypeName": @"Pull Request File" };
    [docTypes addObject:gpatchDict];
    [mutableInfoDict setObject:docTypes forKey:@"CFBundleDocumentTypes"];
    BOOL writeFile = [mutableInfoDict writeToFile:ogInfoPlist atomically:TRUE];
    if (writeFile == TRUE)
    {
        NSString *lsregisterUpdate = [NSString stringWithFormat:@"/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f %@",[[NSBundle mainBundle]bundlePath]];
        NSString *returnStatus = [XCTerminalUtils stringReturnForProcess:lsregisterUpdate];
        NSLog(@"return status: %@", returnStatus);
        if ([man fileExistsAtPath:infoPlistBackup])
        {
            //we have a backup, so remove the new one and reload the old
            [man removeItemAtPath:ogInfoPlist error:nil];
            [man copyItemAtPath:infoPlistBackup toPath:ogInfoPlist error:nil];
        }
    }
}


//git config --get user.email
//From: name@domain.com (Proper Name)
- (NSData *)fromData
{
    return [[NSString stringWithFormat:@"From: %@ (%@)\n", @"_USEREMAIL_", @"_USERNAME_"] dataUsingEncoding:NSUTF8StringEncoding];
}



+ (void)pluginDidLoad:(NSBundle *)plugin
{
    //IDESourceControlIDEDidUpdateLocalStatusNotification
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[self alloc] initWithBundle:plugin];
        });
    }
}

- (id)initWithBundle:(NSBundle *)plugin
{
    
    if (self = [super init]) {
        // reference to plugin's bundle, for resource acccess
        self.bundle = plugin;
        
        [self bringAllToFrontIndex];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationListener:) name:nil object:nil];
        
        if (self.windowController == nil) {
            XCPRWindowController* wc = [[XCPRWindowController alloc] initWithWindowNibName:@"XCPRWindowController"];
            self.windowController = wc;
            wc.delegate = self;
            
        }
        
        // Create menu items, initialize UI, etc.
        
        // Sample Menu Item:
        NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"Source Control"];
        if (menuItem) {
            [[menuItem submenu] addItem:[NSMenuItem separatorItem]];
            NSMenuItem *thePullReq = [[NSMenuItem alloc] initWithTitle:@"Submit Pull Request..." action:@selector(pullRequest) keyEquivalent:@""];
            //[thePullReq setTarget:self];
            [[menuItem submenu] insertItem:thePullReq atIndex:6];
            
        }
        static dispatch_once_t onceToken2;
        dispatch_once(&onceToken2, ^{
            [self doSwizzlingScience];
        });
        
        
        if ([self gpatchAvailable] == TRUE)
        {
            
        } else {
            
            [self updateXcodePlist];
        }
        
    }
    return self;
}

//make things compile / quiet things down to cope with swizzling.

- (void)viewDidInstall {}
- (void)setView:(id)theView {}
- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename { return TRUE; }
- (BOOL)application:(NSApplication *)sender openFiles:(NSArray *)filenames { return TRUE; }
- (void)originalViewDidInstall {}
- (NSView *)view {return nil;};


- (id)contentInitWithFrame:(CGRect)arg1
{
    CGRect targetRect = CGRectMake(0, 0, 750, 164);
    if (CGRectEqualToRect(arg1, targetRect))
    {
        arg1.size.height = arg1.size.height + 30;
    }
    
    id orig = [self contentInitWithFrame:arg1];
    
    
    
    return orig;
    
}

- (void)doSwizzlingScience
{
    
    Class paneCon = objc_getClass("IDESourceControlPrefsPaneController");
    Class dvtcv = objc_getClass("DVTControllerContentView");
    Class xcAppClass = objc_getClass("IDEApplicationController");
    NSError *theError = nil;
    
//    Method ourFileOpenReplacement = class_getInstanceMethod([self class], @selector(ourApplication:openFile:));
//    class_addMethod(xcAppClass, @selector(ourApplication:openFile:), method_getImplementation(ourFileOpenReplacement), method_getTypeEncoding(ourFileOpenReplacement));
//    
//    BOOL swizzleScience = FALSE;
//    
//    swizzleScience = [xcAppClass jr_swizzleMethod:@selector(application:openFile:) withMethod:@selector(ourApplication:openFile:) error:&theError];
//    
//    if (swizzleScience == TRUE)
//    {
//        NSLog(@"IDEApplicationController ourApplication:openFile: replaced!");
//    } else {
//        
//        NSLog(@"IDEApplicationController ourApplication:openFile: failed to replace with error: %@", theError);
//        
//    }
    
    Method ourFilesOpenReplacement = class_getInstanceMethod([self class], @selector(ourApplication:openFiles:));
    class_addMethod(xcAppClass, @selector(ourApplication:openFiles:), method_getImplementation(ourFilesOpenReplacement), method_getTypeEncoding(ourFilesOpenReplacement));
    
    BOOL swizzleScience = [xcAppClass jr_swizzleMethod:@selector(application:openFiles:) withMethod:@selector(ourApplication:openFiles:) error:&theError];
    
    if (swizzleScience == TRUE)
    {
        NSLog(@"IDEApplicationController ourApplication:openFiles: replaced!");
    } else {
        
        NSLog(@"IDEApplicationController ourApplication:openFiles: failed to replace with error(: %@", theError);
    }
    
    Method ourContextReplacement = class_getInstanceMethod([self class], @selector(prefViewDidInstall));
    class_addMethod(paneCon, @selector(prefViewDidInstall), method_getImplementation(ourContextReplacement), method_getTypeEncoding(ourContextReplacement));
    
    Method ourFrameInit = class_getInstanceMethod([self class], @selector(contentInitWithFrame:));
    class_addMethod(dvtcv, @selector(contentInitWithFrame:), method_getImplementation(ourFrameInit), method_getTypeEncoding(ourFrameInit));
    
    
    
    swizzleScience = [dvtcv jr_swizzleMethod:@selector(initWithFrame:) withMethod:@selector(contentInitWithFrame:) error:&theError];
    if (swizzleScience == TRUE)
    {
        NSLog(@"DVTControllerContentView replaced!");
    } else {
        
        NSLog(@"DVTControllerContentView failed to replace with error: %@", theError);
        
    }
    
    swizzleScience = [paneCon jr_swizzleMethod:@selector(viewDidInstall) withMethod:@selector(prefViewDidInstall) error:&theError];
    if (swizzleScience == TRUE)
    {
        NSLog(@"IDESourceControlPrefsPaneController replaced!");
    } else {
        
        NSLog(@"IDESourceControlPrefsPaneController failed to replace with error: %@", theError);
        
    }
    
}

/*
 
 7/25/14 11:14:44.254 PM Xcode[17497]: view: <NSButton: 0x7faf66d5f470> viewFrame: {{292, 226}, {161, 18}}
 7/25/14 11:14:44.254 PM Xcode[17497]: view: <NSButton: 0x7faf66d5f0a0> viewFrame: {{312, 182}, {242, 18}}
 7/25/14 11:14:44.254 PM Xcode[17497]: view: <NSButton: 0x7faf66d5ecd0> viewFrame: {{312, 160}, {244, 18}}
 7/25/14 11:14:44.254 PM Xcode[17497]: view: <NSTextField: 0x7faf66d5e9a0> viewFrame: {{187, 227}, {102, 17}}
 7/25/14 11:14:44.255 PM Xcode[17497]: view: <NSButton: 0x7faf66d5c550> viewFrame: {{312, 204}, {233, 18}}
 7/25/14 11:14:44.255 PM Xcode[17497]: view: <NSTextField: 0x7faf66d5c190> viewFrame: {{171, 123}, {118, 17}}
 7/25/14 11:14:44.255 PM Xcode[17497]: view: <NSTextField: 0x7faf66d5a8e0> viewFrame: {{291, 123}, {144, 17}}
 7/25/14 11:14:44.255 PM Xcode[17497]: view: <NSTextField: 0x7faf66d3fc80> viewFrame: {{508, 123}, {30, 17}}
 7/25/14 11:14:44.255 PM Xcode[17497]: view: <NSPopUpButton: 0x7faf66d43110> viewFrame: {{438, 117}, {68, 26}}
 7/25/14 11:14:44.256 PM Xcode[17497]: view: <NSButton: 0x7faf66a4edb0> viewFrame: {{312, 50}, {244, 18}}
 
 
 */


- (void)textFieldDidEndEditing:(id)sender
{
    //NSLog(@"didEnd: %@", [sender stringValue]);
    [[NSUserDefaults standardUserDefaults] setObject:[sender stringValue] forKey:kXCPullRequestXCServer];
}

- (void)prefViewDidInstall
{
    [self prefViewDidInstall]; // call original method
    
    [sharedPlugin bringAllToFrontIndex];
    
    NSString *serverAddress = [sharedPlugin defaultServerAddress];
    
    NSView *topView = [self view];
    NSView *theView = [[topView subviews] lastObject];
    
    NSTextField *pullReqServerLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(155, 23, 180, 17)];
    NSTextField *requestAddressTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(300, 20, 220, 22)];
    if (serverAddress != nil) [requestAddressTextField setStringValue:serverAddress];
    [requestAddressTextField setTarget:sharedPlugin];
    [requestAddressTextField setAction:@selector(textFieldDidEndEditing:)];
    
    [pullReqServerLabel setStringValue:@"Xcode Server Address:"];
    [pullReqServerLabel setEditable:FALSE];
    [pullReqServerLabel setBordered:FALSE];
    [pullReqServerLabel setBackgroundColor:[NSColor clearColor]];
    [theView addSubview:pullReqServerLabel];
    [theView addSubview:requestAddressTextField];
    if (serverAddress.length == 0)
    {
        [requestAddressTextField becomeFirstResponder];
    }
    
    //    for (NSView *theView2 in theView.subviews)
    //    {
    //        NSString *viewFrame = NSStringFromRect(theView2.frame);
    //        NSLog(@"view: %@ viewFrame: %@", theView2, viewFrame);
    //    }
    //
    // NSLog(@"prefViewDidInstall: %@", [self view]);
    
}

/*
 
 6/25/14 12:44:10.384 PM Xcode[6527]: project dict: {
 IDESourceControlProjectFavoriteDictionaryKey = 0;
 IDESourceControlProjectIdentifier = "5F12C368-D10E-4C12-B5A0-D4445EF0A91E";
 IDESourceControlProjectName = XCPullRequest;
 IDESourceControlProjectOriginsDictionary =     {
 "4065D7A0-199D-4EA7-9779-B15251D9C8D3" = "ssh://macgitserver/git/XCPullRequest.git";
 };
 IDESourceControlProjectPath = "XCPullRequest.xcodeproj/project.xcworkspace";
 IDESourceControlProjectRelativeInstallPathDictionary =     {
 "4065D7A0-199D-4EA7-9779-B15251D9C8D3" = "../..";
 };
 IDESourceControlProjectURL = "ssh://macgitserver/git/XCPullRequest.git";
 IDESourceControlProjectVersion = 110;
 IDESourceControlProjectWCCIdentifier = "4065D7A0-199D-4EA7-9779-B15251D9C8D3";
 IDESourceControlProjectWCConfigurations =     (
 {
 IDESourceControlRepositoryExtensionIdentifierKey = "public.vcs.git";
 IDESourceControlWCCIdentifierKey = "4065D7A0-199D-4EA7-9779-B15251D9C8D3";
 IDESourceControlWCCName = XCPullRequest;
 }
 );
 }
 
 
 */

//IDESourceControlIDEDidUpdateLocalStatusNotification

- (void)notificationListener:(NSNotification *)notification
{
    //IDESourceControlWorkspaceMonitor
    NSString *name = [notification name];
    Class iscwm = NSClassFromString(@"IDESourceControlWorkspaceMonitor");
    if ([name rangeOfString:@"SourceControl"].location != NSNotFound)
    {
        NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"Source Control"];
        //6/25/14 10:41:15.717 AM Xcode[5053]: notification: IDESourceControlIDEWillUpdateLocalStatusNotification object: (null)
        
        if ([name isEqualToString:@"IDESourceControlIDEDidUpdateLocalStatusNotification"] || [name isEqualToString:@"IDESourceControlIDEWillUpdateLocalStatusNotification"])
        {
            IDESourceControlWorkspaceMonitor *monitor = [XCPRModel sourceControlMonitor];
            IDESourceControlProject *project = [monitor sourceControlProject];
            //NSLog(@"project: %@", project);
            if (project == nil)
            {
                [[[menuItem submenu] itemAtIndex:6] setTarget:nil];
                
            } else if (project != nil) {
                
                //     NSLog(@"gitBranch: -%@-", [self currentGITBranch]);
                if ([[XCTerminalUtils currentGITBranch] isEqualToString:@"master"])
                {
                    [[[menuItem submenu] itemAtIndex:6] setTarget:nil];
                } else {
                    [[[menuItem submenu] itemAtIndex:6] setTarget:self];
                }
                
            }
        }
        id object = [notification object];
        
        // NSLog(@"notification: %@ object: %@", name, [notification object]);
        if ([object isKindOfClass:iscwm])
        {
            id sco = [object valueForKey:@"sourceControlProject"];
            
            if (sco == nil)
            {
                [[[menuItem submenu] itemAtIndex:6] setTarget:nil];
            } else if (sco != nil) {
                [[[menuItem submenu] itemAtIndex:6] setTarget:self];
                
            }
        }
    }
}

/*
 
 we havent committed our changes yet error
 
 6/25/14 3:12:31.364 PM Xcode[12162]: string return: fatal: You have not concluded your merge (MERGE_HEAD exists).
 Please, commit your changes before you can merge.
 
 6/25/14 3:15:49.382 PM Xcode[12407]: string return: Automatic merge went well; stopped before committing as requested
 Already up-to-date!
 
 
 
 */

//this is major science

- (NSString *)pullRequestCheck
{
    NSString *currentBranch = [XCTerminalUtils currentGITBranch];
    
    NSArray *gitcheckout = [NSArray arrayWithObjects:@"checkout", @"master", nil];
    NSArray *gitcheckoutC = [NSArray arrayWithObjects:@"checkout", currentBranch, nil];
    NSArray *gitArguments = [NSArray arrayWithObjects:@"merge", @"--no-commit", @"--no-ff", currentBranch, nil];
    [XCTerminalUtils returnFromGITWithArguments:gitcheckout];
    
    NSString *stringReturn = [[XCTerminalUtils returnFromGITWithArguments:gitArguments] componentsJoinedByString:@"\n"];
    //NSLog(@"string return: %@", stringReturn);
    [XCTerminalUtils returnFromGITWithArguments:[NSArray arrayWithObjects:@"merge", @"--abort", nil]];
    [XCTerminalUtils returnFromGITWithArguments:gitcheckoutC];
    
    if ([stringReturn rangeOfString:@"Automatic merge went well"].location != NSNotFound)
    {
        NSLog(@"clean merge possible, return nil");
        return nil;
    }
    
    return stringReturn;
}


- (void)createPatchToPath:(NSString *)outputPath withDict:(NSDictionary *)infoDict
{
    NSString *stringFromDict = [infoDict stringFromDictionary];
    
    NSDictionary *sourceControlDict = [[[XCPRModel sourceControlMonitor] sourceControlProject] dictionaryRepresentation];
    NSString *projectURL = sourceControlDict[@"IDESourceControlProjectURL"];
    NSString *projectBranch = [XCTerminalUtils currentGITBranch];
    NSArray *gitArguments = [NSArray arrayWithObjects:@"request-pull", @"-p", @"origin/master", projectURL, projectBranch, nil];
    [[NSFileManager defaultManager] createFileAtPath:outputPath contents:[self fromData] attributes:nil];
    [XCTerminalUtils createGITPatch:outputPath withArguments:gitArguments];
    NSError *error = nil;
    NSMutableString *outputString = [[NSMutableString alloc] initWithContentsOfFile:outputPath encoding:NSUTF8StringEncoding error:&error];
    if (error != nil)
    {
        //NSLog(@"init string from file: %@ errored out: %@", outputPath, [error localizedDescription]);
        return;
    }
    [outputString appendString:kXCPullRequestBoundary];
    [outputString appendString:stringFromDict];
    NSString *testFile = @"/tmp/sciencely.gpatch";
    [outputString writeToFile:testFile atomically:TRUE encoding:NSUTF8StringEncoding error:&error];
    if (error != nil)
    {
        NSLog(@"new file: %@ failed to write with error: %@", testFile, [error localizedDescription]);
        return;
    }
    // got this far, overwrite the patch!
    [outputString writeToFile:outputPath atomically:TRUE encoding:NSUTF8StringEncoding error:nil];
}

- (NSInteger)bringAllToFrontIndex
{
    NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"Window"];
    NSMenu *submenu = [menuItem submenu];
    NSMenuItem *bringAllItem = [submenu itemWithTitle:@"Bring All to Front"];
//    NSMenuItem *packageManagerItem = [submenu itemWithTitle:@"Package Manager"];
    return [submenu indexOfItem:bringAllItem];
}

// git config --global alias.mergetest '!f(){ git merge --no-commit --no-ff "$1"; git merge --abort; echo "Merge aborted"; };f '

// git request-pull -p origin/master ssh://Kevin%20Bradley@macgitserver/git/XCPullRequest.git science
- (NSString *)pullRequestPatchPath
{
    NSString *rootPath = @"/private/tmp";
    NSDictionary *sourceControlDict = [[[XCPRModel sourceControlMonitor] sourceControlProject] dictionaryRepresentation];
    NSString *projectURL = sourceControlDict[@"IDESourceControlProjectURL"];
    NSString *projectBranch = [XCTerminalUtils currentGITBranch];
    NSArray *gitArguments = [NSArray arrayWithObjects:@"request-pull", @"-p", @"origin/master", projectURL, projectBranch, nil];
    NSString *gitTest = [NSString stringWithFormat:@"git %@", [gitArguments componentsJoinedByString:@" "]];
    NSData *gitData = [gitTest dataUsingEncoding:NSUTF8StringEncoding];
    NSString *patchOutputFile = [rootPath stringByAppendingPathComponent:[self pullRequestName]];
    [[NSFileManager defaultManager] createFileAtPath:patchOutputFile contents:gitData attributes:nil];
    [XCTerminalUtils createGITPatch:patchOutputFile withArguments:gitArguments];
    return patchOutputFile;
}

- (NSString *)emailDevsString
{
    NSString *serverURL = [NSString stringWithFormat:@"http://%@/pull_admins.plist", [self defaultServerAddress]];
    NSArray *theArray = [[NSArray alloc] initWithContentsOfURL:[NSURL URLWithString:serverURL]];
    NSMutableString *finalString = [[NSMutableString alloc] init];
    int adminNumber = 0;
    for (NSString *admin in theArray)
    {
        if ([theArray count] != (adminNumber + 1)){
            
            [finalString appendFormat:@"%@, ", admin];
            
        } else {
            
            [finalString appendFormat:@"%@", admin];
            
        }
        adminNumber++;
    }
    return finalString;
}

- (void)windowDidClose
{
    if (ourMenuName == nil) return;
    
    NSMenuItem *windowItem = [[NSApp mainMenu] itemWithTitle:@"Window"];
    NSMenu *submenu = [windowItem submenu];
    NSMenuItem *prWindowItem = [submenu itemWithTitle:ourMenuName];
    NSInteger ourDividerIndex = [submenu indexOfItem:prWindowItem]-1;
   // NSMenuItem *seperatorItem = [submenu itemAtIndex:ourDividerIndex];
    [[windowItem submenu] removeItemAtIndex:ourDividerIndex];
    [[windowItem submenu] removeItem:prWindowItem];
    ourMenuName = nil;
    ourMenuIndex = -1;
}

- (void)showOurWindow
{
    [self.windowController.window makeKeyAndOrderFront:nil];
}

- (void)openPatchFile:(NSString *)theFile
{
    NSLog(@"openPatchFile: %@", theFile);
    
    //check to see if window is already visible so we dont add another new menu item and divider!!
    BOOL isVisible = self.windowController.window.isVisible;
    
    [self.windowController.window makeKeyAndOrderFront:nil];
    [self.windowController openFile:theFile];
    
    //if (isVisible == TRUE) return;
    
    if (ourMenuName != nil) return;
    
    NSInteger ourDividerIndex = [self bringAllToFrontIndex]+1;
    ourMenuIndex = ourDividerIndex+1;//2 items below that guy
    ourMenuName = theFile.lastPathComponent;
    // NSString *ourPullRequest = [NSString stringWithFormat:@"%@ Pull Request", theFile.lastPathComponent];
  //  NSImage *image = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"xcode-project_Icon" ofType:@"png"]];
    
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AppDataDocument" ofType:@"icns"]];
    [image setScalesWhenResized:TRUE];
    [image setSize:CGSizeMake(16, 16)];
    
    NSMenuItem *prWindowItem = [[NSMenuItem alloc]initWithTitle:ourMenuName action:@selector(showOurWindow) keyEquivalent:@""];
    [prWindowItem setImage:image];
    [prWindowItem setTarget:sharedPlugin];
    NSMenuItem *windowItem = [[NSApp mainMenu] itemWithTitle:@"Window"];
    [[windowItem submenu] insertItem:[NSMenuItem separatorItem] atIndex:ourDividerIndex];
    [[windowItem submenu] insertItem:prWindowItem atIndex:ourMenuIndex];
    [(XCPRWindow *)self.windowController.window setCompanionMenuItem:prWindowItem];
    // NSMenu *submenu = [menuItem submenu];
    
}

- (BOOL)ourApplication:(NSApplication *)sender openFiles:(NSArray *)filenames
{
    BOOL orig = FALSE; 
    NSString *filename = [filenames lastObject];
    if ([[[filename pathExtension] lowercaseString] isEqualToString:@"gpatch"])
    {
        orig = FALSE;
        [sharedPlugin openPatchFile:filename];
        
    } else {
        
        orig = [self ourApplication:sender openFiles:filenames];
        
    }
    
    return orig;
}

- (BOOL)ourApplication:(NSApplication *)sender openFile:(NSString *)filename
{
    BOOL orig = [self ourApplication:sender openFile:filename];
    if ([[[filename pathExtension] lowercaseString] isEqualToString:@"gpatch"])
    {
        orig = FALSE;
        [sharedPlugin openPatchFile:filename];
        
    } else {
        
        orig = [self ourApplication:sender openFile:filename];
        
    }
    
    return orig;
}

- (int)tarBundleAtPath:(NSString *)filePath
{
    NSString *containingFolder = [filePath stringByDeletingLastPathComponent];
    NSString *fileName = [[filePath lastPathComponent] stringByDeletingPathExtension];
	NSString *tempTarFile = [fileName stringByAppendingPathExtension:@"tgz"];
	NSString *tarCommand = [NSString stringWithFormat:@"pushd '%@' ; /usr/bin/tar cpz -P --exclude *DSStore -f '%@' '%@'", containingFolder, tempTarFile, [filePath lastPathComponent]];
	//NSLog(@"%@", tarCommand);
	int sysReturn = system([tarCommand UTF8String]);
	int actualReturn = WEXITSTATUS(sysReturn);
	//NSLog(@"tarBundleAtPath finished with status: %i", actualReturn);
	return actualReturn;
}

//-(NSString *)zipPreferenceFiles:(NSString *)fileName
//{
//	ZipArchive *za = [[ZipArchive alloc] init];
//	NSString *tempZipFile = [NSString stringWithFormat:@"/private/var/tmp/%@.zip", fileName];
//	if ([za CreateZipFile2:tempZipFile]) {
//		NSArray *preferences = [mHelperClass preferenceFiles];
//		int i;
//		for(i = 0; i < [preferences count]; i++)
//		{
//			id currentObject = [preferences objectAtIndex:i];
//			[za addFileToZip:currentObject newname:currentObject];
//		}
//	}
//	[za CloseZipFile2];
//	[za release];
//	return tempZipFile;
//}

- (NSString *)createBundleWithComment:(NSString *)commitComment
{
    NSFileManager *man = [NSFileManager defaultManager];
    NSString *rootPath = @"/private/tmp";
    NSDictionary *sourceControlDict = [[[XCPRModel sourceControlMonitor] sourceControlProject] dictionaryRepresentation];
    NSString *projectName = sourceControlDict[@"IDESourceControlProjectName"];
    NSString *projectBranch = [XCTerminalUtils currentGITBranch];
    NSString *bundlePath = [rootPath stringByAppendingPathComponent:[self pullRequestBundleName]];
    NSString *infoLocation = [bundlePath stringByAppendingFormat:@"/Contents/Info.plist"];
    NSString *resourceFolder = [bundlePath stringByAppendingPathComponent:@"Contents/Resources"];
    [man createDirectoryAtPath:bundlePath withIntermediateDirectories:true attributes:nil error:nil];
    [man createDirectoryAtPath:resourceFolder withIntermediateDirectories:TRUE attributes:nil error:nil];
    NSString *patchPath = [resourceFolder stringByAppendingPathComponent:@"patch.gpatch"];
    
    NSDictionary *infoDict = @{@"ProjectName": projectName, @"ProjectBranch": projectBranch, @"Comment": commitComment, @"Email": [XCTerminalUtils currentUserEmail], @"Committer": [XCTerminalUtils currentUserName], @"id": pullReqId};
    
    [self createPatchToPath:patchPath withDict:infoDict];
    
    [infoDict writeToFile:infoLocation atomically:TRUE];
    return bundlePath;
}

- (NSString *)queryForComment
{
    NSAlert *alertWithAux = [NSAlert alertWithMessageText:@"Please enter a comment for this pull request!" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
    
    commentField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 44)];
    [commentField setEditable:TRUE];
    [commentField setBordered:TRUE];
    
    NSView *viewTextEntry = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 340, 44)];
    [viewTextEntry addSubview:commentField];
    [alertWithAux setAccessoryView:viewTextEntry];
    
    [alertWithAux runModal];
    
    return commentField.stringValue;
}

- (NSString *)defaultServerAddress
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:kXCPullRequestXCServer];
}

#define OUR_DATE_FORMAT @"MMddyy_HHmmss"


- (void)generatePullReqID
{
    if (pullReqId == nil)
    {
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setDateFormat:OUR_DATE_FORMAT];
        pullReqId = [df stringFromDate:[NSDate date]];
    }
}

- (NSString *) pullRequestBundleName
{
    //NSDateFormatter *df = [[NSDateFormatter alloc] init];
    // [df setDateFormat:OUR_DATE_FORMAT];
    NSDictionary *sourceControlDict = [[[XCPRModel sourceControlMonitor] sourceControlProject] dictionaryRepresentation];
    NSString *projectName = sourceControlDict[@"IDESourceControlProjectName"];
    NSString *projectBranch = [XCTerminalUtils currentGITBranch];
    NSString *nameString = [NSString stringWithFormat:@"%@_%@_%@.bundle", projectName, projectBranch, pullReqId];
    return nameString;
}

- (NSString *) pullRequestName
{
    //  NSDateFormatter *df = [[NSDateFormatter alloc] init];
    //[df setDateFormat:OUR_DATE_FORMAT];
    NSDictionary *sourceControlDict = [[[XCPRModel sourceControlMonitor] sourceControlProject] dictionaryRepresentation];
    NSString *projectName = sourceControlDict[@"IDESourceControlProjectName"];
    NSString *projectBranch = [XCTerminalUtils currentGITBranch];
    NSString *nameString = [NSString stringWithFormat:@"%@_%@_%@.gpatch", projectName, projectBranch, pullReqId];
    return nameString;
}

- (NSString *)postJSON:(NSDictionary *)postDictionary
{
    // Get dictionary into JSON
    NSError *error = nil;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:postDictionary
                                                       options:0 // or NSJSONWritingPrettyPrinted
                                                         error:&error];
    
    NSString *urlString = [NSString stringWithFormat:@"http://%@/JSONTest.php", [self defaultServerAddress]];
    
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    //  NSData *requestData = [NSData dataWithBytes:[jsonRequest UTF8String] length:[jsonRequest length]];
    
    [request setHTTPMethod:@"POST"];
    // [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[jsonData length]] forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody: jsonData];
    NSData *returnData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    NSString *returnString = [[NSString alloc] initWithData:returnData encoding:NSUTF8StringEncoding];
    
    NSLog(@"JSON test return String: %@", returnString);
    
    return returnString;
}

//adding stupid frivolous comment for pull request basic test.

- (void)postFile:(NSString *)theFile
{
    NSData *tarData = [NSData dataWithContentsOfFile:theFile];
    NSString *fileType = [theFile pathExtension];
    NSString *urlString = [NSString stringWithFormat:@"http://%@/upload.php?type=%@", [self defaultServerAddress], fileType];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:urlString]];
    [request setHTTPMethod:@"POST"];
    
    NSString *boundary = @"---------------------------14737809831466499882746641449";
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",boundary];
    [request addValue:contentType forHTTPHeaderField: @"Content-Type"];
    
    NSMutableData *body = [NSMutableData data];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"file\"; filename=\"%@\"\r\n", [theFile lastPathComponent]] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[NSData dataWithData:tarData]];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [request setHTTPBody:body];
    
    NSData *returnData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    NSString *returnString = [[NSString alloc] initWithData:returnData encoding:NSUTF8StringEncoding];
    
    NSLog(@"File Upload Return String: %@", returnString);
}

/*
 
 @["Xcode.PreferencePane.General","Xcode.PreferencePane.Accounts","Xcode.PreferencePane.Alerts","Xcode.PreferencePane.Navigation","Xcode.PreferencePane.FontAndColor","Xcode.IDESourceEditor.TextEditingPrefPane","Xcode.PreferencePane.KeyBindings","Xcode.PreferencePane.SourceControl","Xcode.PreferencePane.Downloads","Xcode.PreferencePane.Locations"]
 
 */

- (void)showSourceControlPreferencePane
{
    Class prefConClass = objc_getClass("IDEPreferencesController");
    NSString *sourceControlId = @"Xcode.PreferencePane.SourceControl";
    id sharedPrefController = (IDEPreferencesController *)[prefConClass defaultPreferencesController];
    [(IDEPreferencesController *)sharedPrefController showPreferencesPanel:nil];
    [(IDEPreferencesController *)sharedPrefController selectPreferencePaneWithIdentifier:sourceControlId];
    //NSArray *selectableIds = [(IDEPreferencesController *)sharedPrefController toolbarSelectableItemIdentifiers:nil];
    //NSLog(@"selectableIds: %@", selectableIds);
    
    
}

- (BOOL)runningCompatServer
{
    NSString *testString = [NSString stringWithFormat:@"http://%@/xcpullreqd", [self defaultServerAddress]];
    NSData *fileData = [NSData dataWithContentsOfURL:[NSURL URLWithString:testString]];

    if (fileData.length == 0)
        return FALSE;
    
    return TRUE;
}

- (void)pullRequest
{
    if ([self defaultServerAddress] == nil || [self defaultServerAddress].length == 0)
    {
        NSAlert *alert = [NSAlert alertWithMessageText:@"You need a Xcode server address configured in preferences first!" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
          [alert runModal];
        [self showSourceControlPreferencePane];
        return;
        
    }
    if ([self runningCompatServer] == FALSE)
    {
        NSAlert *alert = [NSAlert alertWithMessageText:@"Invalid configuration!" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@"You need a web server running on a Mac (preferably running OS X server) with Upload.php, pull_admins.plist and xcpullredq installed in /Library/Server/Web/Data/Sites/Default/"];
        [alert runModal];
        return;
    }
    
    NSString *dryMergeOutput = [self pullRequestCheck];
    [self generatePullReqID];
    if (dryMergeOutput == nil)
    {
     //   [self generatePullReqID]; //the timestamp identifier, generate it just once so its never different.
        NSString *pullRequestComment = [self queryForComment];
        NSAlert *alert = [NSAlert alertWithMessageText:@"Pull request submitted successfully!" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
        [alert runModal];
        NSString *bundleLocation = [self createBundleWithComment:pullRequestComment];
        [self tarBundleAtPath:bundleLocation];
        NSString *fileName = [bundleLocation stringByDeletingPathExtension];
        NSString *tempTarFile = [fileName stringByAppendingPathExtension:@"tgz"];
        [self postFile:tempTarFile];
    } else {
        NSAlert *alert = [NSAlert alertWithMessageText:@"Pull Request failed" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@"Failed with output %@", dryMergeOutput];
        [alert runModal];
        NSString *patchOutputFile = [self pullRequestPatchPath];
        [[NSWorkspace sharedWorkspace] openFile:patchOutputFile];
    }
    
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
