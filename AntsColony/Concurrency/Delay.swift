//
//  Delay.swift
//  AntsColony
//
//  There's a Clojure function called delay.
//  It creates an object called a Delay. A Delay ensures that some code is either run zero or one time.
//  It's run zero times if the Delay is never derefed.
//  And it's run once if it is derefed, regardless of how many times it's derefed.

//  Created by rhishikesh on 24/04/20.
//  Copyright © 2020 Helpshift. All rights reserved.
//

import Foundation

struct Delay<T> {
    let fn: () -> T
    var value: T?
    let token: Int

    init(withFn fn: @escaping () -> T) {
        self.fn = fn
        token = Int.random(in: 0 ... Int.max)
    }

    public mutating func deref() -> T {
        DispatchQueue.once(token: token, closure: {
            value = self.fn()
        })
        return value!
    }
}
