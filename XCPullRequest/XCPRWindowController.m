//
//  XCPRWindowController.m
//  XTrello
//
//  Created by Kevin Bradley on 7/14/14.
//  Copyright (c) 2014 nito. All rights reserved.
//

#import "XCPRWindowController.h"
#import "XCPRCategories.h"

@interface XCPRWindowController ()

@end

@implementation XCPRWindowController

@synthesize delegate;

- (void)windowDidBecomeKey:(NSNotification *)notification
{
    [[(XCPRWindow *)self.window companionMenuItem] setState:1];
    
}

- (void)windowDidResignKey:(NSNotification *)notification
{
    [[(XCPRWindow *)self.window companionMenuItem] setState:0];
}

- (void)windowWillClose:(NSNotification *)notification
{
    
    [(XCPRWindow *)self.window setCompanionMenuItem:nil];
    //  NSLog(@"windowWillClose: %@", notification);
    [delegate windowDidClose];
    
}

- (void)awakeFromNib
{
    [patchTextView setEditable:FALSE];
    
    self.patchEnabled = FALSE;
    
    lineNumberView = [[NoodleLineNumberView alloc] initWithScrollView:patchScrollView];
    [patchScrollView setVerticalRulerView:lineNumberView];
    [patchScrollView setHasHorizontalRuler:NO];
    [patchScrollView setHasVerticalRuler:YES];
    [patchScrollView setRulersVisible:YES];
    [(XCPRWindow *)self.window setOurBundle:[self.delegate bundle]];
}

//science

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    NSColor *greyColor = [NSColor lightGrayColor];
    self.window.backgroundColor = greyColor;
   
    // self.window.level = NSFloatingWindowLevel;
    
}


- (BOOL)openFile:(NSString *)filename
{
    NSString *fileContents = [self signGITPatch:filename];
    if (fileContents == nil)
        return FALSE;
    patchFilePath = filename;
    patchFileName = [filename lastPathComponent];
    
    
    fileContents = [self trimmedGITPatch:filename];
    
    submittersEmail = [self committerEmail];
    [self setTextViewString:fileContents];
    [self performSyntaxHighlighting];
    [self updatePatchEnabled];
    self.window.title = [filename lastPathComponent];
    self.window.representedFilename = filename;
     [[(XCPRWindow *)self.window companionMenuItem] setState:1];
    [self.window.toolbar setVisible:TRUE];
   // [self.window.toolbar set
    return TRUE;
}

#pragma mark External Text editor methods

