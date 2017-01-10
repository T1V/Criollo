//
//  CRHTTPServerTests.m
//  Criollo
//
//  Created by Cătălin Stan on 09/01/2017.
//  Copyright © 2017 Cătălin Stan. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Criollo/Criollo.h>

@interface CRHTTPServerTests : XCTestCase <CRServerDelegate>

@property (nonatomic, strong) CRHTTPServer *server;

@end

@implementation CRHTTPServerTests

- (void)setUp {
    [super setUp];
    
    self.server = [[CRHTTPServer alloc] initWithDelegate:self];
    
    self.server add:@"/" block:^(CRRequest * _Nonnull request, CRResponse * _Nonnull response, CRRouteCompletionBlock  _Nonnull completionHandler) {
        [response send:@"Hello world"];
    }
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    
    XCTestExpectation *expectation = [XCTestExpectation expectationWithDescription:@"Requests completed"];
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
    self waitForExpectationsWithTimeout:<#(NSTimeInterval)#> handler:<#^(NSError * _Nullable error)handler#>
}

@end
