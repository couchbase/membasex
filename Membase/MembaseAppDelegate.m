//
//  MembaseAppDelegate.m
//  Membase
//
//  Created by Dustin Sallings on 3/22/11.
//  Copyright 2011 NorthScale. All rights reserved.
//

#import "MembaseAppDelegate.h"

#define MIN_LIFETIME 10

@implementation MembaseAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
}

-(void)applicationWillTerminate:(NSNotification *)notification
{
    NSLog(@"Terminating.");
    [self stop];
}

-(void)applicationWillFinishLaunching:(NSNotification *)notification
{
//	SUUpdater *updater = [SUUpdater sharedUpdater];
//	SUUpdaterDelegate *updaterDelegate = [[SUUpdaterDelegate alloc] init];
//	[updater setDelegate: updaterDelegate];
}

- (IBAction)showAboutPanel:(id)sender {
    [NSApp activateIgnoringOtherApps:YES];
    [[NSApplication sharedApplication] orderFrontStandardAboutPanel:sender];
}

-(void)awakeFromNib
{
    hasSeenStart = NO;
    
    [[NSUserDefaults standardUserDefaults]
     registerDefaults: [NSDictionary dictionaryWithObjectsAndKeys:
                        [NSNumber numberWithBool:YES], @"browseAtStart", nil, nil]];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    statusBar=[[NSStatusBar systemStatusBar] statusItemWithLength: 30.0];
    NSImage *statusIcon = [NSImage imageNamed:@"Membase-status.png"];
    [statusBar setImage: statusIcon];
    [statusBar setMenu: statusMenu];
    [statusBar setEnabled:YES];
    [statusBar setHighlightMode:YES];
    [statusBar retain];
    
    
    [launchBrowserItem setState:([defaults boolForKey:@"browseAtStart"] ? NSOnState : NSOffState)];
    [self updateAddItemButtonState];
    
	[self launchMembase];
}

-(IBAction)start:(id)sender
{
    if([task isRunning]) {
        [self stop];
        return;
    } 
    
    [self launchMembase];
}

-(void)stop
{
    NSFileHandle *writer;
    writer = [in fileHandleForWriting];
    [writer writeData:[@"q().\n" dataUsingEncoding:NSASCIIStringEncoding]];
    [writer closeFile];
}

/* found at http://www.cocoadev.com/index.pl?ApplicationSupportFolder */
- (NSString *)applicationSupportFolder:(NSString*)appName {
    NSString *applicationSupportFolder = nil;
    FSRef foundRef;
    OSErr err = FSFindFolder(kUserDomain, kApplicationSupportFolderType, kDontCreateFolder, &foundRef);
    if (err == noErr) {
        unsigned char path[PATH_MAX];
        OSStatus validPath = FSRefMakePath(&foundRef, path, sizeof(path));
        if (validPath == noErr) {
            applicationSupportFolder = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:(const char*)path
                                                                                                   length:(NSUInteger)strlen((char*)path)];
        }
    }
	applicationSupportFolder = [applicationSupportFolder stringByAppendingPathComponent:appName];
    return applicationSupportFolder;
}

- (NSString *)applicationSupportFolder {
    return [self applicationSupportFolder:@"Membase"];
}

-(void)mkdirP:(NSString *)p {
    if(![[NSFileManager defaultManager] fileExistsAtPath:p]) {
		[[NSFileManager defaultManager] createDirectoryAtPath:p withIntermediateDirectories:YES attributes:nil error:NULL];
	}
}

