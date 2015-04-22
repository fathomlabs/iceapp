// AppDelegate.m
//
// Created by Mattt Thompson (http://mattt.me/)
// Copyright (c) 2012 Heroku (http://heroku.com/)
// 
// Portions Copyright (c) 1996-2012, The PostgreSQL Global Development Group
// Portions Copyright (c) 1994, The Regents of the University of California
//
// Permission to use, copy, modify, and distribute this software and its
// documentation for any purpose, without fee, and without a written agreement
// is hereby granted, provided that the above copyright notice and this
// paragraph and the following two paragraphs appear in all copies.
//
// IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
// DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
// LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
// EVEN IF THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF
// SUCH DAMAGE.
//
// THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
// FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON AN
// "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATIONS TO
// PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.

#import "AppDelegate.h"
#import "PostgresServer.h"
#import "WildFlyServer.h"
#import "IceStatusMenuItemViewController.h"
#import "WelcomeWindowController.h"
#import "PGApplicationMover.h"
#import "PGShellProfileUpdater.h"
#import "PreferenceWindowController.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

#import "Terminal.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

#ifdef SPARKLE
#import <Sparkle/Sparkle.h>
#endif


@implementation AppDelegate {
    NSStatusItem *_statusBarItem;
    WelcomeWindowController *_welcomeWindowController;    
}
@synthesize iceStatusMenuItemViewController = _iceStatusMenuItemViewController;
@synthesize statusBarMenu = _statusBarMenu;
@synthesize iceStatusMenuItem = _iceStatusMenuItem;

#pragma mark - NSApplicationDelegate

-(void)applicationWillFinishLaunching:(NSNotification *)notification {
	
	/* Make sure that the app is inside the application directory */
#if !DEBUG
	[[PGApplicationMover sharedApplicationMover] validateApplicationPath];
#endif
	
	/* make sure that there is no other version of Ice.app running */
	[self validateNoOtherVersionsAreRunning];
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:@{
															  kIceShowWelcomeWindowPreferenceKey: @(YES)
															  }];
}

-(void)validateNoOtherVersionsAreRunning {
	NSMutableArray *runningCopies = [NSMutableArray array];
	[runningCopies addObjectsFromArray:[NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.iceapp.PG94_TC80"]];
	for (NSRunningApplication *runningCopy in runningCopies) {
		if (![runningCopy isEqual:[NSRunningApplication currentApplication]]) {
			NSAlert *alert = [NSAlert alertWithMessageText: @"Another copy of Ice.app is already running."
											 defaultButton: @"OK"
										   alternateButton: nil
											   otherButton: nil
								 informativeTextWithFormat: @"Please quit %@ before starting this copy.", runningCopy.localizedName];
			[alert runModal];
			exit(1);
		}
	}
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	
#ifdef SPARKLE
    [self.checkForUpdatesMenuItem setEnabled:YES];
    [self.checkForUpdatesMenuItem setHidden:NO];
#endif

    [DDLog addLogger:[DDASLLogger sharedInstance]];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
        
    _statusBarItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    _statusBarItem.highlightMode = YES;
    _statusBarItem.menu = self.statusBarMenu;
	NSImage *templateOffImage = [NSImage imageNamed:@"status-off"];
	templateOffImage.template = YES;
	_statusBarItem.image = templateOffImage;
	NSImage *templateOnImage = [NSImage imageNamed:@"status-on"];
	templateOnImage.template = YES;
	_statusBarItem.alternateImage = templateOnImage;
	
    [NSApp activateIgnoringOtherApps:YES];
    
    [self.iceStatusMenuItem setEnabled:NO];
    self.iceStatusMenuItem.view = self.iceStatusMenuItemViewController.view;
    [self startServer];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:kIceShowWelcomeWindowPreferenceKey]) {
		[[WelcomeWindowController sharedController] showWindow:self];
	}
}

- (void) startServer {
    [self.iceStatusMenuItemViewController startAnimatingWithTitle:NSLocalizedString(@"Starting Server…", nil)];
    [WelcomeWindowController sharedController].canConnect = NO;
    [WelcomeWindowController sharedController].isBusy = YES;
    [WelcomeWindowController sharedController].statusMessage = @"Starting Server…";
    
    [[PGShellProfileUpdater sharedUpdater] checkProfiles];
    
    [self startPostgresServer];
}

