//
//  Transaction.swift
//  AntsColony
//
//  Created by rhishikesh on 02/05/20.
//  Copyright © 2020 Helpshift. All rights reserved.
//

import Foundation

class Locker<T: Equatable> {
    var value: T?
    let lock: UnsafeMutablePointer<pthread_mutex_t>

    init(withValue v: T) {
        value = v
        lock = UnsafeMutablePointer.allocate(capacity: MemoryLayout<pthread_mutex_t>.size)

        pthread_mutex_init(lock, nil)
    }

    public func deref() -> T? {
        pthread_mutex_lock(lock)
        let val = value
        pthread_mutex_unlock(lock)
        return val
    }

    public func unsafeValue() -> T? {
        return value
    }

    public func set(_ val: T?) {
        value = val
    }

    public func transfer(to other: Locker<T>, using updateFn: (Locker<T>, Locker<T>) -> Void) {
        while true {
            pthread_mutex_lock(lock)
            if pthread_mutex_trylock(other.lock) == 0 {
                updateFn(self, other)
                value = nil
                pthread_mutex_unlock(other.lock)
                pthread_mutex_unlock(lock)
                return
            } else {
                pthread_mutex_unlock(lock)
                pthread_mutex_lock(other.lock)
                if pthread_mutex_trylock(lock) == 0 {
                    updateFn(self, other)
                    value = nil
                    pthread_mutex_unlock(lock)
                    pthread_mutex_unlock(other.lock)
                    return
                } else {
                    pthread_mutex_unlock(other.lock)
                }
            }
        }
    }
}

func printAll(_ accounts: [Locker<Int>]) {
    for acc in accounts {
        print("Value is \(acc.deref() ?? 0)")
    }
}

func runTransactions() {
    let count = 10
    var accounts = [Locker<Int>]()
    let lock: UnsafeMutablePointer<pthread_mutex_t> = UnsafeMutablePointer.allocate(capacity: MemoryLayout<pthread_mutex_t>.size)

    pthread_mutex_init(lock, nil)

    // 3 accounts with initial values
    accounts.append(Locker(withValue: 100))
    accounts.append(Locker(withValue: 100))
    accounts.append(Locker(withValue: 100))

    for _ in 0 ..< count - 3 {
        accounts.append(Locker(withValue: 0))
    }

    var counter = Atom(withValue: 0)

    for _ in 1 ... 1 {
        Thread {
            for _ in 1 ... 400 {
                let rankFrom = Int.random(in: 0 ..< count)
                let rankTo = Int.random(in: 0 ..< count)
                if rankFrom != rankTo, accounts[rankFrom].deref() != 0 {
                    print("Transferring from \(rankFrom) to \(rankTo) : ID \(counter.swap { old in old + 1 })")
                    accounts[rankFrom].transfer(to: accounts[rankTo]) { x, y in
                        y.set((x.unsafeValue() ?? 0) + (y.unsafeValue() ?? 0))
                    }
                }
            }
        }.start()
    }

    // Thread.sleep(forTimeInterval: 3000)
    while true {
        let sum = accounts.reduce(0) { acc, el in
            let val = el.deref() ?? 0
            return acc + val
        }
        if sum != 300 {
            print("This is not working :: \(sum)")
            printAll(accounts)
            return
        }
    }
}
