//
//  STM.swift
//  AntsColony
//
//  Created by rhishikesh on 11/05/20.
//  Copyright © 2020 Helpshift. All rights reserved.
//  Implementation of : https://github.com/tvcutsem/stm-in-clojure/blob/master/stm/v2_mvcc.clj

import Foundation

var currentTransaction = ThreadLocal<Transaction?>(value: Transaction())

var GLOBAL_WRITE_POINT = Atom(withValue: 0)
var TRANSACTION_ID = Atom(withValue: 0)
let MAX_HISTORY = 10
let COMMIT_LOCK: UnsafeMutablePointer<pthread_mutex_t> = UnsafeMutablePointer.allocate(capacity: MemoryLayout<pthread_mutex_t>.size)

// MARK: Define Structs

public class Ref: Hashable, Equatable, CustomStringConvertible {
    var history: Atom<[History<AnyHashable>]>?

    public init(with value: AnyHashable) {
        let newHistory = [History(value: value,
                                  writePoint: GLOBAL_WRITE_POINT.deref())]
        history = Atom(withValue: newHistory)
    }

    public var description: String { return "Ref :: History -> \(history)" }

    public func deref() throws -> AnyHashable? {
        if let _ = currentTransaction.inner.value {
            do {
                let value = try txRead(tx: &currentTransaction.inner.value!, ref: self)
                return value
            } catch {
                print("Error in txRead is \(error)")
                throw STMError.retry
            }
        } else if let h = self.history?.deref() {
            return h[0].value
        }
        return nil
    }

    public func set(value: AnyHashable) throws -> AnyHashable {
        guard let _ = currentTransaction.inner.value else {
            throw STMError.illegalState(message: "Cannot write outside of a transaction")
        }
        return txWrite(tx: &currentTransaction.inner.value!,
                       ref: self,
                       value: value)
    }