- (void) startPostgresServer {
    self.pgserver = [PostgresServer defaultServer];
    
    PostgresServerControlCompletionHandler completionHandler = ^(BOOL success, NSError *error){
        if (success) {
            [self startWildFlyServer];
            [self.iceStatusMenuItemViewController setTitle:@"Postgres started, launching WildFly..."];
        } else {
            NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Postgres startup failed.", nil)];
            [self.iceStatusMenuItemViewController stopAnimatingWithTitle:errorMessage wasSuccessful:NO];
            [WelcomeWindowController sharedController].statusMessage = errorMessage;
            [WelcomeWindowController sharedController].isBusy = NO;
            
            [[WelcomeWindowController sharedController] showWindow:self];
            [[WelcomeWindowController sharedController].window presentError:error modalForWindow:[WelcomeWindowController sharedController].window delegate:nil didPresentSelector:NULL contextInfo:NULL];
        }
    };
    
    PostgresServerStatus serverStatus = [self.pgserver serverStatus];
    
    if (serverStatus == PostgresServerWrongDataDirectory) {
        /* a different server is running */
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: [NSString stringWithFormat:@"There is already a PostgreSQL server running on port %u", (unsigned)self.pgserver.port],
                                   NSLocalizedRecoverySuggestionErrorKey: @"Please stop this server before starting Ice.app.\n\nIf you want to use multiple servers, configure them to use different ports."
                                   };
        NSError *error = [NSError errorWithDomain:@"com.iceapp.Postgres.server-status" code:serverStatus userInfo:userInfo];
        completionHandler(NO, error);
    }
    else if (serverStatus == PostgresServerRunning) {
        /* apparently the server is already running... Either the user started it manually, or Postgres.app was force quit */
        completionHandler(YES, nil);
    }
    /*	else if ([self.server stat]) {
     
     }*/
    else {
        /* server is not running; try to start it */
        [self.pgserver startWithCompletionHandler:completionHandler];
    }
}

- (void) startWildFlyServer {
    self.wfserver = [WildFlyServer defaultServer];
    
    WildFlyServerControlCompletionHandler completionHandler = ^(BOOL success, NSError *error) {
        if (success) {
            [self.iceStatusMenuItemViewController stopAnimatingWithTitle:@"Running on Port 8080" wasSuccessful:YES];
            [WelcomeWindowController sharedController].statusMessage = nil;
            [WelcomeWindowController sharedController].isBusy = NO;
            [WelcomeWindowController sharedController].canConnect = YES;
            DDLogInfo(@"wildfly server started");
        } else {
            NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Wildfly startup failed.", nil)];
            [self.iceStatusMenuItemViewController stopAnimatingWithTitle:errorMessage wasSuccessful:NO];
            [WelcomeWindowController sharedController].statusMessage = errorMessage;
            [WelcomeWindowController sharedController].isBusy = NO;
            
            [[WelcomeWindowController sharedController] showWindow:self];
            [[WelcomeWindowController sharedController].window presentError:error modalForWindow:[WelcomeWindowController sharedController].window delegate:nil didPresentSelector:NULL contextInfo:NULL];
            DDLogError(@"wildfly server launch failed");
        }
    };
    
    WildFlyServerStatus serverStatus = [self.wfserver serverStatus];

    if (serverStatus == WildFlyServerRunning ||
        serverStatus == WildFlyServerReloadRequired ||
        serverStatus == WildFlyServerRestartRequired ||
        serverStatus == WildFlyServerStarting) {
        // wildfly server is running - just launch the app
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.wfserver deployIceApp];
            dispatch_async(dispatch_get_main_queue(), ^{ completionHandler(YES, nil); });
        });
        
    } else {
        [self.wfserver startWithCompletionHandler:completionHandler];
    }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	
	// make sure preferences are saved before quitting
	PreferenceWindowController *prefController = [PreferenceWindowController sharedController];
	if (prefController.isWindowLoaded && prefController.window.isVisible && ![prefController windowShouldClose:prefController.window]) {
		return NSTerminateCancel;
	}
	
	if (!self.pgserver.isRunning && !self.wfserver.isRunning) {
		return NSTerminateNow;
	}
    
    [self.wfserver stopWithCompletionHandler:^(BOOL success, NSError *error) {
        [self.pgserver stopWithCompletionHandler:^(BOOL success, NSError *error) {
            [sender replyToApplicationShouldTerminate:YES];
        }];
    }];

    // Set a timeout interval for postgres shutdown
    static NSTimeInterval const kTerminationTimeoutInterval = 5.0;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kTerminationTimeoutInterval * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
        [sender replyToApplicationShouldTerminate:YES];
    });
    
    return NSTerminateLater;
}

#pragma mark - IBAction

- (IBAction)selectAbout:(id)sender {
    // Bring application to foreground to have about window display on top of other windows
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp orderFrontStandardAboutPanel:nil];
}

- (IBAction)openDocumentation:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://postgresapp.com/documentation"]];
}

- (IBAction)openPreferences:(id)sender {
    [NSApp activateIgnoringOtherApps:YES];
	[[PreferenceWindowController sharedController] showWindow:nil];
}

- (IBAction)openICE:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://localhost:8080"]];
}

- (IBAction)checkForUpdates:(id)sender {
#ifdef SPARKLE
    [[SUUpdater sharedUpdater] setSendsSystemProfile:YES];
    [[SUUpdater sharedUpdater] checkForUpdates:sender];
#endif
}

@end
