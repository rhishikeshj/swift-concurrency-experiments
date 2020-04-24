//
//  Promise.swift
//  AntsColony
//
//  Created by rhishikesh on 24/04/20.
//  Copyright © 2020 Helpshift. All rights reserved.
//

import Foundation

// @FIXME: This needs to be a class.
// If this is a struct, the deref method will capture
// the value of self and updates done via deliver
// will not be reflected
class Promise<T> {
    var value: T?
    let token: Int
    var isDelivered: Bool
    let promise = NSCondition()

    init() {
        token = Int.random(in: 0 ... Int.max)
        isDelivered = false
    }

    public func deliver(value: T) {
        DispatchQueue.once(token: token) {
            promise.lock()
            self.value = value
            self.isDelivered = true
            promise.signal()
            promise.unlock()
        }
    }

    public func deref() -> T {
        promise.lock()
        while !isDelivered {
            promise.wait()
        }
        promise.unlock()
        return value!
    }
}