-(void)updateConfig
{
	// determine data dir
	NSString *dataDir = [self applicationSupportFolder];
    NSLog(@"App support dir:  %@", dataDir);
    assert(dataDir);
	// create if it doesn't exist
    [self mkdirP:[dataDir stringByAppendingPathComponent:@"data"]];
    [self mkdirP:[dataDir stringByAppendingPathComponent:@"priv"]];
    [self mkdirP:[dataDir stringByAppendingPathComponent:@"config"]];
    [self mkdirP:[dataDir stringByAppendingPathComponent:@"logs"]];
    [self mkdirP:[dataDir stringByAppendingPathComponent:@"mnesia"]];
    [self mkdirP:[dataDir stringByAppendingPathComponent:@"tmp"]];

    NSString *initSqlProto = [[NSBundle mainBundle] pathForResource:@"init" ofType:@"sql"];
    NSString *initSql = [dataDir stringByAppendingPathComponent:@"priv/init.sql"];

    if(![[NSFileManager defaultManager] fileExistsAtPath:initSql]) {
        assert([[NSFileManager defaultManager] fileExistsAtPath:initSqlProto]);
        [[NSFileManager defaultManager] copyItemAtPath:initSqlProto
                                                toPath:initSql
                                                 error:nil];
    }

    NSString *conf = [NSString stringWithFormat:@"{directory, \"%@\"}.\n", dataDir, nil];
    assert(conf);
    NSLog(@"Config:  %@", conf);

	// if data dirs are not set in local.ini
	NSMutableString *confFile = [[NSMutableString alloc] init];
    assert(confFile);
	[confFile appendString:[[NSBundle mainBundle] resourcePath]];
	[confFile appendString:@"/membase-core/priv/config"];
    NSLog(@"Config file:  %@", confFile);

    [conf writeToFile:confFile atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	[confFile release];
	// done
}

-(void)launchMembase
{
    [self updateConfig];

	in = [[NSPipe alloc] init];
	out = [[NSPipe alloc] init];
	task = [[NSTask alloc] init];
    
    startTime = time(NULL);

    NSDictionary *env = [NSDictionary dictionaryWithObjectsAndKeys:
                         @"./bin:/bin:/usr/bin", @"PATH",
                         NSHomeDirectory(), @"HOME",
                         nil, nil];

	NSMutableString *launchPath = [[NSMutableString alloc] init];
	[launchPath appendString:[[NSBundle mainBundle] resourcePath]];
	[launchPath appendString:@"/membase-core"];
	[task setCurrentDirectoryPath:launchPath];
    
	[launchPath appendString:@"/start_shell.sh"];
    NSLog(@"Launching '%@'", launchPath);
	[task setLaunchPath:launchPath];
    [task setEnvironment:env];
	[task setStandardInput:in];
	[task setStandardOutput:out];
    
	NSFileHandle *fh = [out fileHandleForReading];
	NSNotificationCenter *nc;
	nc = [NSNotificationCenter defaultCenter];
    
	[nc addObserver:self
           selector:@selector(dataReady:)
               name:NSFileHandleReadCompletionNotification
             object:fh];
	
	[nc addObserver:self
           selector:@selector(taskTerminated:)
               name:NSTaskDidTerminateNotification
             object:task];
    
  	[task launch];
  	[fh readInBackgroundAndNotify];
}

-(void)taskTerminated:(NSNotification *)note
{
    NSLog(@"Terminated with status %d", [[note object] terminationStatus]);
    [self cleanup];
    
    time_t now = time(NULL);
    if (now - startTime < MIN_LIFETIME) {
        NSInteger b = NSRunAlertPanel(@"Problem Running Couchbase",
                                      @"Couchbase Server doesn't seem to be operating properly.  "
                                      @"Check Console logs for more details.", @"Retry", @"Quit", nil);
        if (b == NSAlertAlternateReturn) {
            [NSApp terminate:self];
        }
    }
    
    [NSTimer scheduledTimerWithTimeInterval:1.0
                                     target:self selector:@selector(launchMembase)
                                   userInfo:nil
                                    repeats:NO];
}

-(void)cleanup
{
    [task release];
    task = nil;
    
    [in release];
    in = nil;
    [out release];
    out = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)openGUI
{
	NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
	NSString *homePage = [info objectForKey:@"HomePage"];
    NSURL *url=[NSURL URLWithString:homePage];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

-(IBAction)browse:(id)sender
{
	[self openGUI];
}

- (void)appendData:(NSData *)d
{
    NSString *s = [[NSString alloc] initWithData: d
                                        encoding: NSUTF8StringEncoding];
    
    if (!hasSeenStart) {
        if ([s rangeOfString:@"Membase Server has started on web port 8091"].location != NSNotFound) {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            if ([defaults boolForKey:@"browseAtStart"]) {
                [self openGUI];
            }
            hasSeenStart = YES;
        }
    }
    
    NSLog(@"%@", s);
}

- (void)dataReady:(NSNotification *)n
{
    NSData *d;
    d = [[n userInfo] valueForKey:NSFileHandleNotificationDataItem];
    if ([d length]) {
        [self appendData:d];
    }
    if (task)
        [[out fileHandleForReading] readInBackgroundAndNotify];
}

-(IBAction)setLaunchPref:(id)sender {
    
    NSCellStateValue stateVal = [sender state];
    stateVal = (stateVal == NSOnState) ? NSOffState : NSOnState;
    
    NSLog(@"Setting launch pref to %s", stateVal == NSOnState ? "on" : "off");
    
    [[NSUserDefaults standardUserDefaults]
     setBool:(stateVal == NSOnState)
     forKey:@"browseAtStart"];
    
    [launchBrowserItem setState:([[NSUserDefaults standardUserDefaults]
                                  boolForKey:@"browseAtStart"] ? NSOnState : NSOffState)];
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(bool) isInLoginItems {
    NSUserDefaults * defaults = [[NSUserDefaults alloc] init];
    BOOL rv = NO;
    
    [defaults addSuiteNamed:@"loginwindow"];
    
    NSMutableArray *loginItems=[[[defaults
                                  persistentDomainForName:@"loginwindow"]
                                 objectForKey:@"AutoLaunchedApplicationDictionary"] mutableCopy];
    
    // Remove anything that looks like the current login item.
    NSString *myName=[[[NSBundle mainBundle] bundlePath] lastPathComponent];
    NSEnumerator *e=[loginItems objectEnumerator];
    id current=nil;
    while( (current=[e nextObject]) != nil) {
        if([[current valueForKey:@"Path"] hasSuffix:myName]) {
            rv = YES;
        }
    }
    
    [defaults release];
    return rv;
}

-(void) updateAddItemButtonState {
    [launchAtStartupItem setState:[self isInLoginItems] ? NSOnState : NSOffState];
}

-(void) removeLoginItem:(id)sender {
    NSUserDefaults * defaults = [[NSUserDefaults alloc] init];
    
    [defaults addSuiteNamed:@"loginwindow"];
    
    NSMutableArray *loginItems=[[[defaults
                                  persistentDomainForName:@"loginwindow"]
                                 objectForKey:@"AutoLaunchedApplicationDictionary"] mutableCopy];
    
    // Remove anything that looks like the current login item.
    NSString *myName=[[[NSBundle mainBundle] bundlePath] lastPathComponent];
    NSEnumerator *e=[loginItems objectEnumerator];
    id current=nil;
    while( (current=[e nextObject]) != nil) {
        if([[current valueForKey:@"Path"] hasSuffix:myName]) {
            NSLog(@"Removing login item: %@", [current valueForKey:@"Path"]);
            [loginItems removeObject:current];
        }
    }
    
    [defaults removeObjectForKey:@"AutoLaunchedApplicationDictionary"];
    [defaults setObject:loginItems forKey:
     @"AutoLaunchedApplicationDictionary"];
    
    // Use the corefoundation API since I can't figure out the other one.
    CFPreferencesSetValue((CFStringRef)@"AutoLaunchedApplicationDictionary",
                          loginItems, (CFStringRef)@"loginwindow", kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFPreferencesSynchronize((CFStringRef) @"loginwindow", kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    
    [defaults release];
}

// XXX:  I need to make this be able to add or remove, and validate the current user wishes.
-(void)addToLoginItems:(id)sender {
    
    [self removeLoginItem: self];
    
    NSMutableDictionary * myDict=[[NSMutableDictionary alloc] init];
    NSUserDefaults * defaults = [[NSUserDefaults alloc] init];
    
    [defaults addSuiteNamed:@"loginwindow"];
    
    NSLog(@"Adding login item: %@", [[NSBundle mainBundle] bundlePath]);
    [myDict setObject:[NSNumber numberWithBool:NO] forKey:@"Hide"];
    [myDict setObject:[[NSBundle mainBundle] bundlePath]
               forKey:@"Path"];
    
    NSMutableArray *loginItems=[[[defaults
                                  persistentDomainForName:@"loginwindow"]
                                 objectForKey:@"AutoLaunchedApplicationDictionary"] mutableCopy];
    
    [loginItems addObject:myDict];
    [defaults removeObjectForKey:@"AutoLaunchedApplicationDictionary"];
    [defaults setObject:loginItems forKey:
     @"AutoLaunchedApplicationDictionary"];
    
    // Use the corefoundation API since I can't figure out the other one.
    CFPreferencesSetValue((CFStringRef)@"AutoLaunchedApplicationDictionary",
                          loginItems, (CFStringRef)@"loginwindow", kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFPreferencesSynchronize((CFStringRef) @"loginwindow", kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    
    [defaults release];
    [myDict release];
    [loginItems release];
}

-(IBAction)changeLoginItems:(id)sender {
    if([sender state] == NSOffState) {
        [self addToLoginItems:self];
    } else {
        [self removeLoginItem:self];
    }
    [self updateAddItemButtonState];
}

-(IBAction)showTechSupport:(id)sender {
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
	NSString *homePage = [info objectForKey:@"SupportPage"];
    NSURL *url=[NSURL URLWithString:homePage];
    [[NSWorkspace sharedWorkspace] openURL:url];
    
}

@end
