//
//  XCPRModel.m
//  XToDo
//
//  Created by Travis on 13-11-28.
//  Copyright (c) 2013年 Plumn LLC. All rights reserved.
//

#import "XCPRModel.h"
#import <objc/runtime.h>

//#import "XToDoPreferencesWindowController.h"

#import "NSData+Split.h"

static NSBundle *pluginBundle;


@implementation XCPRModel

+ (NSString *)applicationSupportFolder
{
    NSBundle *ourBundle = [NSBundle bundleForClass:objc_getClass("XCPullRequest")];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    basePath = [basePath stringByAppendingPathComponent:[[ourBundle infoDictionary] objectForKey:(NSString *)kCFBundleNameKey]];
    if (![[NSFileManager defaultManager] fileExistsAtPath:basePath])
        [[NSFileManager defaultManager] createDirectoryAtPath:basePath withIntermediateDirectories:YES attributes:nil error:nil];
    
    return basePath;
}

+ (IDEWorkspaceTabController*)tabController{
    NSWindowController *currentWindowController = [[NSApp keyWindow] windowController];
    if ([currentWindowController isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")]) {
        IDEWorkspaceWindowController *workspaceController = (IDEWorkspaceWindowController *)currentWindowController;
        
        return workspaceController.activeWorkspaceTabController;
    }
    return nil;
}

+ (id)currentEditor {
    NSWindowController *currentWindowController = [[NSApp mainWindow] windowController];
    if ([currentWindowController isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")]) {
        IDEWorkspaceWindowController *workspaceController = (IDEWorkspaceWindowController *)currentWindowController;
        IDEEditorArea *editorArea = [workspaceController editorArea];
        IDEEditorContext *editorContext = [editorArea lastActiveEditorContext];
        return [editorContext editor];
    }
    return nil;
}
+ (IDEWorkspaceDocument *)currentWorkspaceDocument {
    NSWindowController *currentWindowController = [[NSApp mainWindow] windowController];
    id document = [currentWindowController document];
    if (currentWindowController && [document isKindOfClass:NSClassFromString(@"IDEWorkspaceDocument")]) {
        return (IDEWorkspaceDocument *)document;
    }
    return nil;
}

+ (IDESourceCodeDocument *)currentSourceCodeDocument {
    
    IDESourceCodeEditor *editor=[self currentEditor];
    
    if ([editor isKindOfClass:NSClassFromString(@"IDESourceCodeEditor")]) {
        return editor.sourceCodeDocument;
    }
    
    if ([editor isKindOfClass:NSClassFromString(@"IDESourceCodeComparisonEditor")]) {
        if ([[(IDESourceCodeComparisonEditor*)editor primaryDocument] isKindOfClass:NSClassFromString(@"IDESourceCodeDocument")]) {
            return (id)[(IDESourceCodeComparisonEditor *)editor primaryDocument];
        }
    }
    
    return nil;
}

+ (IDESourceControlWorkspaceMonitor *)sourceControlMonitor
{
    return [XCPRModel currentWorkspaceDocument].workspace.sourceControlWorkspaceMonitor;
    
}

//TESTME: some tests!
/*
+ (NSString*)scannedStrings {
    NSArray* prefsStrings = [[NSUserDefaults standardUserDefaults] objectForKey:kXToDoTagsKey];
    NSMutableArray* escapedStrings = [NSMutableArray arrayWithCapacity:[prefsStrings count]];
    
    for (NSString* origStr in prefsStrings) {
        NSMutableString* str = [NSMutableString string];
        
        for (NSUInteger i=0; i<[origStr length]; i++) {
            unichar c = [origStr characterAtIndex:i];
            
            if (!isalpha(c) && ! isnumber(c)) {
                [str appendFormat:@"\\%C", c];
            } else {
                [str appendFormat:@"%C", c];
            }
        }
        
        [str appendFormat:@"\\:"];
        
        [escapedStrings addObject:str];
    }
    
    return [escapedStrings componentsJoinedByString:@"|"];
}
*/

typedef void(^OnFindedItem)(NSString *fullPath, BOOL isDirectory,  BOOL *skipThis, BOOL *stopAll);
+ (void) scanFolder:(NSString*)folder findedItemBlock:(OnFindedItem)findedItemBlock
{
    BOOL stopAll = NO;
    
    NSFileManager* localFileManager = [[NSFileManager alloc] init];
    NSDirectoryEnumerationOptions option = NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsPackageDescendants;
    NSDirectoryEnumerator* directoryEnumerator = [localFileManager enumeratorAtURL:[NSURL fileURLWithPath:folder]
                                                        includingPropertiesForKeys:nil
                                                                           options:option
                                                                      errorHandler:nil];
    for (NSURL* theURL in directoryEnumerator)
    {
        if (stopAll)
        {
            break;
        }
        
        NSString *fileName = nil;
        [theURL getResourceValue:&fileName forKey:NSURLNameKey error:NULL];
        
        NSNumber *isDirectory = nil;
        [theURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL];
        
        BOOL skinThis = NO;
        
        BOOL directory = [isDirectory boolValue];
        
        findedItemBlock([theURL path], directory, &skinThis, &stopAll);
        
        if (skinThis)
        {
            [directoryEnumerator skipDescendents];
        }
    }
}


+ (NSArray *)removeSubDirs:(NSArray*)dirs
{
    // TODO:
    return dirs;
}

+ (NSSet *)lowercaseFileTypes:(NSSet *)fileTypes
{
    NSMutableSet *set = [NSMutableSet setWithCapacity:[fileTypes count]];
    for (NSString * fileType in fileTypes)
    {
        [set addObject:[fileType lowercaseString]];
    }
    return set;
}

+ (NSArray*)findFileNameWithProjectPath:(NSString *)projectPath
                            includeDirs:(NSArray *)includeDirs
                            excludeDirs:(NSArray *)excludeDirs
                              fileTypes:(NSSet *)fileTypes
{
    includeDirs = [XCPRModel explandRootPathMacros:includeDirs projectPath:projectPath];
    includeDirs = [XCPRModel removeSubDirs:includeDirs];
    excludeDirs = [XCPRModel explandRootPathMacros:excludeDirs projectPath:projectPath];
    excludeDirs = [XCPRModel removeSubDirs:excludeDirs];
    fileTypes   = [XCPRModel lowercaseFileTypes:fileTypes];
    NSMutableArray *allFilePaths = [NSMutableArray arrayWithCapacity:1000];
    for (NSString *includeDir in includeDirs)
    {
        [XCPRModel scanFolder:includeDir findedItemBlock:^(NSString *fullPath, BOOL isDirectory, BOOL *skipThis, BOOL *stopAll) {
            if (isDirectory)
            {
                for (NSString *excludeDir in excludeDirs)
                {
                    if ([fullPath hasPrefix:excludeDir])
                    {
                        *skipThis = YES;
                        return;
                    }
                }
            }
            else
            {
                if ([fileTypes containsObject:[[fullPath pathExtension] lowercaseString]])
                {
                    [allFilePaths addObject:fullPath];
                }
            }
            
        }];
    }
    return allFilePaths;
}




+ (NSString *) _settingDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    // TODO [path count] == 0
    NSString *settingDirectory = [(NSString *)[paths objectAtIndex:0] stringByAppendingPathComponent:@"XCPullRequest"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:settingDirectory] == NO)
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:settingDirectory
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
    }
    return settingDirectory;
}