- (NSString *)newDiffPath
{
    NSMutableArray *nameComponents = [[NSMutableArray alloc] initWithArray:[patchFileName componentsSeparatedByString:@"_"]];
    if ([nameComponents count] == 0) return nil;
    [nameComponents removeLastObject];
    return [[patchFilePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:[[nameComponents componentsJoinedByString:@"_"] stringByAppendingPathExtension:@"diff"]];
}

- (void)createTrimmedDiff
{
    NSString *originalContents = [self patchContents];
    NSMutableArray *lineArray = [[NSMutableArray alloc] initWithArray:[originalContents componentsSeparatedByString:@"\n"]];
    [lineArray removeObjectAtIndex:0]; //remove the first line, im sure theres a more elegant way to do this...
    NSString *newContents = [lineArray componentsJoinedByString:@"\n"];
    [newContents writeToFile:[self newDiffPath] atomically:TRUE encoding:NSUTF8StringEncoding error:nil];
}


- (void)openWith:(id)sender
{
    
    if (patchFilePath != nil)
    {
        [self createTrimmedDiff];
        [[NSWorkspace sharedWorkspace] openFile:[self newDiffPath] withApplication:[sender title]];
        
    }
}


#pragma convenience methods


- (NSString *)currentGITBranch
{
    NSString *currentBranch = nil;
    NSArray *branchArray = [XCTerminalUtils returnFromCommand:@"/usr/bin/git" withArguments:@[@"branch", @"--list"] inPath:[self projectPath]];
    for (NSString *branchItem in branchArray)
    {
        if ([branchItem rangeOfString:@"*"].location != NSNotFound)
            currentBranch = [branchItem substringFromIndex:2];
    }
    
    return currentBranch;
}



- (NSString *)currentUserEmail
{
    return [[XCTerminalUtils returnFromCommand:@"/usr/bin/git" withArguments:@[@"config", @"--get", @"user.email"] inPath:[self projectPath]] objectAtIndex:0];
}

- (NSString *)currentUserName
{
    return [[XCTerminalUtils returnFromCommand:@"/usr/bin/git" withArguments:@[@"config", @"--get", @"user.name"] inPath:[self projectPath]] objectAtIndex:0];
}


- (NSString *)deprecatedProjectName
{
    NSArray *nameComponents = [patchFileName componentsSeparatedByString:@"_"];
    if ([nameComponents count] == 0) return nil;
    return [nameComponents objectAtIndex:0];
}

- (NSString *)deprecatedBranchName
{
    NSArray *nameComponents = [patchFileName componentsSeparatedByString:@"_"];
    if ([nameComponents count] == 0) return nil;
    return [nameComponents objectAtIndex:1];
}

- (NSString *)deprecatedCommitterEmail
{
    NSArray *nameComponents = [patchFileName componentsSeparatedByString:@"_"];
    if ([nameComponents count] == 0) return nil;
    if ([nameComponents count] < 4) return nil;
    return [[nameComponents objectAtIndex:4] stringByDeletingPathExtension];
}

- (NSString *)deprecatedTimeStampValue
{
    NSArray *nameComponents = [patchFileName componentsSeparatedByString:@"_"];
    if ([nameComponents count] == 0) return nil;
    if ([nameComponents count] < 3) return nil;
    
    return [NSString stringWithFormat:@"%@_%@", [nameComponents objectAtIndex:2], [nameComponents objectAtIndex:3]];
}


- (NSString *)projectName
{
    if (plistDict != nil)
    {
        return plistDict[@"ProjectName"];
    } else {
        return [self deprecatedProjectName];
    }
}

- (NSString *)branchName
{
    if (plistDict != nil)
    {
        return plistDict[@"ProjectBranch"];
    } else {
        return [self deprecatedBranchName];
    }
}

- (NSString *)committerEmail
{
    if (plistDict != nil)
    {
        return plistDict[@"Email"];
    } else {
        return [self deprecatedCommitterEmail];
    }
}

- (NSString *)timeStampValue
{
    if (plistDict != nil)
    {
        return plistDict[@"id"];
    } else {
        return [self deprecatedTimeStampValue];
    }
}


- (NSString *)projectPath
{
    NSString *developerDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Developer"];
    NSString *guess = [developerDir stringByAppendingPathComponent:[self projectName]];
    return guess;
}

# pragma mark TextView editing

- (void)setTextViewString:(NSString *)theString
{
    patchTextView.string = theString;
}

- (void)addTextToView:(NSString *)addedText
{
    NSMutableString *theString = [[NSMutableString alloc] initWithString:patchTextView.string];
    [theString appendString:addedText];
    patchTextView.string = theString;
}

- (NSString *)patchContents
{
    return [NSString stringWithContentsOfFile:patchFilePath encoding:NSUTF8StringEncoding error:nil];
}

# pragma mark Syntax highlighting

/*
 
 taken and modified from ray wenderlich tutorial on regex
 
 http://www.raywenderlich.com/30288/nsregularexpression-tutorial-and-cheat-sheet
 
 http://www.regular-expressions.info/
 
 also helpful :
 https://developer.apple.com/library/mac/documentation/Foundation/Reference/NSRegularExpression_Class/Reference/Reference.html
 
 the regex for diff highlighting was taken from with (minor modifications)
 
 https://git.wikimedia.org/blob/mediawiki%2Fextensions%2FSyntaxHighlight_GeSHi/d7b87ac836b23230957cda8be551cca40c5574e1/geshi%2Fgeshi%2Fdiff.php
 
 */


- (BOOL)checkForBinaryMods
{
    //Binary files /dev/null and b/XCPullRequest/iPad-3.png differ
    NSError *error = NULL;
    NSString *pattern = @"(Binary files)\\b(.*?)\\b(and)\\b(.*?)\\b(differ)$";
    NSString *string = patchTextView.string;
    NSRange range = NSMakeRange(0, string.length);
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options: NSRegularExpressionAnchorsMatchLines error:&error];
    NSArray *matches = [regex matchesInString:string options:NSMatchingReportProgress range:range];
    [self highlightMatches:matches withColor:[NSColor colorFromHex:@"FF0891"]];
    if ([matches count] > 0)
    {
        NSLog(@"found binary patches / updates / additions");
        return (TRUE);
    }
    return FALSE;
}

