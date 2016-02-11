//
//  SharedRequestHandler.m
//  HelloWorld
//
//  Created by Cătălin Stan on 11/9/15.
//
//

#import "CommonRequestHandler.h"

#import <sys/utsname.h>

@interface CommonRequestHandler ()

@property (strong) NSString* uname;

@end

@implementation CommonRequestHandler

+ (instancetype)defaultHandler {
    static CommonRequestHandler* _defaultHandler;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _defaultHandler = [[CommonRequestHandler alloc] init];
    });
    return _defaultHandler;
}

- (instancetype)init {
    self = [super init];
    if ( self != nil ) {
        struct utsname systemInfo;
        uname(&systemInfo);
        _uname = [NSString stringWithFormat:@"%s %s %s %s %s", systemInfo.sysname, systemInfo.nodename, systemInfo.release, systemInfo.version, systemInfo.machine];
    }
    return self;
}

- (CRRouteBlock)identifyBlock {
    __block CRRouteBlock _identifyBlock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *bundle = [NSBundle mainBundle];
        _identifyBlock = ^(CRRequest* request, CRResponse* response, CRRouteCompletionBlock completionHandler) {
            [response setValue:[NSString stringWithFormat:@"%@, %@ build %@", bundle.bundleIdentifier, [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"], [bundle objectForInfoDictionaryKey:@"CFBundleVersion"]] forHTTPHeaderField:@"Server"];

            if ( ! request.cookies[@"session_cookie"] ) {
                [response setCookie:@"session_cookie" value:[NSUUID UUID].UUIDString path:@"/" expires:nil domain:nil secure:NO];
            }
            [response setCookie:@"persistant_cookie" value:[NSUUID UUID].UUIDString path:@"/" expires:[NSDate distantFuture] domain:nil secure:NO];

            completionHandler();
        };
    });
    return _identifyBlock;
}

- (CRRouteBlock) helloWorldBlock {
    __block CRRouteBlock _helloWorldBlock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _helloWorldBlock = ^(CRRequest* request, CRResponse* response, CRRouteCompletionBlock completionHandler) {
            [response setValue:@"text/plain; charset=utf-8" forHTTPHeaderField:@"Content-type"];
            [response sendString:@"Hello World"];
            completionHandler();
        };
    });
    return _helloWorldBlock;
}

- (CRRouteBlock)jsonHelloWorldBlock {
    __block CRRouteBlock _jsonHelloWorldBlock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _jsonHelloWorldBlock = ^(CRRequest* request, CRResponse* response, CRRouteCompletionBlock completionHandler) {
            [response setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-type"];
            [response sendData:[NSJSONSerialization dataWithJSONObject:@{@"status": @YES, @"message": @"Hello World"} options:0 error:nil]];
            completionHandler();
        };
    });
    return _jsonHelloWorldBlock;
}

- (CRRouteBlock)statusBlock {
    __block CRRouteBlock _statusBlock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _statusBlock = ^(CRRequest* request, CRResponse* response, CRRouteCompletionBlock completionHandler) {

            NSDate* startTime = [NSDate date];

            NSMutableString* responseString = [[NSMutableString alloc] init];

            // Bundle Info
            [responseString appendFormat:@"<h1>%@</h1>", [NSBundle mainBundle].bundleIdentifier];
            [responseString appendFormat:@"<h2>Version %@ build %@</h2>", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"], [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];

            // Headers
            [responseString appendString:@"<h3>Request Headers:</h2><pre>"];
            [request.allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
                [responseString appendFormat:@"%@: %@\n", key, obj];
            }];
            [responseString appendString:@"</pre>"];

            // Request enviroment
            [responseString appendString:@"<h3>Request Enviroment:</h2><pre>"];
            [request.env enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
                [responseString appendFormat:@"%@: %@\n", key, obj];
            }];
            [responseString appendString:@"</pre>"];


            // Query
            [responseString appendString:@"<h3>Request Query:</h2><pre>"];
            [request.query enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
                [responseString appendFormat:@"%@: %@\n", key, obj];
            }];
            [responseString appendString:@"</pre>"];


            // Cookies
            [responseString appendString:@"<h3>Request Cookies:</h2><pre>"];
            [request.cookies enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
                [responseString appendFormat:@"%@: %@\n", key, obj];
            }];
            [responseString appendString:@"</pre>"];

            // Stack trace
            [responseString appendString:@"<h3>Stack Trace:</h2><pre>"];
            [[NSThread callStackSymbols] enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [responseString appendFormat:@"%@\n", obj];
            }];
            [responseString appendString:@"</pre>"];

            // System Info
            [responseString appendString:@"<hr/>"];
            [responseString appendFormat:@"<small>%@</small><br/>", _uname];
            [responseString appendFormat:@"<small>Task took: %.4fms</small>", [startTime timeIntervalSinceNow] * -1000];

            [response setValue:@"text/html; charset=utf-8" forHTTPHeaderField:@"Content-type"];
            [response setValue:@(responseString.length).stringValue forHTTPHeaderField:@"Content-Length"];
            [response sendString:responseString];
            
            completionHandler();
        };
    });
    return _statusBlock;
}

@end