+ (NSString *) _tempFileDirectory
{
    NSString *tempFileDirectory = [[XCPRModel _settingDirectory] stringByAppendingPathComponent:@"Temp"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:tempFileDirectory] == NO)
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:tempFileDirectory
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
    }
    return tempFileDirectory;
}

+ (void) cleanAllTempFiles
{
    [XCPRModel scanFolder:[XCPRModel _tempFileDirectory] findedItemBlock:^(NSString *fullPath, BOOL isDirectory, BOOL *skipThis, BOOL *stopAll) {
        [[NSFileManager defaultManager] removeItemAtPath:fullPath error:nil];
    }];
}

+ (NSString *)currentProjectFile
{
    NSString *filePath = [[XCPRModel currentWorkspaceDocument].workspace.representingFilePath.fileURL path];
    //NSString *projectDir= [filePath stringByDeletingLastPathComponent];
    return filePath;
}

+ (NSString *)currentRootPath
{
    NSString *filePath = [[XCPRModel currentWorkspaceDocument].workspace.representingFilePath.fileURL path];
    return [filePath stringByDeletingLastPathComponent];
}

+ (NSString *) rootPathMacro
{
    return [XCPRModel addPathSlash:@"$(SRCROOT)"];
}

+ (NSArray *) explandRootPathMacros:(NSArray *)paths projectPath:(NSString *)projectPath
{
    if (projectPath == nil)
    {
        return paths;
    }
    
    NSMutableArray *explandPaths = [NSMutableArray arrayWithCapacity:[paths count]];
    for (NSString *path in paths) {
        [explandPaths addObject:[XCPRModel explandRootPathMacro:path projectPath:projectPath]];
    }
    return explandPaths;
}