- (void)performSyntaxHighlighting
{
    //  [self checkForBinaryMods];
    
    [self highlightFileSpecs]; //old style diff highlighting for files that have additions
    [self highlightFileSpecs2]; //stuff like @@ -38,11 +38,6 @@ static XCPullRequest *sharedPlugin;
    
    [self highlightInsertedLines]; //actual lines that are inserted
    [self highlightInsertedFileLines]; //ie +++ b/XCPullRequest/XCPullRequest.m
    
    [self highlightModifiedLines]; //lines that start with a ! (old diff files for exisiting lines that have changed)
    
    [self highlightRemovedLines]; //all actual removed lines
    [self highlightLocationLines]; //ie --- a/XCPullRequest/XCPullRequest.m
    
    [self highlightOldStyleInsertedLines]; //unneeded, just here for reference. git files that use > for line insertion rather than less
}

//(^|(?<=\A\s))\\!.*$

- (void)highlightModifiedLines
{
    NSError *error = NULL;
    NSString *pattern = @"(^|(?<=\\A\\s))\\!.*$";
    NSString *string = patchTextView.string;
    NSRange range = NSMakeRange(0, string.length);
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive | NSRegularExpressionAnchorsMatchLines error:&error];
    NSArray *matches = [regex matchesInString:string options:NSMatchingReportProgress range:range];
    [self highlightMatches:matches withColor:[NSColor colorFromHex:@"0E7CFF"]];
}

//(^|(?<=\A\s))[\\@]{2}.*$

- (void)highlightFileSpecs2
{
    NSError *error = NULL;
    NSString *pattern = @"(^|(?<=\\A\\s))[\\@]{2}.*[\\@]{2}";
    NSString *string = patchTextView.string;
    NSRange range = NSMakeRange(0, string.length);
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive  | NSRegularExpressionAnchorsMatchLines error:&error];
    NSArray *matches = [regex matchesInString:string options:NSMatchingReportProgress range:range];
    [self highlightMatches:matches withColor:[NSColor colorFromHex:@"4B79DE"]];
    
}

//(^|(?<=\A\s))\\-.*$
- (void)highlightRemovedLines
{
    NSError *error = NULL;
    NSString *pattern = @"(^|(?<=\\A\\s))\\-.*$";
    NSString *string = patchTextView.string;
    NSRange range = NSMakeRange(0, string.length);
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive  | NSRegularExpressionAnchorsMatchLines error:&error];
    NSArray *matches = [regex matchesInString:string options:NSMatchingReportProgress range:range];
    [self highlightMatches:matches withColor:[NSColor redColor]];
    [self highlightRemovedLinesTwo];
}

//(^|(?<=\A\s))(\\+){3}\\s.*$

- (void)highlightLocationLines //
{
    //#888822
    //(^|(?<=\A\s))-{3}\\s.*$
    NSError *error = NULL;
    NSString *pattern = @"(^|(?<=\\A\\s))-{3}\\s.*$";
    NSString *string = patchTextView.string;
    NSRange range = NSMakeRange(0, string.length);
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive  | NSRegularExpressionAnchorsMatchLines error:&error];
    NSArray *matches = [regex matchesInString:string options:NSMatchingReportProgress range:range];
    [self highlightMatches:matches withColor:[NSColor colorFromHex:@"2C5BCB"]];//2C5BCB
}

- (void)highlightRemovedLinesTwo
{
    //(^|(?<=\A\s))\\&lt;.*$
    NSError *error = NULL;
    NSString *pattern = @"(^|(?<=\\A\\s))\\<.*$";
    NSString *string = patchTextView.string;
    NSRange range = NSMakeRange(0, string.length);
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive  | NSRegularExpressionAnchorsMatchLines error:&error];
    NSArray *matches = [regex matchesInString:string options:NSMatchingReportProgress range:range];
    [self highlightMatches:matches withColor:[NSColor redColor]];
}