    public func alter(fn: (AnyHashable?) -> AnyHashable?) throws -> AnyHashable? {
        if let newVal = fn(try self.deref()) {
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

struct History<T: Hashable>: Hashable, CustomStringConvertible {
    var value: T
    var writePoint: Int

    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
        hasher.combine(writePoint)
    }

    public var description: String { return "History :: Value -> \(value) WritePoint -> \(writePoint)" }
}

public struct Transaction {
    static let ensure: Void = {
        pthread_mutex_init(COMMIT_LOCK, nil)
    }()

    var readPoint: Int = GLOBAL_WRITE_POINT.deref()
    var inTxValues: Atom<[Ref: AnyHashable]>? = Atom(withValue: [:])
    var writtenRefs: Atom<Set<Ref>>? = Atom(withValue: Set())

    var id: Int
    init() {
        id = TRANSACTION_ID.swap(usingFn: { $0 + 1 })
    }

    public static func doSync(fn: () throws -> Void) {
        Transaction.ensure
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
    var new = map.filter { (k, _) -> Bool in
        k.hashValue != key.hashValue
    }
    new[key] = value
    return new
}

func assoc(_ map: [AnyHashable: AnyHashable],
           key: AnyHashable, value: AnyHashable) -> [AnyHashable: AnyHashable] {
    var new = map.filter { (k, _) -> Bool in
        k.hashValue != key.hashValue
    }
    new[key] = value
    return new
}

func conj(_ set: Set<Ref>, value: Ref) -> Set<Ref> {
    var new = set.filter { (r) -> Bool in
        r.hashValue != value.hashValue
    }

    new.insert(value)
    return new
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

func txRead(tx: inout Transaction, ref: Ref) throws -> AnyHashable? {
    guard let inTxValues = tx.inTxValues else {
        return nil
    }
    if let val = inTxValues.deref()[ref] {
        return val
    }
    if let history = ref.history?.deref(),
        let refEntry = findEntryBeforeOrOn(historyChain: history, readPoint: tx.readPoint) {
        let inTxValue = refEntry.value
        _ = tx.inTxValues?.swap { assoc($0, key: ref, value: inTxValue) }
        return inTxValue
    } else {
        try txRetry()
    }
    assert(false, "Shouldn't really come here \(#function)")
}

func txWrite(tx: inout Transaction, ref: Ref, value: AnyHashable) -> AnyHashable {
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
        print("Transaction succeeded !!")
        _ = GLOBAL_WRITE_POINT.swap(usingFn: { $0 + 1 })
        pthread_mutex_unlock(COMMIT_LOCK)
    }
}

func txRun(tx: Transaction, fn: () throws -> Void) {
    currentTransaction.inner.value = tx
    do {
        try fn()
        try txCommit(tx: currentTransaction.inner.value!)
    } catch STMError.retry {
        txRun(tx: Transaction(), fn: fn)
    } catch {
        assert(false, "Unknown Error in running the transaction : \(error)")
    }
}

// MARK: Run transaction

public func runSTMTransactionsOnMaps() {
    let count = 10
    var counter = Atom(withValue: 0)
    var accounts: [Ref] = []

    let ref1 = Ref(with: ["name": "Rhi-0", "balance": 100] as! [String: AnyHashable])
    let ref2 = Ref(with: ["name": "Rhi-1", "balance": 100] as! [String: AnyHashable])
    let ref3 = Ref(with: ["name": "Rhi-2", "balance": 100] as! [String: AnyHashable])

    accounts.append(ref1)
    accounts.append(ref2)
    accounts.append(ref3)

    for i in 3 ..< count {
        accounts.append(Ref(with: ["name": "Rhi-\(i)", "balance": 0] as! [String: AnyHashable]))
    }

    Thread {
        while true {
            Thread.sleep(forTimeInterval: 0.1)
            Transaction.doSync {
                var sum = 0
                for i in 0 ..< count {
                    let account = try accounts[i].deref() as! [String: AnyHashable]
                    let bal = account["balance"] as! Int
                    if bal > 0 {
                        print("Account \(i) has \(bal)")
                    }
                    sum += bal
                }

                if sum != 300 {
                    assert(false, "This is not working :: \(sum)")
                    return
                } else {
                    print("Sum is correct ! ")
                }
            }
        }
    }.start()

    for _ in 0 ..< 10 {
        Thread {
            for _ in 0 ..< 100 {
                let rankFrom = Int.random(in: 0 ..< count)
                var rankTo = Int.random(in: 0 ..< count)
                if rankTo == rankFrom {
                    rankTo = Int.random(in: 0 ..< count)
                }
                Transaction.doSync {
                    let accountFrom = try accounts[rankFrom].deref() as! [String: AnyHashable]
                    let accountTo = try accounts[rankTo].deref() as! [String: AnyHashable]

                    if accountFrom["balance"] as! Int != 0 {
                        print("Transferring from \(rankFrom) to \(rankTo) : ID \(counter.swap { old in old + 1 })")
                        let balance = accountFrom["balance"] as! Int
                        do {
                            let aFrom = assoc(accountFrom, key: "balance", value: 0)
                            let aTo = assoc(accountTo,
                                            key: "balance",
                                            value: (accountTo["balance"] as! Int) + balance)
                            _ = try accounts[rankFrom].set(value: aFrom)
                            _ = try accounts[rankTo].set(value: aTo)
                        } catch {
                            assert(false, "Error in setting value in transaction \(error)")
                        }
                    }
                }
                Thread.sleep(forTimeInterval: 0.1)
            }
        }.start()
    }

    Thread.sleep(forTimeInterval: 2000)
}

public func runSTMTransactions() {
    let count = 10
    var counter = Atom(withValue: 0)
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
            for _ in 0 ..< 1000 {
                let rankFrom = Int.random(in: 0 ..< count)
                let rankTo = Int.random(in: 0 ..< count)
                Transaction.doSync {
                    let accountFrom = try accounts[rankFrom].deref()?.base as! BankAccount
                    let accountTo = try accounts[rankTo].deref()?.base as! BankAccount

                    if rankFrom != rankTo, accountFrom.balance != 0 {
                        print("Transferring from \(rankFrom) to \(rankTo) : ID \(counter.swap { old in old + 1 })")
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

    // Thread.sleep(forTimeInterval: 20)
    while true {
        Thread.sleep(forTimeInterval: 1)
        Transaction.doSync {
            let sum = try accounts.reduce(0) { acc, el in
                let val = (try el.deref() as! BankAccount).balance
                return acc + val
            }
            if sum != 300 {
                print("This is not working :: \(sum)")
                for acc in accounts {
                    print("Value is \(try acc.deref())")
                }
                return
            }
        }
    }
}