+ (NSString *) addPathSlash:(NSString *)path
{
    if ([path length] > 0)
    {
        if ([path characterAtIndex:([path length] - 1)] != '/')
        {
            path = [NSString stringWithFormat:@"%@/", path];
        }
    }
    return path;
}

+ (NSString *) explandRootPathMacro:(NSString *)path projectPath:(NSString *)projectPath
{
    projectPath = [XCPRModel addPathSlash:projectPath];
    path = [path stringByReplacingOccurrencesOfString:[XCPRModel rootPathMacro] withString:projectPath];
    
    return [XCPRModel addPathSlash:path];
}

+ (NSString *) settingFilePathByProjectName:(NSString *)projectName
{
    NSString *settingDirectory = [XCPRModel _settingDirectory];
    NSString *fileName = [projectName length] ? projectName : @"Test.xcodeproj";
    return [settingDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist",fileName]];
}



+ (XCPRProjectSetting *) projectSettingByProjectName:(NSString *)projectName
{
    static NSMutableDictionary *projectName2ProjectSetting = nil;
    if (projectName2ProjectSetting == nil)
    {
        projectName2ProjectSetting = [[NSMutableDictionary alloc] init];
    }
    
    if (projectName != nil)
    {
        id object = [projectName2ProjectSetting objectForKey:projectName];
        if ([object isKindOfClass:[XCPRProjectSetting class]])
        {
            return object;
        }
    }
    
    NSString *fullPath = [XCPRModel settingFilePathByProjectName:projectName];
    XCPRProjectSetting *projectSetting = nil;
    @try {
        projectSetting = [NSKeyedUnarchiver unarchiveObjectWithFile:fullPath];
    }
    @catch (NSException *exception) {
    }
    if ([projectSetting isKindOfClass:[projectSetting class]] == NO){
        projectSetting = nil;
    }
    
    if (projectSetting == nil) {
        projectSetting = [XCPRProjectSetting defaultProjectSetting];
    }
    if ((projectSetting != nil) && (projectName != nil))
    {
        [projectName2ProjectSetting setObject:projectSetting forKey:projectName];
    }
    return projectSetting;
}

+ (void) saveProjectSetting:(XCPRProjectSetting *)projectSetting ByProjectName:(NSString *)projectName
{
    if (projectSetting == nil)
    {
        return;
    }
    @try {
        NSString *filePath = [XCPRModel settingFilePathByProjectName:projectName];
        [NSKeyedArchiver archiveRootObject:projectSetting
                                    toFile:filePath];
        filePath = nil;
    }
    @catch (NSException *exception) {
        NSLog(@"saveProjectSetting:exception:%@", exception);
    }
    NSLog(@"haha");
}

@end
