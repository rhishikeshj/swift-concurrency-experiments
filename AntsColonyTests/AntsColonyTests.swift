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
        var counter = Atom<Int>(withValue: 0)
        measure {
            label: for _ in 0 ..< 20 {
                Thread {
                    for _ in 0 ..< 400 {
                        counter.swap { $0 + 1 }
                    }
                }.start()
            }
        }
        Thread.sleep(forTimeInterval: 3)
        XCTAssertEqual(counter.deref(), 80000)
    }

    func testAtomics() {
        var counter = Atomic<Int>(withValue: 0)

        measure {
            for _ in 0 ..< 20 {
                Thread {
                    for _ in 0 ..< 400 {
                        counter.swap { $0 + 1 }
                    }
                }.start()
            }
        }
        Thread.sleep(forTimeInterval: 3)
        XCTAssertEqual(counter.deref(), 80000)
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

        XCTAssert(sum == 499_999_500_000)
    }

    func testDispatchGroups() {
        let mygroup = DispatchGroup()
        let globalDefault = DispatchQueue.global()

        for i in 0 ..< 5 {
            globalDefault.async(group: mygroup) {
                sleep(UInt32(i))
                print("Group async on globalDefault:" + String(i))
            }
        }
        print("Waiting for completion...")
        // this is the last job to execute in the group
        mygroup.notify(queue: globalDefault) {
            print("Notify received, done waiting.")
        }
        // this is for blocking wait for all other previously submitted
        // jobs in this group
        mygroup.wait()
        print("Done waiting.")
    }

    func testNewTransactions() {
        runTransactions()
    }

    func testSTMTransactions() {
        // runSTMTransactions()
        runSTMTransactionsOnMaps()
    }

    func testAssoc() {
        var someRef = Ref(with: ":a")
        let map1 = [Ref(with: "a"): 1,
                    Ref(with: "b"): 2,
                    Ref(with: "c"): 3,
                    someRef: 42]
        print(assoc(map1, key: Ref(with: "a"), value: 3))
        try? someRef.set(value: ":b")
        print(map1[someRef])
        print(try? someRef.deref())
    }

    func testWrittenRefs() {
        var writtenRefs: Atom<Set<Ref>>? = Atom(withValue: Set())

        let count = 10
        var accounts: [Ref] = []

        let ref1 = Ref(with: BankAccount(name: "Rhi-1", balance: 100))
        let ref2 = Ref(with: BankAccount(name: "Rhi-2", balance: 100))
        let ref3 = Ref(with: BankAccount(name: "Rhi-3", balance: 100))

        accounts.append(ref1)
        accounts.append(ref2)
        accounts.append(ref3)

        for i in 3 ..< count {
            accounts.append(Ref(with: BankAccount(name: "Rhi-\(i)", balance: 0)))
        }

        for _ in 0 ..< 20 {
            Thread {
                for _ in 0 ..< 20 {
                    let rankFrom = Int.random(in: 0 ..< count)
                    let accountFrom = accounts[rankFrom]

                    _ = writtenRefs?.swap(usingFn: { set in
                        conj(set, value: accountFrom)
                    })
                }
            }.start()
        }

        Thread.sleep(forTimeInterval: 5)
        for s in (writtenRefs?.deref())! {
            print("Hashvalue of item is \(s.hashValue)")
        }
    }
}
