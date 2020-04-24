//
//  AntsColonyTests.swift
//  AntsColonyTests
//
//  Created by rhishikesh on 04/04/20.
//  Copyright © 2020 Helpshift. All rights reserved.
//

@testable import AntsColony
import XCTest

class AntsColonyTests: XCTestCase {
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSingleThreadAccess() {
        measure {
            singleThreadAccess(1000)
        }
    }

    func testMultiThreadAccess() {
        // This is an example of a performance test case.
        measure {
            multiThreadAccess(1000)
        }
    }

    func testTransactions() {
        demoTransactions()
    }

    func testDelay() {
        var delayedCalculation1 = Delay<String> {
            Thread.sleep(forTimeInterval: 2)
            print("Inside the delay fn : 1")
            return "DelayedCalculation 1"
        }

        var delayedCalculation2 = Delay<String> {
            Thread.sleep(forTimeInterval: 2)
            print("Inside the delay fn : 2")
            return "DelayedCalculation 2"
        }

        print("Delay not yet realised")
        let answerNeeded = true
        if answerNeeded {
            print("First value is \(delayedCalculation1.deref())")
            print("But this will not cause another execution of delay \(delayedCalculation1.deref())")
            print("Second value is \(delayedCalculation2.deref())")
            print("But this will not cause another execution of delay \(delayedCalculation2.deref())")
        } else {
            print("Dont need that heavy calculation!")
        }
    }

    func testPromises() {
        let promise = Promise<Int>()

        DispatchQueue.global().async {
            Thread.sleep(forTimeInterval: 2)
            promise.deliver(value: 42)
        }

        print("Lets wait for the promise to be delivered!")
        XCTAssert(promise.deref() == 42)

        // Promises cannot be delivered more than once
        promise.deliver(value: 10)
        promise.deliver(value: 16)
        XCTAssert(promise.deref() == 42)
    }

    func testFutures() {
        let future = Future<Int> { () -> Int in
            print("Starting hard calculation")
            Thread.sleep(forTimeInterval: 2)
            print("Long hard calculation done!")
            return 42
        }

        print("Lets wait for the future to be realised!")
        XCTAssert(future.deref() == 42)
    }

    func testAtoms() {
        let counter = Atom<Int>(withValue: 0)

        for _ in 0 ..< 1000 {
            DispatchQueue.global().async {
                Thread.sleep(forTimeInterval: TimeInterval(Float.random(in: 0 ... 0.5)))
                counter.swap { old in
                    old + 1
                }
            }
        }

        Thread.sleep(forTimeInterval: 5)
        XCTAssert(counter.deref() == 1000)
    }

    func testAgents() {
        let agentCount = 10
        var agents = [Agent<Int>]()
        for _ in 0 ..< agentCount {
            agents.append(Agent(withValue: 0))
        }

        for n in 0 ..< 1_000_000 {
            let i = n % agentCount
            agents[i].send { old in
                old + n
            }
        }

        for i in 0 ..< agentCount {
            agents[i].await()
        }

        let sum = agents.reduce(0) { x, y in
            x + y.deref()
        }

        XCTAssert(sum == 499999500000)
    }
}
