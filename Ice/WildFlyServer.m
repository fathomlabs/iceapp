//
//  WildFlyServer.m
//  Ice
//
//  Created by Richard Smith-Unna on 19/03/2015.
//
//

#import "WildFlyServer.h"
#import "RecoveryAttempter.h"
#import "IceConstants.h"
#include <JSONKit.h>

#define xstr(a) str(a)
#define str(a) #a

@interface WildFlyServer()
@property BOOL isRunning;
@property NSUInteger port;
@end

@implementation WildFlyServer

+ (WildFlyServer*) defaultServer {
    static WildFlyServer *_sharedServer = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        NSString *binDirectory = [[NSBundle mainBundle].bundlePath stringByAppendingFormat:@"/Contents/Versions/wildfly-%s.Final/bin", xstr(WF_VERSION)];
        _sharedServer = [[WildFlyServer alloc] initWithPort:kIceWildFlyDefaultPort
                                              binDirectory:binDirectory];
    });
    
    return _sharedServer;
}

- (id) initWithPort:(NSUInteger)port binDirectory:(NSString *)binDirectory {
    
    self = [super init];
    if (!self) {
        return nil;
    }
    
    _port = port;
    _binPath = binDirectory;
    
    return self;
    
}

#pragma mark - Command running

- (NSTask*) runTaskWithCommand:(NSString*)cmd arguments:(NSArray*)args error:(NSError**)error errorDescription:(NSString*)errDesc errorDomain:(NSString*)errDomain {
    NSTask *controlTask = [[NSTask alloc] init];
    controlTask.launchPath = @"/bin/bash";
    controlTask.arguments = [@[@"-c", [self.binPath stringByAppendingPathComponent:cmd]] arrayByAddingObjectsFromArray:args];
    controlTask.standardOutput = [[NSPipe alloc] init];
    controlTask.standardError = [[NSPipe alloc] init];
    [controlTask launch];
    NSString *controlTaskError = [[NSString alloc] initWithData:[[controlTask.standardError fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
    [controlTask waitUntilExit];
    NSLog(controlTaskError);
    if (controlTask.terminationStatus != 0 && error) {
        NSMutableDictionary *errorUserInfo = [[NSMutableDictionary alloc] init];
        errorUserInfo[NSLocalizedDescriptionKey] = NSLocalizedString(errDesc, nil);
        errorUserInfo[NSLocalizedRecoverySuggestionErrorKey] = controlTaskError;
        errorUserInfo[NSLocalizedRecoveryOptionsErrorKey] = @[@"OK", @"Open Server Log"];
        errorUserInfo[NSRecoveryAttempterErrorKey] = [[RecoveryAttempter alloc] init];
        errorUserInfo[@"ServerLogRecoveryOptionIndex"] = @1;
        errorUserInfo[@"ServerLogPath"] = self.logfilePath;
        *error = [NSError errorWithDomain:errDomain code:controlTask.terminationStatus userInfo:errorUserInfo];
    }
    
    return controlTask;
}

- (id) runJbossCommand:(NSString*)cmd error:(NSError**)error {
    NSString *genericCmd = @"jboss-cli.sh --connect ";
    NSString *fullCmd = [genericCmd stringByAppendingString:cmd];
    NSString *errorDesc = [@"Failed to run JBOSS-cli command: " stringByAppendingString:cmd];
    NSTask *task = [self runTaskWithCommand:fullCmd arguments:@[] error:error errorDescription:errorDesc errorDomain:@"com.iceapp.WildFly.jboss-cli"];
    NSData *responseData = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
    return [responseData objectFromJSONData];
}

#pragma mark - Starting server

// Asynchronously start server
- (void) startWithCompletionHandler:(WildFlyServerControlCompletionHandler)completionBlock {
    NSError *error = nil;
    BOOL success = [self startServerWithError:&error];
    if (completionBlock) completionBlock(success, error);
}

// Synchronously start server
- (BOOL) startServerWithError:(NSError**)error {
    NSString *cmd = @"standalone_bg.sh | grep -m1 'started' | head -1";
    NSString *errDesc = @"Could not start WildFly server.";
    NSString *errDom = @"com.iceapp.WildFly.startup";
    NSTask *task = [self runTaskWithCommand:cmd arguments:@[] error:error errorDescription:errDesc errorDomain:errDom];
    
    if (task.terminationStatus == 0) {
        self.isRunning = [self checkIfRunning];
    }
    
    return task.terminationStatus == 0;
}

#pragma mark - Stopping server

// Asynchronously stop server
- (void) stopWithCompletionHandler:(WildFlyServerControlCompletionHandler)completionBlock {
    NSError *error = nil;
    BOOL success = [self stopServerWithError:&error];
    if (completionBlock) dispatch_async(dispatch_get_main_queue(), ^{ completionBlock(success, error); });
}

// Synchronously stop server
- (BOOL) stopServerWithError:(NSError**)error {
    NSString *cmd = @":shutdown";
    NSTask *task = [self runJbossCommand:cmd error:error];
    
    if (task.terminationStatus == 0) {
        NSData *resultData = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
        NSString *resultString = [[NSString alloc] initWithData:resultData
                                                       encoding:NSUTF8StringEncoding];
        NSDictionary *result = [resultString objectFromJSONString];
        return [result[@"outcome"] isEqualToString:@"success"];
    }
    return task.terminationStatus == 0;
}

#pragma mark - Server status

- (bool) checkIfRunning {
    return [self serverStatus] != WildFlyServerUnreachable;
}

- (WildFlyServerStatus) serverStatus {
    return WildFlyServerRunning;
}

# pragma mark - App status

- (WildFlyAppStatus) appStatus:(NSString*)appname {
    NSString *cmd = @"/deployment=ice.war :read-attribute(name=status)";
    NSError *error = nil;
    NSTask *task = [self runJbossCommand:cmd error:&error];
    
    if (task.terminationStatus == 0) {
        NSData *resultData = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
        NSString *resultString = [[NSString alloc] initWithData:resultData
                                                 encoding:NSUTF8StringEncoding];
        NSDictionary *result = [resultString objectFromJSONString];
        return [self parseAppStatus:result[@"result"]];
    }
    
    return WildFlyAppError;
}

- (WildFlyAppStatus) parseAppStatus:(NSString*)status {
    // valid status: OK, FAILED, STOPPED
    if ([status isEqualToString:@"OK"])
        return WildFlyAppOK;
    else if ([status isEqualToString:@"FAILED"])
        return WildFlyAppFailed;
    else if ([status isEqualToString:@"STOPPED"])
        return WildFlyAppStopped;
    else
        return WildFlyAppError;
}

- (NSString *) logfilePath {
    return [self.binPath stringByAppendingPathComponent:@"../standalone/log/server.log"];
}

@end
