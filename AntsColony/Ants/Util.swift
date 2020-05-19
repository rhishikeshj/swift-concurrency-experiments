//
//  Util.swift
//  AntsColony
//
//  Created by rhishikesh on 09/05/20.
//  Copyright © 2020 Helpshift. All rights reserved.
//

import Foundation

public func rankBy<T>(_ comparator: (T, T) -> Bool, xs: [T]) -> [T: Int] {
    let sorted = xs.sorted(by: comparator)
    var ranks: [T: Int] = [:]
    var rank = 1 // WE NEED A 1 based rank !!
    for c in sorted {
        ranks[c] = rank
        rank += 1
    }
    return ranks
}

public func bound(by: Int, n: Int) -> Int {
    let n1 = n % by
    if n1 < 0 {
        return n1 + by
    } else {
        return n1
    }
}

public func roulette(of slices: [Int]) -> Int {
    let total = slices.reduce(0) { (acc, a) -> Int in
        acc + a
    }
    let r = Int.random(in: 0 ..< total)
    var sum = 0
    for i in 0 ..< slices.count {
        if r < (slices[i] + sum) {
            return i
        }
        sum = sum + slices[i]
    }
    return -1
}

public func scaledColor(_ of: [String: Int]) -> Int {
    min(255, 255 * (of["value"]! / of["max-value"]!))
}

public func delta(x: (Int, Int, Int, Int), by: (Int, Int)) -> (Int, Int, Int, Int) {
    (x.0 + by.0, x.1 + by.1, x.2 + by.0, x.3 + by.1)
}

public func scale(it: (Int, Int), by: Int) -> (Int, Int) {
    (it.0 * by, it.1 * by)
}

// MARK: Clojure util functions for swift

public func juxt<T, A>(fns: ((T, _ additionals: [A]) -> Any)...) -> (T, _ additionals: [A]) -> [Any] {
    return { (x: T, args: [A]) in
        var returns: [Any] = []
        for fn in fns {
            returns.append(fn(x, args))
        }
        return returns
    }
}

public func partial(fn: @escaping (Any...) -> Any,
                    some args: Any...) -> (Any...) -> Any {
    return { (rest: Any...) -> Any in
        var vals: [Any] = []
        for i in args {
            vals.append(i)
        }
        for i in rest {
            vals.append(i)
        }
        return fn(vals)
    }
}

public func mergeWith<K: Hashable, V>(fn: (V, V) -> V, maps: [K: V]...) -> [K: V] {
    var newMap: [K: V] = [:]
    for m in maps {
        for (k, v) in m {
            if let val = newMap[k] {
                newMap.updateValue(fn(val, v), forKey: k)
            } else {
                newMap[k] = v
            }
        }
    }
    return newMap
}
