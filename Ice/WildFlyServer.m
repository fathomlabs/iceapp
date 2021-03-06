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
#import <CocoaLumberjack/CocoaLumberjack.h>

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
        binDirectory = [WildFlyServer wrapPath:binDirectory];
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
    
    DDLogDebug(@"JAVA_HOME should be set to %@", [self java_home]);
    NSMutableDictionary *env = [NSMutableDictionary dictionaryWithObjectsAndKeys: [self java_home], @"JAVA_HOME", nil];
    
    NSTask *controlTask = [[NSTask alloc] init];
    controlTask.launchPath = @"/bin/bash";
    NSString *quotedCmd = [@"" stringByAppendingPathComponent:@"which java && echo $JAVA_HOME"];
    controlTask.arguments = @[@"-c", quotedCmd];
    controlTask.standardOutput = [[NSPipe alloc] init];
    controlTask.standardError = [[NSPipe alloc] init];
    [controlTask setEnvironment:env];
    [controlTask launch];
    [controlTask waitUntilExit];
    NSData *responseData = [[controlTask.standardOutput fileHandleForReading] readDataToEndOfFile];
    DDLogDebug(@"Where it really is: %@", [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
    
    return self;
    
}

#pragma mark - Path utils

+ (NSString*) wrapPath:(NSString*)path {
    return [NSString stringWithFormat:@"\"%@\"", path];
}

- (id)java_home {
    return [[NSBundle mainBundle].bundlePath stringByAppendingFormat:@"/Contents/Versions/jre"];
}

#pragma mark - Command running

- (NSTask*) runTaskWithCommand:(NSString*)cmd arguments:(NSArray*)args error:(NSError**)error errorDescription:(NSString*)errDesc errorDomain:(NSString*)errDomain {
    DDLogDebug(@"Running task with cmd: %@", cmd);
    
    NSMutableDictionary *env = [NSMutableDictionary dictionaryWithObjectsAndKeys: [self java_home], @"JAVA_HOME", nil];
    
    NSTask *controlTask = [[NSTask alloc] init];
    controlTask.launchPath = @"/bin/bash";
    NSString *quotedCmd = [self.binPath stringByAppendingPathComponent:cmd];
    controlTask.arguments = [@[@"-c", quotedCmd] arrayByAddingObjectsFromArray:args];
    controlTask.standardOutput = [[NSPipe alloc] init];
    controlTask.standardError = [[NSPipe alloc] init];
    [controlTask setEnvironment:env];
    [controlTask launch];
    [controlTask waitUntilExit];
    
    if (controlTask.terminationStatus != 0) {
        NSString *controlTaskError = [[NSString alloc] initWithData:[[controlTask.standardError fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding];

        DDLogError(@"Task error: %@ for cmd: %@", controlTaskError, cmd);
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
    DDLogDebug(@"Running JBOSS cmd: %@", cmd);
    NSString *genericCmd = @"jboss-cli.sh --connect ";
    NSString *quotedCmd = [NSString stringWithFormat:@"\"%@\"", cmd];
    NSString *fullCmd = [genericCmd stringByAppendingString:quotedCmd];
    DDLogDebug(@"Full quoted JBOSS cmd: %@", fullCmd);
    NSString *errorDesc = [@"Failed to run JBOSS-cli command: " stringByAppendingString:cmd];
    
    NSTask *task = [self runTaskWithCommand:fullCmd arguments:@[] error:error errorDescription:errorDesc errorDomain:@"com.iceapp.WildFly.jboss-cli"];
    
    NSString *responseString = [[NSString alloc] initWithData:[[task.standardOutput fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
    NSString *jsonString = [responseString stringByReplacingOccurrencesOfString:@"=>" withString:@":"];
    DDLogDebug(@"Command response: %@", jsonString);
    NSDictionary *result = [jsonString objectFromJSONString];
    DDLogDebug(@"Jboss result: %@", result);
    return result;
}

#pragma mark - Starting server

// Asynchronously start server
- (void) startWithCompletionHandler:(WildFlyServerControlCompletionHandler)completionBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        BOOL success = [self startServerWithError:&error];
        if (completionBlock) dispatch_async(dispatch_get_main_queue(), ^{ completionBlock(success, error); });
    });
}

// Synchronously start server
- (BOOL) startServerWithError:(NSError**)error {
    NSString *cmd = @"standalone_bg.sh | grep -m1 'started' | head -1";
    NSString *errDesc = @"Could not start WildFly server.";
    NSString *errDom = @"com.iceapp.WildFly.startup";
    NSTask *task = [self runTaskWithCommand:cmd arguments:@[] error:error errorDescription:errDesc errorDomain:errDom];
    NSData *responseData = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
    DDLogDebug(@"Command response: %@", [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
    
    self.isRunning = [self checkIfRunning];
    int fails = 0;
    bool deployed = NO;
    while (!deployed && fails < 5) {
        if (fails > 0) {
            DDLogDebug(@"Sleeping for 2 seconds before retrying deployment...");
            sleep(2);
        }
        deployed = [self deployIceApp];
        if (!deployed) {
            DDLogDebug(@"Deployment failed");
            ++fails;
        }
    }
    self.isRunning = deployed;
    return deployed;
}

- (BOOL) deployIceApp {
    
    WildFlyAppStatus status = [self appStatus:@"ice.war"];
    if (status == WildFlyAppOK) {
        DDLogDebug(@"ICE app already deployed");
        return YES;
    } else if (status == WildFlyAppStopped) {
        [self undeployIceApp];
    }

    DDLogInfo(@"Deploying ICE app");
    NSError *error = nil;
    NSString *warpath = [[NSBundle mainBundle].bundlePath stringByAppendingFormat:@"/Contents/Versions/wildfly-%s.Final/standalone/deployments/ice.war", xstr(WF_VERSION)];
    NSString *addCmd = [NSString stringWithFormat:@"/deployment=ice.war:add(runtime-name=\\\"ice.war\\\", content=[{\\\"path\\\"=>\\\"%@\\\",\\\"archive\\\"=>false}])", warpath];
    
    NSString *deployCmd = @"/deployment=ice.war:deploy";
    
    NSDictionary *result = [self runJbossCommand:addCmd error:&error];
    DDLogDebug(@"Ice app add result class: %@", NSStringFromClass([result class]));
    result = [self runJbossCommand:deployCmd error:&error];
    DDLogDebug(@"Ice app deploy result: %@", result);
    
    if ([result[@"outcome"] isEqualToString:@"success"]) {
        return YES;
    }
    else {
        return NO;
    }
}

- (BOOL) undeployIceApp {
    DDLogInfo(@"Undeploying ICE app");
    NSError *error = nil;
    NSString *undeployCmd = @"/deployment=ice.war:undeploy";
    NSString *removeCmd = @"/deployment=ice.war:remove";
    
    NSDictionary *result = [self runJbossCommand:undeployCmd error:&error];
    
    if ([result[@"outcome"] isEqualToString:@"success"]) {
        result = [self runJbossCommand:removeCmd error:&error];
        
        if ([result[@"outcome"] isEqualToString:@"success"]) {
            return YES;
        }
        else {
            return NO;
        }
    } else {
        return NO;
    }
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
    [self undeployIceApp];
    
    NSString *cmd = @":shutdown";
    NSDictionary *result = [self runJbossCommand:cmd error:error];
    
    return ([result[@"outcome"] isEqualToString:@"success"]);
}

#pragma mark - Server status

- (bool) checkIfRunning {
    return [self serverStatus] != WildFlyServerUnreachable;
}

- (WildFlyServerStatus) serverStatus {
    DDLogDebug(@"Checking server status");
    NSString *cmd = @":read-attribute(name=server-state)";
    NSError *error = nil;
    NSDictionary *result = [self runJbossCommand:cmd error:&error];
    DDLogDebug(@"Server status: %@", result);
    if (error) {
        return WildFlyServerUnreachable;
    } else {
        return [self parseServerStatus:result[@"result"]];
    }
}

- (WildFlyServerStatus) parseServerStatus:(NSString*)status {
    // valid status: running, starting, stopping, restart-required, reload-required
    if ([status isEqualToString:@"running"])
        return WildFlyServerRunning;
    else if ([status isEqualToString:@"starting"])
        return WildFlyServerStarting;
    else if ([status isEqualToString:@"stopping"])
        return WildFlyServerStopping;
    else if ([status isEqualToString:@"restart-required"])
        return WildFlyServerRestartRequired;
    else if ([status isEqualToString:@"reload-required"])
        return WildFlyServerReloadRequired;
    else
        return WildFlyServerUnreachable;
}

# pragma mark - App status

- (WildFlyAppStatus) appStatus:(NSString*)appname {
    NSString *cmd = @"/deployment=ice.war :read-attribute(name=status)";
    NSError *error = nil;
    NSDictionary *result = [self runJbossCommand:cmd error:&error];
    DDLogDebug(@"Status of %@ app: %@", appname, result[@"result"]);

    if (error) {
        return WildFlyAppError;
    } else {
        return [self parseAppStatus:result[@"result"]];
    }
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
    return [WildFlyServer wrapPath:[self.binPath stringByAppendingPathComponent:@"../standalone/log/server.log"]];
}

@end
