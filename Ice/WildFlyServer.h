//
//  WildFlyServer.h
//  Ice
//
//  Created by Richard Smith-Unna on 03/04/2015.
//
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    WildFlyServerRunning,
    WildFlyServerStarting,
    WildFlyServerReloadRequired,
    WildFlyServerRestartRequired,
    WildFlyServerStopping,
    WildFlyServerUnreachable
} WildFlyServerStatus;

typedef enum : NSUInteger {
    WildFlyAppOK,
    WildFlyAppFailed,
    WildFlyAppStopped,
    WildFlyAppError
} WildFlyAppStatus;

typedef void (^WildFlyServerControlCompletionHandler)(BOOL success, NSError *error);

@interface WildFlyServer : NSObject

@property (readonly) NSUInteger port;
@property (readonly) NSString *binPath;
@property (readonly) NSString *varPath;
@property (readonly) NSString *logfilePath;
@property (readonly) BOOL isRunning;

+ (WildFlyServer*) defaultServer;

- (id) initWithPort:(NSUInteger)port binDirectory:(NSString *)binDirectory;

- (void) startWithCompletionHandler:(WildFlyServerControlCompletionHandler)completionBlock;
- (void) stopWithCompletionHandler:(WildFlyServerControlCompletionHandler)completionBlock;

- (bool) checkIfRunning;
- (WildFlyServerStatus) serverStatus;
- (WildFlyAppStatus) appStatus:(NSString*)appname;

@end
