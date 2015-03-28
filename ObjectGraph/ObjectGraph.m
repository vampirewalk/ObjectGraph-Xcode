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

typedef void(^TaskBlock)(NSTask *t, NSString *standardOutputString, NSString *standardErrorString);

@interface ObjectGraph()
@property (nonatomic, strong, readwrite) NSBundle *bundle;
@property (nonatomic, strong) NSMenuItem *drawObjectGraphItem;
@property (nonatomic, strong) NSMenuItem *pathItem;
@property (nonatomic, copy) NSString *sourceCodePath;
@property (nonatomic, copy) TaskBlock getGraphvizExecutablePathBlock;
@property (nonatomic, copy) TaskBlock convertToPNGBlock;
@property (nonatomic, copy) TaskBlock movePNGFileBlock;
@property (nonatomic, copy) TaskBlock moveDOTFileBlock;
@property (nonatomic, copy) TaskBlock openBlock;

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
        
        [self setupGetGraphvizExecutablePathBlock];
        [self setupConvertToPNGBlock];
        [self setupMovePNGFileBlock];
        [self setupMoveDOTFileBlock];
        [self setupOpenBlock];
        
        
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
        
        self.drawObjectGraphItem = [[NSMenuItem alloc] initWithTitle:@"Draw Object Graph" action:@selector(drawObjectGraph) keyEquivalent:@""];
        [self.drawObjectGraphItem setTarget:self];
        
        
        self.pathItem = [[NSMenuItem alloc] initWithTitle:@"Set Source Code PATH..." action:@selector(selectPath) keyEquivalent:@""];
        [self.pathItem setTarget:self];
        
        [[objectGraphMenu submenu] addItem:self.drawObjectGraphItem];
        [[objectGraphMenu submenu] addItem:self.pathItem];
        
        
        [[topMenuItem submenu] insertItem:objectGraphMenu atIndex:[topMenuItem.submenu indexOfItemWithTitle:@"Build For"]];
    }
}

#pragma mark - Menu Actions

// Sample Action, for menu item:
- (void)drawObjectGraph
{
    if([self isValidSourceCodePath])
    {
        self.sourceCodePath = self.projectPath;
    }
    
    NSString *dotFileScriptPath = [[ObjectGraph pluginBundle] pathForResource:@"objc_dep" ofType:@"py"];
    if (dotFileScriptPath.length) {
        [VWKShellHandler runShellCommand:[USER_BIN_PATH stringByAppendingPathComponent:PYTHON_EXECUTABLE]
                                withArgs:@[dotFileScriptPath, _sourceCodePath, @"-o", self.dotFileName]
                               directory:_sourceCodePath
                              completion:self.getGraphvizExecutablePathBlock];
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
    NSString *dotFileName = [project.projectName stringByAppendingPathExtension:@"dot"];
    return dotFileName;
}

- (NSString *)pngFileName
{
    VWKProject *project = [VWKProject projectForKeyWindow];
    NSString *pngFileName = [project.projectName stringByAppendingPathExtension:@"png"];
    return pngFileName;
}

- (NSString *)projectPath
{
    VWKProject *project = [VWKProject projectForKeyWindow];
    NSString *projectPath = project.directoryPath;
    return projectPath;
}

- (BOOL)isValidSourceCodePath
{
    NSFileManager *manager = [NSFileManager defaultManager];
    return _sourceCodePath == nil || ![manager fileExistsAtPath:_sourceCodePath];
}

- (void)setupGetGraphvizExecutablePathBlock
{
    NSDictionary *environmentDict = [[NSProcessInfo processInfo] environment];
    NSString *shellString = [environmentDict objectForKey:@"SHELL"];
    
    NSArray *args = @[@"-l",
                      @"-c",
                      @"which dot", //Assuming git is the launch path you want to run
                      ];
    __weak __typeof(&*self)weakSelf = self;
    self.getGraphvizExecutablePathBlock = ^(NSTask *t,
                               NSString *standardOutputString,
                               NSString *standardErrorString)
    {
        __strong __typeof(&*weakSelf)strongSelf = weakSelf;
        [VWKShellHandler runShellCommand:shellString
                                withArgs:args
                               directory:strongSelf.sourceCodePath
                              completion:strongSelf.convertToPNGBlock];
    };
}

- (void)setupConvertToPNGBlock
{
    __weak __typeof(&*self)weakSelf = self;
    self.convertToPNGBlock = ^(NSTask *t,
                               NSString *standardOutputString,
                               NSString *standardErrorString){
        __strong __typeof(&*weakSelf)strongSelf = weakSelf;
        if (standardOutputString.length > 0) {
            NSString *GRAPHVIZ_EXECUTABLE_PATH = [standardOutputString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            [VWKShellHandler runShellCommand:GRAPHVIZ_EXECUTABLE_PATH
                                    withArgs:@[@"-Tpng", strongSelf.dotFileName, @"-o", strongSelf.pngFileName]
                                   directory:strongSelf.sourceCodePath
                                  completion:strongSelf.movePNGFileBlock];
        }
    };
}

- (void)setupMovePNGFileBlock
{
    __weak __typeof(&*self)weakSelf = self;
    self.movePNGFileBlock = ^(NSTask *t,
                              NSString *standardOutputString,
                              NSString *standardErrorString){
        __strong __typeof(&*weakSelf)strongSelf = weakSelf;
        [VWKShellHandler runShellCommand:[BIN_PATH stringByAppendingPathComponent:MOVE_EXECUTABLE]
                                withArgs:@[strongSelf.pngFileName, strongSelf.projectPath]
                               directory:strongSelf.sourceCodePath
                              completion:strongSelf.moveDOTFileBlock];
    };
}

- (void)setupMoveDOTFileBlock
{
    __weak __typeof(&*self)weakSelf = self;
    self.moveDOTFileBlock = ^(NSTask *t,
                              NSString *standardOutputString,
                              NSString *standardErrorString){
        __strong __typeof(&*weakSelf)strongSelf = weakSelf;
        [VWKShellHandler runShellCommand:[BIN_PATH stringByAppendingPathComponent:MOVE_EXECUTABLE]
                                withArgs:@[strongSelf.dotFileName, strongSelf.projectPath]
                               directory:strongSelf.sourceCodePath
                              completion:strongSelf.openBlock];
    };
}

- (void)setupOpenBlock
{
    __weak __typeof(&*self)weakSelf = self;
    self.openBlock = ^(NSTask *t,
                       NSString *standardOutputString,
                       NSString *standardErrorString){
        __strong __typeof(&*weakSelf)strongSelf = weakSelf;
        [VWKShellHandler runShellCommand:[USER_BIN_PATH stringByAppendingPathComponent:OPEN_EXECUTABLE]
                                withArgs:@[strongSelf.pngFileName]
                               directory:strongSelf.projectPath
                              completion:nil];
    };
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
