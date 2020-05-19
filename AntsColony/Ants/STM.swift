//
//  STM.swift
//  AntsColony
//
//  Created by rhishikesh on 11/05/20.
//  Copyright © 2020 Helpshift. All rights reserved.
//  Implementation of : https://github.com/tvcutsem/stm-in-clojure/blob/master/stm/v2_mvcc.clj

import Foundation

var currentTransaction = ThreadLocal<Transaction?>(value: Transaction())

let GLOBAL_WRITE_POINT = Atom(withValue: 0)
let MAX_HISTORY = 10
let COMMIT_LOCK: UnsafeMutablePointer<pthread_mutex_t> = UnsafeMutablePointer.allocate(capacity: MemoryLayout<pthread_mutex_t>.size)

// MARK: Define Structs
public struct Ref : Hashable, Equatable {
    var history: Atom<[History<AnyHashable>]>?

    public init(with value: AnyHashable) {
        let newHistory = [History(value: value,
                                  writePoint: GLOBAL_WRITE_POINT.deref())]
        history = Atom(withValue: newHistory)
    }

    public func deref() -> AnyHashable? {
        if let transaction = currentTransaction.inner.value {
            do {
                let value = try txRead(tx: transaction, ref: self)
                return value
            } catch {
                print("Error in txRead is \(error)")
                return nil
            }
        } else if let h = self.history?.deref() {
            return h[0].value
        }
        return nil
    }

    public func set(value: AnyHashable) throws -> AnyHashable {
        guard let currentTransaction = currentTransaction.inner.value else {
            throw STMError.illegalState(message: "Cannot write outside of a transaction")
        }
        return txWrite(tx: currentTransaction,
                       ref: self,
                       value: value)
    }

    public func alter(fn: (AnyHashable?) -> AnyHashable?) throws -> AnyHashable? {
        if let newVal = fn(self.deref()) {
            return try set(value: newVal)
        }
        return nil
    }

    public func hash(into hasher: inout Hasher) {
        if let hist = self.history?.deref() {
            for h in hist {
                hasher.combine(h)
            }
        }
    }

    public static func == (lhs: Ref, rhs: Ref) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

struct History<T: Hashable>: Hashable {
    var value: T
    var writePoint: Int

    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
        hasher.combine(writePoint)
    }
}

public struct Transaction {
    static let initialize = {
        pthread_mutex_init(COMMIT_LOCK, nil)
        currentTransaction.inner.value = nil
    }

    var readPoint: Int = GLOBAL_WRITE_POINT.deref()
    var inTxValues: Atom<[Ref: AnyHashable]>? = Atom(withValue: [:])
    var writtenRefs: Atom<Set<Ref>>? = Atom(withValue: Set())

    public static func doSync(fn: () -> Void) {
        if currentTransaction.inner.value == nil {
            currentTransaction.inner.value = Transaction()
        }
        txRun(tx: currentTransaction.inner.value!, fn: fn)
    }
}

// MARK: Transaction utils
func findEntryBeforeOrOn(historyChain: [History<AnyHashable>], readPoint: Int) -> History<AnyHashable>? {
    for h in historyChain {
        if h.writePoint <= readPoint {
            return h
        }
    }
    return nil
}

func mostRecent(array: [Any]) -> Any {
    return array[0]
}

enum STMError: Error {
    case retry
    case illegalState(message: String)
}

func txRetry() throws {
    throw STMError.retry
}

// MARK: Clojure utils
func assoc(_ map: [Ref: AnyHashable],
           key: Ref, value: AnyHashable) -> [Ref: AnyHashable] {
    var new = map
    if new.keys.contains(key) {
        new.removeValue(forKey: key)
    }
    new[key] = value
    return new
}

func conj(_ set: Set<Ref>, value: Ref) -> Set<Ref> {
    if !set.contains(value) {
        var new = set
        new.insert(value)
        return new
    }
    return set
}

func cons<T>(_ arr: [T], value: T) -> [T] {
    var new = arr
    new.insert(value, at: 0)
    return new
}

func butLast<T>(_ arr: [T], capped: Int) -> [T] {
    var new = arr
    if new.count == capped {
        new.removeLast()
    }
    return new
}

