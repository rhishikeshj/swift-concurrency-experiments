//
//  Atom.swift
//  AntsColony
//
//  Created by rhishikesh on 24/04/20.
//  Copyright © 2020 Helpshift. All rights reserved.
//

import Foundation

class Atom<T: Equatable> {
    var value: T
    private let lock: UnsafeMutablePointer<pthread_mutex_t>

    init(withValue v: T) {
        value = v
        lock = UnsafeMutablePointer.allocate(capacity: MemoryLayout<pthread_mutex_t>.size)

        pthread_mutex_init(lock, nil)
    }

    public func swap(usingFn fn: (T) -> T) {
        // capture the current value
        let v1 = value
        // run fn to update the value
        let v2 = fn(v1)

        // compare to see if someone changed the value
        pthread_mutex_lock(lock)
        if v1 != value {
            // unlock and try again
            pthread_mutex_unlock(lock)
            swap(usingFn: fn)
        } else {
            value = v2
            pthread_mutex_unlock(lock)
        }
    }

    public func deref() -> T {
        return value
    }
}