- (void)highlightInsertedFileLines
{
    //(^|(?<=\A\s))(\\+){3}\\s.*$
    NSError *error = NULL;
    NSString *pattern = @"(^|(?<=\\A\\s))(\\+){3}\\s.*$";
    NSString *string = patchTextView.string;
    NSRange range = NSMakeRange(0, string.length);
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive  | NSRegularExpressionAnchorsMatchLines  error:&error];
    NSArray *matches = [regex matchesInString:string options:NSMatchingReportProgress range:range];
    [self highlightMatches:matches withColor:[NSColor colorFromHex:@"2C5BCB"]];
}

//(^|(?<=\A\s))\\&gt;.*$
- (void)highlightOldStyleInsertedLines
{
    NSError *error = NULL;
    NSString *pattern = @"(^|(?<=\\A\\s))\\>.*$";
    NSString *string = patchTextView.string;
    NSRange range = NSMakeRange(0, string.length);
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive  | NSRegularExpressionAnchorsMatchLines | NSRegularExpressionUseUnixLineSeparators error:&error];
    NSArray *matches = [regex matchesInString:string options:NSMatchingReportProgress range:range];
    [self highlightMatches:matches withBGColor:[NSColor colorFromHex:@"00b000"] foregroundColor:[NSColor blackColor]];
}

//(^|(?<=\A\s))\\+.*$
- (void)highlightInsertedLines
{
    NSError *error = NULL;
    NSString *pattern = @"(^|(?<=\\A\\s))\\+.*$";
    NSString *string = patchTextView.string;
    NSRange range = NSMakeRange(0, string.length);
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive  | NSRegularExpressionAnchorsMatchLines | NSRegularExpressionUseUnixLineSeparators error:&error];
    NSArray *matches = [regex matchesInString:string options:NSMatchingReportProgress range:range];
    [self highlightMatches:matches withBGColor:[NSColor colorFromHex:@"00b000"] foregroundColor:[NSColor blackColor]];
}


//(^|(?<=\A\s))(\\*){3}\\s.*$

- (void)highlightFileSpecs
{
    NSError *error = NULL;
    NSString *pattern = @"(^|(?<=\\A\\s))(\\*){3}\\s.*$";
    NSString *string = patchTextView.string;
    NSRange range = NSMakeRange(0, string.length);
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators | NSRegularExpressionAnchorsMatchLines error:&error];
    NSArray *matches = [regex matchesInString:string options:NSMatchingReportProgress range:range];
    [self highlightMatches:matches withColor:[NSColor colorFromHex:@"888822"]];
    
}

- (void)highlightMatches:(NSArray *)matches withBGColor:(NSColor *)theColor foregroundColor:(NSColor *)foregroundColor
{
    __block NSMutableAttributedString *mutableAttributedString = patchTextView.attributedString.mutableCopy;
    
    [matches enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        
        if ([obj isKindOfClass:[NSTextCheckingResult class]])
        {
            NSTextCheckingResult *match = (NSTextCheckingResult *)obj;
            NSRange matchRange = match.range;
            [mutableAttributedString addAttribute:NSForegroundColorAttributeName value:foregroundColor range:matchRange];
            [mutableAttributedString addAttribute:NSBackgroundColorAttributeName value:theColor range:matchRange];
        }
    }];
    
    [[patchTextView textStorage] setAttributedString:mutableAttributedString.copy];
}

- (void)highlightMatches:(NSArray *)matches withColor:(NSColor *)theColor
{
    [self highlightMatches:matches withBGColor:theColor foregroundColor:[NSColor whiteColor]];
}



#pragma mark Patch Methods

