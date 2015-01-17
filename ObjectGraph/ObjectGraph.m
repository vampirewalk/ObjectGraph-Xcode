//
//  ObjectGraph.m
//  ObjectGraph
//
//  Created by vampirewalk on 2015/1/13.
//  Copyright (c) 2015年 mocacube. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.

#import "ObjectGraph.h"
#import "VWKShellHandler.h"
#import "VWKWorkspaceManager.h"
#import "VWKProject.h"

static ObjectGraph *sharedPlugin;

static NSString *BIN_PATH = @"/bin";
static NSString *USER_BIN_PATH = @"/usr/bin";
static NSString *USER_LOCAL_BIN_PATH = @"/usr/local/bin";

static NSString *PYTHON_EXECUTABLE = @"python";
static NSString *GRAPHVIZ_EXECUTABLE = @"dot";
static NSString *MOVE_EXECUTABLE = @"mv";
static NSString *OPEN_EXECUTABLE = @"open";

@interface ObjectGraph()

@property (nonatomic, strong, readwrite) NSBundle *bundle;

@property (nonatomic, strong) NSMenuItem *drawObjectGrpahItem;
@property (nonatomic, strong) NSMenuItem *pathItem;

@property (nonatomic, copy) NSString *sourceCodePath;

@end

@implementation ObjectGraph

+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[self alloc] initWithBundle:plugin];
        });
    }
}

+ (instancetype)sharedPlugin
{
    return sharedPlugin;
}

+ (NSBundle *)pluginBundle
{
    return [NSBundle bundleForClass:self];
}

- (id)initWithBundle:(NSBundle *)plugin
{
    if (self = [super init]) {
        // reference to plugin's bundle, for resource access
        self.bundle = plugin;
        
        [self setDefaultSourceCodePathPath];
        
        // Create menu items, initialize UI, etc.
        [self addMenuItems];
    }
    return self;
}

- (void)setDefaultSourceCodePathPath
{
    VWKProject *project = [VWKProject projectForKeyWindow];
    self.sourceCodePath = project.directoryPath;
}


#pragma mark - Menu

- (void)addMenuItems
{
    NSMenuItem *topMenuItem = [[NSApp mainMenu] itemWithTitle:@"Product"];
    if (topMenuItem) {
        NSMenuItem *objectGraphMenu = [[NSMenuItem alloc] initWithTitle:@"ObjectGraph" action:nil keyEquivalent:@""];
        objectGraphMenu.submenu = [[NSMenu alloc] initWithTitle:@"ObjectGraph"];
        
        self.drawObjectGrpahItem = [[NSMenuItem alloc] initWithTitle:@"Draw Object Grpah" action:@selector(drawObjectGrpah) keyEquivalent:@""];
        [self.drawObjectGrpahItem setTarget:self];
        
        
        self.pathItem = [[NSMenuItem alloc] initWithTitle:@"Set Source Code PATH..." action:@selector(selectPath) keyEquivalent:@""];
        [self.pathItem setTarget:self];
        
        [[objectGraphMenu submenu] addItem:self.drawObjectGrpahItem];
        [[objectGraphMenu submenu] addItem:self.pathItem];
        
        
        [[topMenuItem submenu] insertItem:objectGraphMenu atIndex:[topMenuItem.submenu indexOfItemWithTitle:@"Build For"]];
    }
}

#pragma mark - Menu Actions

// Sample Action, for menu item:
- (void)drawObjectGrpah
{
    VWKProject *project = [VWKProject projectForKeyWindow];
    NSString *projectPath = project.directoryPath;
    
    if([self isSourceCodePathValid])
    {
        self.sourceCodePath = projectPath;
    }
    
    NSString *pngFileName = [self pngFileName];
    NSString *dotFileName = [self dotFileName];
    
    NSString *dotFileScriptPath = [[ObjectGraph pluginBundle] pathForResource:@"objc_dep" ofType:@"py"];
    
    __weak __typeof(&*self)weakSelf = self;
    
    if (dotFileScriptPath.length) {
        void(^openBlock)(NSTask *t) = ^(NSTask *t){
            [VWKShellHandler runShellCommand:[USER_BIN_PATH stringByAppendingPathComponent:OPEN_EXECUTABLE]
                                    withArgs:@[pngFileName]
                                   directory:projectPath
                                  completion:nil];
        };
        
        void(^moveDOTFileBlock)(NSTask *t) = ^(NSTask *t){
            __strong __typeof(&*weakSelf)strongSelf = weakSelf;
            [VWKShellHandler runShellCommand:[BIN_PATH stringByAppendingPathComponent:MOVE_EXECUTABLE]
                                    withArgs:@[dotFileName, projectPath]
                                   directory:strongSelf.sourceCodePath
                                  completion:openBlock];
        };
        
        void(^movePNGFileBlock)(NSTask *t) = ^(NSTask *t){
            __strong __typeof(&*weakSelf)strongSelf = weakSelf;
            [VWKShellHandler runShellCommand:[BIN_PATH stringByAppendingPathComponent:MOVE_EXECUTABLE]
                                    withArgs:@[pngFileName, projectPath]
                                   directory:strongSelf.sourceCodePath
                                  completion:moveDOTFileBlock];
        };
        
        void(^convertToPNGBlock)(NSTask *t) = ^(NSTask *t){
            __strong __typeof(&*weakSelf)strongSelf = weakSelf;
            [VWKShellHandler runShellCommand:[USER_LOCAL_BIN_PATH stringByAppendingPathComponent:GRAPHVIZ_EXECUTABLE]
                                    withArgs:@[@"-Tpng", dotFileName, @"-o", pngFileName]
                                   directory:strongSelf.sourceCodePath
                                  completion:movePNGFileBlock];
        };
        
        [VWKShellHandler runShellCommand:[USER_BIN_PATH stringByAppendingPathComponent:PYTHON_EXECUTABLE]
                                withArgs:@[dotFileScriptPath, _sourceCodePath, @"-o", dotFileName]
                               directory:_sourceCodePath
                              completion:convertToPNGBlock];
    }
}

- (void)selectPath
{
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setCanChooseDirectories:YES];
    [oPanel setCanChooseFiles:NO];
    if ([oPanel runModal] == NSModalResponseOK) {
        NSString *projPath = [[[oPanel URLs] objectAtIndex:0] path];
        self.sourceCodePath = projPath;
    }
}

#pragma mark - Private Method

- (NSString *)dotFileName
{
    VWKProject *project = [VWKProject projectForKeyWindow];
    NSString *dotFileName = [project.projectName stringByAppendingString:@".dot"];
    return dotFileName;
}

- (NSString *)pngFileName
{
    VWKProject *project = [VWKProject projectForKeyWindow];
    NSString *pngFileName = [project.projectName stringByAppendingString:@".png"];
    return pngFileName;
}

- (BOOL)isSourceCodePathValid
{
    NSFileManager *manager = [NSFileManager defaultManager];
    return _sourceCodePath == nil || ![manager fileExistsAtPath:_sourceCodePath];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
