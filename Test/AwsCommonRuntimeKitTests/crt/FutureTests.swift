//  Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
//  SPDX-License-Identifier: Apache-2.0.
import XCTest
@testable import AwsCommonRuntimeKit

class FutureTests: XCTestCase {

    func testFuture() throws {
        let future = Future<String>(value: .success("test"))
        let expectation = XCTestExpectation(description: "then succeeded")
        future.then { result in
            XCTAssertEqual("test", try! result.get())
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    func testFutureVoid() throws {
        let future = Future<Void>(value: .success(()))
        let expectation = XCTestExpectation(description: "then succeeded")
        future.then { _ in

            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testFutureFromDifferentThread() throws {
        let group = DispatchGroup()
        //create new future
        let future = Future<String>()
        
        for _ in 0...1000 {
            group.enter()

            DispatchQueue.global().async {
                let sleepVal = arc4random() % 1000
                usleep(sleepVal)
                future.fulfill("value is finally fulfilled")
                group.leave()
            }
        }
        
        let result = group.wait(timeout: DispatchTime.now() + 5)

        XCTAssert(result == .success)
    }
    
    func testFutureFromMultipleThreads()  throws {
        //create new future
        let group = DispatchGroup()
        let globalQueue = DispatchQueue.global()
        let mainThread = DispatchQueue.main
        let future = Future<String>()
        
        globalQueue.async {
            group.enter()
            future.then { (result) in
                group.leave()
            }
        }
        
        mainThread.async {
            group.enter()
            future.then { (result) in
                group.leave()
            }
        }
        
        future.fulfill("value is finally fulfilled")
        let result = group.wait(timeout: DispatchTime.now() + 10)

        XCTAssert(result == .success)
    }
}