- (NSString *)trimmedGITPatch:(NSString *)theFilePath
{
    NSString *patchString = [NSString stringWithContentsOfFile:theFilePath encoding:NSUTF8StringEncoding error:nil];
    NSInteger fileLength = [patchString length];
    
    NSInteger safeStart = fileLength - 1000;
    NSRange safeRange = NSMakeRange(safeStart, 1000);
    NSRange xmlRange = [patchString rangeOfString:kXCPullRequestBoundary options:NSCaseInsensitiveSearch range:safeRange];
    // NSRange xmlRange = [patchString rangeOfString:@"<?xml"];
    if (xmlRange.location == NSNotFound)
    {
        NSLog(@"there is no plist file in this patch, malformed!!: %@", patchString);
        return patchString;
    }
    //NSInteger trueLocation = safeStart + xmlRange.location;
    NSInteger adjustedLocation = xmlRange.location + kXCPullRequestBoundary.length;
    // NSInteger fileLength = [patchString length];
    NSInteger plistLength = (fileLength - xmlRange.location) - kXCPullRequestBoundary.length;
    NSRange xmlFileRange = NSMakeRange(adjustedLocation, plistLength);
    NSString *plistString = [patchString substringWithRange:xmlFileRange];
    plistDict = [plistString dictionaryFromString];
    NSString *tempGitPatch = [NSString stringWithFormat:@"/private/tmp/%@", [theFilePath lastPathComponent]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:tempGitPatch])
    {
        [[NSFileManager defaultManager] removeItemAtPath:tempGitPatch error:nil];
    }
    [plistString writeToFile:@"/private/tmp/tmpplist.plist" atomically:TRUE encoding:NSUTF8StringEncoding error:nil];
    
    
    NSRange patchRange = NSMakeRange(0, xmlRange.location);
    
    
    NSString *newPatch = [patchString substringWithRange:patchRange];
    // NSString *newPatch = [patchString substringToIndex:xmlRange.location];
    NSError *writeerror = nil;
    BOOL writeFile = [newPatch writeToFile:tempGitPatch atomically:TRUE encoding:NSUTF8StringEncoding error:&writeerror];
    //TODO: shouldn't rely on a temp path file, should have an app support folder or something these are saved to.
    
    if (writeFile == TRUE)
    {
        patchFilePath = tempGitPatch;
    } else {
    }
    return newPatch;
    
}

- (NSString *)signGITPatch:(NSString *)theFilePath
{
    NSString *originalContents = [NSString stringWithContentsOfFile:theFilePath encoding:NSUTF8StringEncoding error:nil];
    NSMutableString *patchString = [[NSMutableString alloc] initWithString:originalContents];
    NSString *userEmail = [self currentUserEmail];
    NSString *userName = [self currentUserName];
    [patchString replaceOccurrencesOfString:@"_USEREMAIL_" withString:userEmail options:NSCaseInsensitiveSearch range:NSMakeRange(0, [patchString length])];
    [patchString replaceOccurrencesOfString:@"_USERNAME_" withString:userName options:NSCaseInsensitiveSearch range:NSMakeRange(0, [patchString length])];
    NSError *scienceError = nil;
    [patchString writeToFile:theFilePath atomically:TRUE encoding:NSUTF8StringEncoding error:&scienceError];
    return patchString;
    
}

- (NSString *)projectGITReturnFromArguments:(NSArray *)arguments
{
    return [[XCTerminalUtils returnFromCommand:@"/usr/bin/git" withArguments:arguments inPath:[self projectPath]] componentsJoinedByString:@"\n"];
}

/*
 
 On branch newtest
 nothing to commit, working directory clean
 
 */

- (NSString *)currentGITStatus
{
    return [self projectGITReturnFromArguments:@[@"status"]];
}

- (BOOL)statusIsClean
{
    NSString *gitStatus = [self currentGITStatus];
    NSLog(@"git status: %@", gitStatus);
    if ([gitStatus rangeOfString:@"nothing to commit, working directory clean"].location == NSNotFound)
    {
        return FALSE;
    }
    return TRUE;
}

