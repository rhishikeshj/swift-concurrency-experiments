//
//  Agent.swift
//  AntsColony
//
//  Created by rhishikesh on 24/04/20.
//  Copyright © 2020 Helpshift. All rights reserved.
//

import Foundation

class Agent<T> {
    var value: T
    let queue = DispatchQueue(label: "com.helpshift.agent.\(Int.random(in: 0 ... Int.max))", qos: .background)

    init(withValue v: T) {
        value = v
    }

    public func send(update fn: @escaping (T) -> T) {
        queue.async {
            self.value = fn(self.value)
        }
    }

    public func await() {
        queue.sync {
            // some work
        }
    }

    public func deref() -> T {
        queue.sync {
            // some work
        }
        return value
    }
}
