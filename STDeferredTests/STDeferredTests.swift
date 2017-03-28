//
//  STDeferredTest.swift
//  STDeferred
//
//  Copyright © 2015 saiten. All rights reserved.
//

import XCTest
import STDeferred
import Result

private enum TestError : String, Error {
    case fail = "fail"
    case first = "first"
    case second = "second"
    case third = "third"
}

class STDeferredTest: XCTestCase {

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testSuccess() {
        var count = 1
        let deferred = Deferred<String, TestError>()
        deferred
        .success { (value) in
            XCTAssertEqual("success", value)
            XCTAssertEqual(1, count)
            count += 1
        }.success { (value) in
            XCTAssertEqual("success", value)
            XCTAssertEqual(2, count)
            count += 1
        }.failure { (error) in
            XCTFail()
        }.resolve("success")
        
        XCTAssertEqual(3, count)
    }
    
    func testSuccessAfterResolve() {
        let deferred = Deferred<String, TestError>()
        deferred.resolve("hoge")
        
        deferred
        .success { (value) in
            XCTAssertEqual("hoge", value)
        }.failure { (error) in
            XCTFail()
        }
    }
    
    
    func testFailure() {
        var count = 1
        let deferred = Deferred<String, TestError>()
        deferred
        .success { (value) in
            XCTFail()
        }.failure { (error) in
            XCTAssertEqual("fail", error!.rawValue)
            XCTAssertEqual(1, count)
            count += 1
        }.failure { (error) in
            XCTAssertEqual("fail", error!.rawValue)
            XCTAssertEqual(2, count)
            count += 1
        }.reject(.fail)
        
        XCTAssertEqual(3, count)
    }
    
    func testFailureAfterReject() {
        let deferred = Deferred<String, TestError>()
        deferred.reject(.fail)
        
        deferred
        .success { (value) in
            XCTFail()
        }.failure { (error) in
            XCTAssertEqual("fail", error!.rawValue)
        }
    }
    
    func testComplete() {
        Deferred<String, TestError>()
        .success { (value) in
            XCTAssertEqual("hoge", value)
        }
        .failure { (error) in
            XCTFail()
        }
        .complete { (result) in
            switch result! {
            case .success(let value):
                XCTAssertEqual("hoge", value)
            case .failure:
                XCTFail()
            }
        }
        .resolve("hoge")
        
        Deferred<String, TestError>()
        .success { (value) in
            XCTFail()
        }
        .failure { (error) in
            XCTAssertEqual("fail", error!.rawValue)
        }
        .complete { (result) in
            switch result! {
            case .success:
                XCTFail()
            case .failure(let error):
                XCTAssertEqual("fail", error.rawValue)
            }
        }
        .reject(.fail)
    }
    
    
    func testCompleteAfterResolve() {
        let deferred = Deferred<String, TestError>()
        deferred.resolve("hoge")
        
        deferred
        .success { (value) in
            XCTAssertEqual("hoge", value)
        }
        .failure { (error) in
            XCTFail()
        }
        .complete { (result) in
            switch result! {
            case .success(let value):
                XCTAssertEqual("hoge", value)
            case .failure:
                XCTFail()
            }
        }

        let deferred2 = Deferred<String, TestError>()
        deferred2.reject(.fail)
        
        deferred2
        .success { (value) in
            XCTFail()
        }
        .failure { (error) in
            XCTAssertEqual("fail", error!.rawValue)
        }
        .complete { (result) in
            switch result! {
            case .success:
                XCTFail()
            case .failure(let error):
                XCTAssertEqual("fail", error.rawValue)
            }
        }
        .reject(.fail)
    }