- (NSString *)checkGITPatch:(NSString *)thePatch againstProject:(NSString *)theProject
{
    if ([self statusIsClean] == FALSE)
    {
        return @"Can't verify patch validity, there are uncommitted changes on the current local branch!";
    }
    NSString *currentGITBranch = [self currentGITBranch];
    if (![currentGITBranch isEqualToString:@"master"])
    {
        [XCTerminalUtils returnFromCommand:@"/usr/bin/git" withArguments:[NSArray arrayWithObjects:@"checkout", @"master", nil] inPath:[self projectPath]];
    }
    NSArray *gitCheck = [XCTerminalUtils returnFromCommand:@"/usr/bin/git" withArguments:@[@"apply", @"--check", thePatch] inPath:[self projectPath]];
    //NSLog(@"gitCheckCount: %lu", (unsigned long)[gitCheck count]);
    if (![currentGITBranch isEqualToString:@"master"])
    {
        [XCTerminalUtils returnFromCommand:@"/usr/bin/git" withArguments:@[@"checkout", currentGITBranch] inPath:[self projectPath]];
    }
    if ([gitCheck count] > 1)
    {
        NSLog(@"got an error: -%@-", [gitCheck componentsJoinedByString:@"\n"]);
        return ([gitCheck componentsJoinedByString:@"\n"]);
    }
    return (nil);
}

- (NSString *)applyGITPatch:(NSString *)thePatch toProject:(NSString *)theProject
{
    
    NSString *scriptPath = [[delegate bundle] pathForResource:@"patch" ofType:@"sh"];
    NSString *commandString = [NSString stringWithFormat:@"/bin/bash \"%@\" '%@' '%@'",scriptPath, theProject, thePatch];
    //NSLog(@"commandString: %@", commandString);
    return [XCTerminalUtils stringReturnForProcess:commandString];
    
}

- (void)abortPatch
{
    NSString *failString = [NSString stringWithFormat:@"\n\n#### MERGE FAILED! running 'git am --abort' automatically...\n\nReloading patch contents...\n\n %@", [self patchContents]];
    [self addTextToView:failString];
    [XCTerminalUtils returnFromCommand:@"/usr/bin/git" withArguments:[NSArray arrayWithObjects:@"am", @"--abort", nil] inPath:[self projectPath]];
}