// MARK: Transaction internal fns
func txRead(tx: Transaction, ref: Ref) throws -> AnyHashable? {
    guard let inTxValues = tx.inTxValues else {
        return nil
    }
    if let val = inTxValues.deref()[ref] {
        return val
    }
    if let history = ref.history?.deref(),
        let refEntry = findEntryBeforeOrOn(historyChain: history, readPoint: tx.readPoint) {
        let inTxValue = refEntry.value
        let _ = inTxValues.swap { assoc($0, key: ref, value: inTxValue) }
        return inTxValue
    } else {
        try txRetry()
    }
    assert(false, "Shouldn't really come here \(#function)")
}

func txWrite(tx: Transaction, ref: Ref, value: AnyHashable) -> AnyHashable {
//    if let inTx = tx.inTxValues?.deref() {
//        for (k,_) in inTx {
//            print("Item in inTx is \(k.hashValue)")
//        }
//    }
//    print("New item to add to dictionary is \(ref.hashValue)")
//    if let wr = tx.writtenRefs?.deref() {
//        for i in wr {
//            print("Item in written refs is \(i.hashValue)")
//        }
//    }
//    print("New item to add to set is \(ref.hashValue)")
    
    _ = tx.inTxValues?.swap(usingFn: { assoc($0, key: ref, value: value) })
    _ = tx.writtenRefs?.swap(usingFn: { conj($0, value: ref) })
    return value
}

func txCommit(tx: Transaction) throws {
    guard let writtenRefs = tx.writtenRefs else {
        return
    }

    if writtenRefs.deref().count > 0 {
        pthread_mutex_lock(COMMIT_LOCK)
        for w in writtenRefs.deref() {
            if let h = w.history?.deref()[0], h.writePoint > tx.readPoint {
                pthread_mutex_unlock(COMMIT_LOCK)
                try txRetry()
            }
        }
        guard let inTxValues = tx.inTxValues?.deref() else {
            pthread_mutex_unlock(COMMIT_LOCK)
            assert(false, "Error in committing values. inTxValues is nil")
        }
        let newWritePoint = GLOBAL_WRITE_POINT.deref() + 1
        for w in writtenRefs.deref() {
            if let currentValue = inTxValues[w] {
                let newHistory = History(value: currentValue, writePoint: newWritePoint)
                _ = w.history?.swap(usingFn: { cons(butLast($0, capped: MAX_HISTORY), value: newHistory) })
            }
        }
        _ = GLOBAL_WRITE_POINT.swap(usingFn: { $0 + 1 })
        currentTransaction.inner.value = nil
        pthread_mutex_unlock(COMMIT_LOCK)
    }
}

func txRun(tx: Transaction, fn: () -> Void) {
    currentTransaction.inner.value = tx
    do {
        print("Running the transaction fn")
        fn()
        try txCommit(tx: tx)
    } catch STMError.retry {
        txRun(tx: Transaction(), fn: fn)
    } catch {
        assert(false, "Unknown Error in running the transaction : \(error)")
    }
}

// MARK: Run transaction
public func runSTMTransactions() {
    Transaction.initialize()
    
    let count = 10
    let counter = Atom(withValue: 0)
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

    for _ in 0 ..< 100 {
        Thread {
            Transaction.initialize()
            for _ in 0 ..< 1000 {
                let rankFrom = Int.random(in: 0 ..< count)
                let rankTo = Int.random(in: 0 ..< count)
                let accountFrom = accounts[rankFrom].deref()?.base as! BankAccount
                let accountTo = accounts[rankTo].deref()?.base as! BankAccount

                if rankFrom != rankTo, accountFrom.balance != 0 {
                    print("Transferring from \(rankFrom) to \(rankTo) : ID \(counter.swap { old in old + 1 })")
                    Transaction.doSync {
                        let balance = accountFrom.balance
                        do {
                            let aFrom = BankAccount.withdraw(account: accountFrom, amount: balance)
                            let aTo = BankAccount.deposit(account: accountTo, amount: balance)
                            _ = try accounts[rankFrom].set(value: aFrom)
                            _ = try accounts[rankTo].set(value: aTo)
                        } catch {
                            assert(false, "Error in setting value in transaction \(error)")
                        }
                    }
                }
            }
        }.start()
    }
    
    //Thread.sleep(forTimeInterval: 20)
    while true {
        Thread.sleep(forTimeInterval: 1)
        Transaction.doSync {
            let sum = accounts.reduce(0) { acc, el in
                let val = (el.deref()?.base as! BankAccount).balance
                return acc + val
            }
            if sum != 300 {
                print("This is not working :: \(sum)")
                for acc in accounts {
                    print("Value is \(acc.deref()?.base)")
                }
                return
            }
        }
    }
}