    func testPipe() {
        let expectation = self.expectation(description: "testPipe")

        var count = 0
        
        let deferred = Deferred<String, TestError>()
        deferred
        .pipe { (result) -> Deferred<Int, TestError> in
            switch result! {
            case .success(let value):
                XCTAssertEqual("start", value)
            case .failure:
                XCTFail()
            }
            let d2 = Deferred<Int, TestError>()
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
                XCTAssertEqual(1, count)
                count += 1
                d2.resolve(12345)
            }
            
            return d2
        }
        .pipe { (result) -> Result<String, TestError>? in
            switch result! {
            case .success(let value):
                XCTAssertEqual(12345, value)
            case .failure:
                XCTFail()
            }
            XCTAssertEqual(2, count)
            count += 1
            return Result<String, TestError>(value: "second")
        }
        .pipe { (result) -> Result<String, TestError>? in
            switch result! {
            case .success(let value):
                XCTAssertEqual("second", value)
            case .failure:
                XCTFail()
            }
            XCTAssertEqual(3, count)
            count += 1
            return Result<String, TestError>(value: "third")
        }
        .success { (value) in
            XCTAssertEqual("third", value)
            XCTAssertEqual(4, count)
            count += 1
            expectation.fulfill()
        }
        .failure { (error) in
            XCTFail()
        }
    
        deferred.resolve("start")
        XCTAssertEqual(0, count)
        count += 1
    