- (void)updatePatchEnabled
{
    [mergeItem setEnabled:FALSE];
    if ([self projectPath] == nil)
    {
        self.patchEnabled = FALSE;
        return;
    }
    
    if (patchTextView.string.length == 0)
    {
        self.patchEnabled = FALSE;
        return;
    }
    
    BOOL binaryMods = [self checkForBinaryMods];
    
    //passed the dumb null checks
    if (binaryMods == TRUE)
        //if ([patchTextView.string rangeOfString:@"Binary files"].location != NSNotFound)
    {
        self.patchEnabled = FALSE;
        /*
        [[self delegate] setMergeBranchMode:TRUE]; //we will turn this off if the merge test below fails.
        NSAlert *errorAlert = [NSAlert alertWithMessageText:@"Merge Problems Detected" defaultButton:@"OK" alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:@"%@", @"This pull request contains binary file additions or changes, this cannot be processed. Would you like to automatically reject this pull request?"];
        NSLog(@"binary files changes / additions detected. should we autoreject?");
        NSModalResponse modalResponse = [errorAlert runModal];
        switch (modalResponse) {
                
            case NSAlertDefaultReturn: //OK
                
                [self rejectPullRequestWithComment:@"There are binary file changes or additions in this pull request, this cannot be applied without a direct merge."];
                break;
                
            case NSAlertAlternateReturn: //cancel
                
                break;
                
        }
         */
         [[(XCPRWindow *)self.window companionMenuItem] setState:1];
     //   return;
    }
    
    NSString *patchCheckReturn = [self checkGITPatch:patchFilePath againstProject:[self projectPath]];
   // if ([self checkGITPatch:patchFilePath againstProject:[self projectPath]] == FALSE)
    if (patchCheckReturn != nil)
    {
        NSLog(@"patch should not be enabled!");
        
        [[self delegate] setMergeBranchMode:FALSE];
        NSAlert *patchErrorAlert = [NSAlert alertWithMessageText:@"Patch Error" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Dry run for patch failed with error: %@", patchCheckReturn];
       [patchErrorAlert runModal];
        return;
    }
    
     [[(XCPRWindow *)self.window companionMenuItem] setState:1];
    //if its gotten this far, i guess we are okay?
    
    [mergeItem setEnabled:TRUE];
    self.patchEnabled = TRUE;
    
}

- (void)logWindowMode
{
    [self.window.toolbar setVisible:FALSE];
    [self.window setTitle:@"Merge Results Log"];
}

# pragma mark Actions

- (NSString *)mergeBranchToMasterOnProject:(NSString *)theProject
{
    NSString *commandString = [NSString stringWithFormat:@"pushd '%@' ; git checkout master ; git merge %@",theProject, [self branchName]];
    //NSLog(@"commandString: %@", commandString);
    NSString *commandReturn = [XCTerminalUtils stringReturnForProcess:commandString];
    if ([commandReturn rangeOfString:@"fatal"].location != NSNotFound)
    {
        //failed!!
        NSLog(@"#### merge failed with message: %@ aborting merge!!", commandReturn);
        [self projectGITReturnFromArguments:@[@"merge", @"--abort"]];
        return commandReturn;
    }

    // if we got this far the merge should have been clean!, commit!
    
    NSString *pushString = [self projectGITReturnFromArguments:@[@"push", @"origin", @"master"]];
    return [commandReturn stringByAppendingFormat:@"\n%@\n", pushString];

}

//git merge --abort
- (void)mergeBranchToMaster
{
    NSAlert *mergeCheckAlert = [NSAlert alertWithMessageText:@"Merge branch into master?" defaultButton:@"Merge" alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:@"There are binary file changes so a direct application of the patch is not possible. As an alternative you can attempt to merge %@ into master. Do you want to do this? These changes cannot be easily reverted!!", [self branchName]];
    NSModalResponse modalResponse = [mergeCheckAlert runModal];
    switch (modalResponse) {
            
        case NSAlertDefaultReturn: //OK
            //NSLog(@"merge selected, continuing with merge operation!!");
            [mergeItem setEnabled:FALSE];
            break;
            
        case NSAlertAlternateReturn: //cancel
            //NSLog(@"CANCEL merge selected!!");
            return;
    }
    NSString *projectPath = [self projectPath];
    //NSLog(@"project path: %@", projectPath);
    
    if (projectPath == nil)
    {
        NSLog(@"bail for now, can't find a proper project folder");
        return;
    }
    
    NSString *progressOutput = [self mergeBranchToMasterOnProject:projectPath];
    
   // NSString *progressOutput = [self applyGITPatch:patchFilePath toProject:projectPath];
    patchTextView.string = progressOutput;
    
    [self logWindowMode];
    
    NSDictionary *acceptDict = nil;
    
    if ([progressOutput rangeOfString:@"fatal"].location != NSNotFound)
    {
        NSLog(@"FAIL!!!");
        
        acceptDict = @{@"ProjectName": [self projectName], @"Email": submittersEmail, @"Status": @"Accepted but failed to merge", @"ProjectBranch": [self branchName], @"ServerName": [delegate defaultServerAddress], @"ResponseUser": [self currentUserName] };
        [self sendDictionaryToServer:acceptDict];
        
        return;
    }
  
    
    acceptDict = @{@"ProjectName": [self projectName], @"Email": [delegate emailDevsString], @"Status": @"Accepted and successfully merged", @"ProjectBranch": [self branchName], @"ServerName": [delegate defaultServerAddress], @"ResponseUser": [self currentUserName]};
    [self sendDictionaryToServer:acceptDict];
}

-(IBAction)mergeToMaster:(id)sender
{
    if ([[self delegate] mergeBranchMode] == TRUE)
    {
        [self mergeBranchToMaster];
        return;
    }
    
    NSAlert *mergeCheckAlert = [NSAlert alertWithMessageText:@"Merge Request?" defaultButton:@"Merge" alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:@"Are you sure you want to merge this pull request? these changes cannot be easily reverted!!"];
    NSModalResponse modalResponse = [mergeCheckAlert runModal];
    switch (modalResponse) {
            
        case NSAlertDefaultReturn: //OK
            //NSLog(@"merge selected, continuing with merge operation!!");
            [mergeItem setEnabled:FALSE];
            break;
            
        case NSAlertAlternateReturn: //cancel
            //NSLog(@"CANCEL merge selected!!");
            return;
    }
    NSString *projectPath = [self projectPath];
    //NSLog(@"project path: %@", projectPath);
    
    if (projectPath == nil)
    {
        NSLog(@"bail for now, can't find a proper project folder");
        return;
    }
    
    NSString *progressOutput = [self applyGITPatch:patchFilePath toProject:projectPath];
    patchTextView.string = progressOutput;
       [self logWindowMode];
    NSDictionary *acceptDict = nil;
    
    if ([progressOutput rangeOfString:@"git am --abort"].location != NSNotFound)
    {
        NSLog(@"FAIL!!!");
        
        [self abortPatch];
        
        acceptDict = @{@"ProjectName": [self projectName], @"Email": submittersEmail, @"Status": @"Accepted but failed to merge", @"ProjectBranch": [self branchName], @"ServerName": [delegate defaultServerAddress], @"ResponseUser": [self currentUserName] };
        [self sendDictionaryToServer:acceptDict];
        
        return;
    }
    if ([progressOutput rangeOfString:@"still exists but mbox given."].location != NSNotFound)
    {
        NSLog(@"FAIL!!!");
        [self abortPatch];
        acceptDict = @{@"ProjectName": [self projectName], @"Email": submittersEmail, @"Status": @"Accepted but failed to merge", @"ProjectBranch": [self branchName], @"ServerName": [delegate defaultServerAddress], @"ResponseUser": [self currentUserName] };
        
        
        [self sendDictionaryToServer:acceptDict];
        return;
    }
    
    acceptDict = @{@"ProjectName": [self projectName], @"Email": [delegate emailDevsString], @"Status": @"Accepted and successfully merged", @"ProjectBranch": [self branchName], @"ServerName": [delegate defaultServerAddress], @"ResponseUser": [self currentUserName]};
    [self sendDictionaryToServer:acceptDict];
    
}

/*
 
 $projectName = $obj['ProjectName'];
 $emailAddress = $obj['Email'];
 $projectStatus = $obj['Status'];
 $subject = "Pull Request for " . $projectName . " has been " . $projectStatus;
 $branch = $obj['ProjectBranch'];
 $user = $obj['ResponseUser'];
 $comment = $obj['Comment'];
 $serverName = $obj['ServerName'];
 
 */

- (void)sendDictionaryToServer:(NSDictionary *)theDict
{
    NSString *outputFile = @"/private/var/tmp/process.plist";
    [theDict writeToFile:outputFile atomically:TRUE];
    [delegate postFile:outputFile];
}

- (void)rejectPullRequestWithComment:(NSString *)theComment
{
    NSDictionary *rejectDict = @{@"ProjectName": [self projectName], @"Email": submittersEmail, @"Status": @"rejected", @"ProjectBranch": [self branchName], @"Comment": theComment, @"ServerName": [delegate defaultServerAddress], @"ResponseUser": [self currentUserName] };
    [self sendDictionaryToServer:rejectDict];
}

-(IBAction)rejectPullRequest:(id)sender
{
    NSString *rejectionQuery = [self queryForRejectionComment];
    NSDictionary *rejectDict = @{@"ProjectName": [self projectName], @"Email": submittersEmail, @"Status": @"rejected", @"ProjectBranch": [self branchName], @"Comment": rejectionQuery, @"ServerName": [delegate defaultServerAddress], @"ResponseUser": [self currentUserName] };
    [self sendDictionaryToServer:rejectDict];
    
}

- (NSString *)queryForRejectionComment
{
    NSAlert *alertWithAux = [NSAlert alertWithMessageText:@"Please enter the reason for this rejecting this pull request!" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
    
    rejectTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 44)];
    [rejectTextField setEditable:TRUE];
    [rejectTextField setBordered:TRUE];
    
    NSView *viewTextEntry = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 340, 44)];
    [viewTextEntry addSubview:rejectTextField];
    [alertWithAux setAccessoryView:viewTextEntry];
    
    [alertWithAux runModal];
    
    return rejectTextField.stringValue;
}

#pragma mark Email processing







@end
