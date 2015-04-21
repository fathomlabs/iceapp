//
//  PreferencesWindowController.m
//  Postgres
//
//  Created by Jakob Egger on 18.12.13.
//
//

#import "PreferenceWindowController.h"
#import <ServiceManagement/ServiceManagement.h>
#import "IceConstants.h"
#import "PostgresServer.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@implementation PreferenceWindowController

+(PreferenceWindowController*)sharedController {
	static PreferenceWindowController* sharedController = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedController = [[PreferenceWindowController alloc] initWithWindowNibName:@"PreferenceWindow"];
	});
	return sharedController;
}

-(void)windowDidLoad {
	[self configureLoginItemButton];
}

-(void)configureLoginItemButton {
	BOOL loginItemEnabled = NO;
	NSArray *jobs = (__bridge_transfer NSArray *)SMCopyAllJobDictionaries(kSMDomainUserLaunchd);
	for (NSDictionary *job in jobs) {
		if ([[job valueForKey:@"Label"] isEqualToString:@"com.postgresapp.PostgresHelper"]) {
			loginItemEnabled = YES;
			break;
		}
	}
	[loginItemCheckbox setState: loginItemEnabled ? NSOnState : NSOffState];
	
	BOOL loginItemSupported = [[NSBundle mainBundle].bundlePath isEqualToString:@"/Applications/Postgres.app"];
	if (loginItemSupported) {
		loginItemCheckbox.target = self;
		loginItemCheckbox.action = @selector(toggleLoginItem:);
	} else {
		loginItemCheckbox.enabled = NO;
	}
}

-(IBAction)toggleLoginItem:(id)sender {
	BOOL loginItemEnabled = (loginItemCheckbox.state == NSOnState);
    
    NSURL *helperApplicationURL = [[NSBundle mainBundle].bundleURL URLByAppendingPathComponent:@"Contents/Library/LoginItems/PostgresHelper.app"];
    if (LSRegisterURL((__bridge CFURLRef)helperApplicationURL, true) != noErr) {
        DDLogError(@"LSRegisterURL Failed");
    }
    
    BOOL stateChangeSuccessful = SMLoginItemSetEnabled(CFSTR("com.postgresapp.PostgresHelper"), loginItemEnabled);
	if (!stateChangeSuccessful) {
        NSError *error = [NSError errorWithDomain:@"com.postgresapp.Postgres" code:1 userInfo:@{ NSLocalizedDescriptionKey: @"Failed to set login item."}];
		[self presentError:error modalForWindow:self.window delegate:nil didPresentSelector:NULL contextInfo:NULL];
		loginItemCheckbox.state = loginItemEnabled ? NSOffState : NSOnState;
    }
}

-(BOOL)windowShouldClose:(NSWindow*)window {
	BOOL controlDidResign = [self.window makeFirstResponder:nil];
	if (!controlDidResign) NSBeep();
	[[NSUserDefaults standardUserDefaults] synchronize];
	return controlDidResign;
}


@end