        self.waitForExpectations(timeout: 5.0) { (error) in }
    }
    
    func testPipeFailure() {
        let expectation = self.expectation(description: "testPipeFailure")
        
        var count = 0
        
        let deferred = Deferred<String, TestError>()
        deferred
        .pipe { (result) -> Deferred<Int, TestError> in
            switch result! {
            case .success:
                XCTFail()
            case .failure(let error):
                XCTAssertEqual("fail", error.rawValue)
            }
            let d2 = Deferred<Int, TestError>()
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
                XCTAssertEqual(1, count)
                count += 1
                d2.reject(TestError.first)
            }
            
            return d2
        }
        .pipe { (result) -> Result<String, TestError>? in
            switch result! {
            case .success:
                XCTFail()
            case .failure(let error):
                XCTAssertEqual("first", error.rawValue)
            }
            XCTAssertEqual(2, count)
            count += 1
            return Result<String, TestError>(error: TestError.second)
        }
        .pipe { (result) -> Result<String, TestError>? in
            switch result! {
            case .success:
                XCTFail()
            case .failure(let error):
                XCTAssertEqual("second", error.rawValue)
            }
            XCTAssertEqual(3, count)
            count += 1
            return Result<String, TestError>(error: TestError.third)
        }
        .success { (value) in
            XCTFail()
        }
        .failure { (error) in
            XCTAssertEqual("third", error!.rawValue)
            XCTAssertEqual(4, count)
            count += 1
            expectation.fulfill()
        }
        
        deferred.reject(.fail)
        XCTAssertEqual(0, count)
        count += 1
        
        self.waitForExpectations(timeout: 5.0) { (error) in }
    }
    
    func testThen() {
        let expectation = self.expectation(description: "testThen")
        
        var count = 0
        
        let deferred = Deferred<String, TestError>()
        deferred
        .then { (value) -> String in
            XCTAssertEqual("start", value)
            XCTAssertEqual(1, count)
            count += 1
            return "first"
        }
        .then { (value) -> Result<String, TestError> in
            XCTAssertEqual("first", value)
            XCTAssertEqual(2, count)
            count += 1
            return Result<String, TestError>(value: "second")
        }
        .then { (value) -> Deferred<String, TestError> in
            XCTAssertEqual("second", value)
            XCTAssertEqual(3, count)
            count += 1
            return Deferred<String, TestError>(result: Result<String, TestError>(value: "third"))
        }
        .success { (value) in
            XCTAssertEqual("third", value)
            XCTAssertEqual(4, count)
            count += 1
            expectation.fulfill()
        }
        .failure { (error) in
            XCTFail()
        }
        
        XCTAssertEqual(0, count)
        count += 1
        deferred.resolve("start")
        XCTAssertEqual(5, count)
        count += 1

        self.waitForExpectations(timeout: 5.0) { (error) in }
    }
    
    func testWhen() {        
        let expectation = self.expectation(description: "testWhen")
        
        let d1 = Deferred<String, TestError>()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
            d1.resolve("1 sec")
        }

        let d2 = Deferred<String, TestError>()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(2 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
            d2.resolve("2 sec")
        }

        when(d1, d2).success { (values: [String]) in
            XCTAssertEqual(2, values.count)
            XCTAssertEqual("1 sec", values[0])
            XCTAssertEqual("2 sec", values[1])
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 5.0) { (error) in }
    }

    func testWhenMultiType() {
        let expectation = self.expectation(description: "testWhenMultiType")
        
        let d1 = Deferred<String, TestError>()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
            d1.resolve("1 sec")
        }
        
        let d2 = Deferred<Int, TestError>()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(2 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
            d2.resolve(2)
        }
        
        when(d1, d2).success { (v1, v2) in
            XCTAssertEqual("1 sec", v1)
            XCTAssertEqual(2, v2)
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 5.0) { (error) in }
    }
    
    func testCancel() {
        let deferred = Deferred<String, TestError>()
        .success { (value) in
            XCTFail()
        }
        .failure { (error) in
            XCTAssert(error == nil)
        }
        
        deferred.cancel()
    }

    func testCancelAfterResolve() {
        let deferred = Deferred<String, TestError>()
        .success { (value) in
            XCTAssertEqual("hoge", value)
        }
        .failure { (error) in
            XCTFail()
        }
        .canceller {
            XCTFail()
        }

        deferred.resolve("hoge")
        deferred.cancel()
    }

    func testCancelAfterReject() {
        let deferred = Deferred<String, TestError>()
        .success { (value) in
            XCTFail()
        }
        .failure { (error) in
            XCTAssertEqual("fail", error!.rawValue)
        }
        .canceller {
            XCTFail()
        }
        
        deferred.reject(.fail)
        deferred.cancel()
    }
    
    func testCancelUndefinedCanceller() {
        let deferred = Deferred<String, TestError>()
        .success { (value) in
            XCTFail()
        }
        .failure { (error) in
            XCTAssert(error == nil)
        }
        
        deferred.cancel()
        deferred.resolve("hoge")
    }
    
    func testCancelWhen() {
        var count = 0;
        
        let d1 = Deferred<String, TestError>()
        .failure { (error) in
            XCTAssert(error == nil)
        }
        .canceller {
            XCTAssertEqual(1, count)
            count += 1
        }
        
        let d2 = Deferred<String, TestError>()
        .failure { (error) in
            XCTAssert(error == nil)
        }
        .canceller {
            XCTAssertEqual(2, count)
            count += 1
        }

        let deferred = when(d1, d2)
        .success { (s1, s2) in
            XCTFail()
        }
        .failure { (error) in
            XCTAssert(error == nil)
            XCTAssertEqual(3, count)
            count += 1
        }

        XCTAssertEqual(0, count)
        count += 1
        deferred.cancel()
        XCTAssertEqual(4, count)
    }
    
    func testCancelPipe() {
        var count = 0;
        
        let d1 = Deferred<String, TestError>()
        d1.canceller {
            XCTAssertEqual(1, count)
            count += 1
        }

        let d2 = d1.pipe { $0 }
        let d3 = d2.pipe { $0 }
        
        d3.failure { (error) in
            XCTAssert(error == nil)
            XCTAssertEqual(2, count)
            count += 1
        }

        XCTAssertEqual(0, count)
        count += 1
        d3.cancel()
    }
    
    func testCancelPipeHalfway() {
        var count = 0
        
        let deferred = Deferred<String, TestError>().resolve("start")
        .pipe { _ in
            return Deferred<String, TestError>()
            .success { _ in
                XCTFail()
            }
            .failure { _ in
                XCTAssertEqual(2, count)
                count += 1
            }
            .canceller {
                XCTAssertEqual(1, count)
                count += 1
            }
        }
        .pipe { (result) -> Result<String, TestError>? in
            XCTAssert(result == nil)
            return result
        }
        
        XCTAssertEqual(0, count)
        count += 1

        deferred
        .success { _ in
            XCTFail()
        }
        .failure { _ in
            XCTAssertEqual(3, count)
            count += 1
        }
        
        deferred.cancel()
    }
    
    func testCancelPipeLast() {
        var count = 0
        
        let deferred = Deferred<String, TestError>().resolve("start")
        .pipe { (result) -> Deferred<String, TestError> in
            XCTAssertEqual("start", result!.value!)
            return Deferred<String, TestError>().resolve("first")
                .canceller { XCTFail() }
        }
        .pipe { (result) -> Deferred<String, TestError> in
            XCTAssertEqual("first", result!.value!)
            return Deferred<String, TestError>().resolve("second")
                .canceller { XCTFail() }
        }
        .pipe { _ in
            return Deferred<String, TestError>()
            .success { _ in
                XCTFail()
            }
            .failure { _ in
                XCTAssertEqual(2, count)
                count += 1
            }
            .canceller {
                XCTAssertEqual(1, count)
                count += 1
            }
        }
        
        XCTAssertEqual(0, count)
        count += 1

        deferred
        .success { _ in
            XCTFail()
        }
        .failure { _ in
            XCTAssertEqual(3, count)
            count += 1
        }
        
        deferred.cancel()
    }
    
    func testCancelInPipe() {
        let expectation = self.expectation(description: "testCancelInPipe")
        
        var count = 0
        
        let deferred = Deferred<String, TestError>()
        
        let d1 = Deferred<Void, TestError>().resolve()
        .pipe { _ -> Deferred<Void, TestError> in
            XCTAssertEqual(0, count)
            count += 1
            return Deferred<Void, TestError>().resolve().canceller { XCTFail() }
        }
        .pipe { _ -> Deferred<Void, TestError> in
            XCTAssertEqual(1, count)
            count += 1

            let d = Deferred<Void, TestError>()
            .canceller {
                XCTAssertEqual(4, count)
                count += 1
            }
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(2 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
                XCTAssertEqual(5, count)
                count += 1
                XCTAssertTrue(d.isCancelled)
                d.resolve()
            }
            
            return d
        }
        .pipe { $0 }
        .pipe { $0 }
        
        let d2 = Deferred<Void, TestError>().resolve()
        .canceller { XCTFail() }
        .success { XCTAssertTrue(true) }

        let setup = when(d1, d2)
        .success {
            XCTFail()
        }
        .failure { (error) in
            XCTAssert(error == nil)
            deferred.reject(.fail)
            expectation.fulfill()
        }
        
        deferred.canceller {
            XCTAssertEqual(3, count)
            count += 1
            setup.cancel()
        }

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
            XCTAssertEqual(2, count)
            count += 1
            deferred.cancel()
        }

        self.waitForExpectations(timeout: 5.0) { _ in }
    }
    
    func testInitClosure() {
        let expectation = self.expectation(description: "testInitClosure")
        
        Deferred<String, TestError> { (resolve, _, _) in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
                resolve("success")
            }
        }
        .success { (value) in
            XCTAssertEqual("success", value)
        }
        .failure { _ in
            XCTFail()
        }

        Deferred<String, TestError> { (_, reject, _) in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
                reject(.fail)
            }
        }
        .success { (value) in
            XCTFail()
        }
        .failure { (error) in
            XCTAssertEqual("fail", error!.rawValue)
        }

        Deferred<String, TestError> { (_, _, cancel) in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(2 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
                cancel()
            }
        }
        .success { (value) in
            XCTFail()
        }
        .failure { (error) in
            XCTAssert(error == nil)
            expectation.fulfill()
        }

        self.waitForExpectations(timeout: 5.0) { _ in }
    }
    
    func testSync() {
        let d1 = Deferred<String, TestError>()

        Deferred<String, TestError>().sync(d1)
        .success { (value) in
            XCTAssertEqual("success", value)
        }
        .failure { (error) in
            XCTFail()
        }
        d1.resolve("success")
        
        let d2 = Deferred<String, TestError>()
        Deferred<String, TestError>().sync(d2)
        .success { (value) in
            XCTFail()
        }
        .failure { (error) in
            XCTAssertEqual("fail", error!.rawValue)
        }
        d2.reject(.fail)
        
        let d3 = Deferred<String, TestError>()
        Deferred<String, TestError>().sync(d3)
        .success { (value) in
            XCTFail()
        }
        .failure { (error) in
            XCTAssertNil(error)
        }
        d3.cancel()
    }
    
}

