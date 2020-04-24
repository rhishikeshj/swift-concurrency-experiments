//
//  Future.swift
//  AntsColony
//
//  Created by rhishikesh on 24/04/20.
//  Copyright © 2020 Helpshift. All rights reserved.
//

import Foundation

class Future<T> {
    let fn: () -> T
    var value: T?
    let token: Int
    var isRealised: Bool
    let promise = NSCondition()

    init(withFn fn: @escaping () -> T) {
        self.fn = fn
        token = Int.random(in: 0 ... Int.max)
        isRealised = false
        let t = Thread {
            DispatchQueue.once(token: self.token) {
                self.promise.lock()
                self.value = self.fn()
                self.isRealised = true
                self.promise.signal()
                self.promise.unlock()
            }
        }
        t.start()
    }

    public func deref() -> T {
        promise.lock()
        while !isRealised {
            promise.wait()
        }
        promise.unlock()
        return value!
    }
}
