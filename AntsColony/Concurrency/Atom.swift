//
//  Atom.swift
//  AntsColony
//
//  Created by rhishikesh on 24/04/20.
//  Copyright © 2020 Helpshift. All rights reserved.
//

import Foundation

struct Atom<T: Hashable>: Hashable {
    var value: T
    private let lock: UnsafeMutablePointer<pthread_mutex_t>

    init(withValue v: T) {
        value = v
        lock = UnsafeMutablePointer.allocate(capacity: MemoryLayout<pthread_mutex_t>.size)

        pthread_mutex_init(lock, nil)
    }

    public mutating func swap(usingFn fn: (T) -> T) -> T {
        // capture the current value
        let v1 = value
        // run fn to update the value
        let v2 = fn(v1)

        // compare to see if someone changed the value
        pthread_mutex_lock(lock)
        if v1 != value {
            // unlock and try again
            pthread_mutex_unlock(lock)
            return swap(usingFn: fn)
        } else {
            value = v2
            pthread_mutex_unlock(lock)
        }
        return value
    }

    public func deref() -> T {
        return value
    }

    static func == (lhs: Atom<T>, rhs: Atom<T>) -> Bool {
        lhs.deref() == rhs.deref()
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
        hasher.combine(lock)
    }
}

struct Atomic<T: Hashable>: Hashable {
    var reference: AtomicReference<T>

    init(withValue v: T) {
        reference = AtomicReference(initialValue: v)
    }

    public mutating func swap(usingFn fn: (T) -> T) -> T {
        while true {
            let oldValue = reference.value
            if reference.compareAndSet(expect: oldValue, newValue: fn(oldValue)) {
                break
            } else {
                return swap(usingFn: fn)
            }
        }
        return reference.value
    }

    public func deref() -> T {
        return reference.value
    }

    static func == (lhs: Atomic<T>, rhs: Atomic<T>) -> Bool {
        lhs.deref() == rhs.deref()
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(reference.value)
    }
}
