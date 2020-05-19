//
//  Ref.swift
//  AntsColony
//
//  Created by rhishikesh on 05/04/20.
//  Copyright © 2020 Helpshift. All rights reserved.
//

import Foundation

class BadRef<A: Equatable> {
    private var val: A?
    private let lock: UnsafeMutablePointer<pthread_mutex_t>

    public init() {
        val = .none
        lock = UnsafeMutablePointer.allocate(capacity: MemoryLayout<pthread_mutex_t>.size)

        pthread_mutex_init(lock, nil)
    }

    /// Creates a new `Ref` containing the supplied value.
    public convenience init(initial: A) {
        self.init()
        put(initial)
    }

    private func put(_ x: A) {
        val = x
    }

    public func deref() -> A {
        let value = val!
        return value
    }

    public func alter(_ f: (A) throws -> A) {
        let a = val!
        do {
            let a1 = try f(a)
            // has a write happened ?
            if a1 != a {
                // Transaction
                pthread_mutex_lock(lock)
                // check if the value is still what we expect
                if val! == a {
                    // yes, put the value, we won !
                    val = a1
                    pthread_mutex_unlock(lock)
                } else {
                    // no, try again
                    pthread_mutex_unlock(lock)
                    alter(f)
                }
            }
        } catch _ {
            put(a)
        }
    }
}

func assoc(_ map: [String: Int], key: String, value: Int) -> [String: Int] {
    var new = map
    new[key] = value
    return new
}

func multiThreadAccess(_ count: Int) {
    let initialValue: [String: Int] = [:]
    let place = BadRef(initial: initialValue)

    // this emulates multi thread access with contention.
    for i in 1 ... count {
        DispatchQueue.global(qos: .userInteractive).async {
            place.alter { (old: [String: Int]) -> [String: Int] in
                assoc(old, key: "key:\(i)", value: i)
            }
        }
    }

    let t0 = Date().timeIntervalSince1970
    // This is just to ensure that work is done
    while place.deref().keys.count < count {
        sleep(1)
    }
    let t1 = Date().timeIntervalSince1970
    print("Time taken : \(t1 - t0)")
    print("Number of keys : \(place.deref().keys.count)")
}

func singleThreadAccess(_ count: Int) {
    let initialValue: [String: Int] = [:]
    let place = BadRef(initial: initialValue)
    // this is single thread access, no contention or retries.
    DispatchQueue.global(qos: .userInteractive).async {
        for i in 1 ... count {
            place.alter { (old: [String: Int]) -> [String: Int] in
                assoc(old, key: "key:\(i)", value: i)
            }
        }
    }
    let t0 = Date().timeIntervalSince1970
    // This is just to ensure that work is done
    while place.deref().keys.count < count {
        sleep(1)
    }
    let t1 = Date().timeIntervalSince1970
    print("Time taken : \(t1 - t0)")
    print("Number of keys : \(place.deref().keys.count)")
}

func simpleAccess(_ count: Int) {
    let initialValue: [String: Int] = [:]
    // this is best case, no contention, no function calls.
    DispatchQueue.global(qos: .userInteractive).async {
        let t0 = Date().timeIntervalSince1970

        var old = initialValue
        for i in 1 ... count {
            var new = old
            new["key\(i)"] = i
            old = new
        }
        let t1 = Date().timeIntervalSince1970
        print("Time taken : \(t1 - t0)")
        print("Number of keys : \(old.keys.count)")
    }
}

func simpleFunctionAccess(_ count: Int) {
    let initialValue: [String: Int] = [:]

    // this is best case with function call overheads.
    DispatchQueue.global(qos: .userInteractive).async {
        let t0 = Date().timeIntervalSince1970

        var old = initialValue
        for i in 1 ... count {
            old = assoc(old, key: "key:\(i)", value: i)
        }
        let t1 = Date().timeIntervalSince1970
        print("Time taken : \(t1 - t0)")
    }
}
