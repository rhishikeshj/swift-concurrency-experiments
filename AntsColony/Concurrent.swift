//
//  Concurrent.swift
//  AntsColony
//
//  Created by rhishikesh on 04/04/20.
//  Copyright © 2020 Helpshift. All rights reserved.
//

import Concurrent
import Foundation

typealias Account = TVar<UInt>

enum TransactionError: Error {
    case insufficientFunds
}

func demoTransactions() {
    /// Some atomic operations
    func withdraw(from account: Account, amount: UInt) -> STM<Void> {
        return account.read().flatMap { balance in
            if balance > amount {
                return account.write(balance - amount)
            }
            throw TransactionError.insufficientFunds
        }
    }

    func deposit(into account: Account, amount: UInt) -> STM<Void> {
        return account.read().flatMap { balance in
            account.write(balance + amount)
        }
    }

    func transfer(from: Account, to: Account, amount: UInt) -> STM<Void> {
        return from.read().flatMap { fromBalance in
            if fromBalance > amount {
                return withdraw(from: from, amount: amount)
                    .then(deposit(into: to, amount: amount))
            }
            throw TransactionError.insufficientFunds
        }
    }

    /// Here are some bank accounts represented as TVars - transactional memory
    /// variables.
    let alice = Account(200)
    let bob = Account(100)

    /// All account activity that will be applied in one contiguous transaction.
    /// Either all of the effects of this transaction apply to the accounts or
    /// everything is completely rolled back and it was as if nothing ever happened.
    for _ in 1 ... 3 {
        Thread {
            _ =
                transfer(from: alice, to: bob, amount: 100)
                .then(transfer(from: bob, to: alice, amount: 20))
                .then(deposit(into: bob, amount: 1000))
                .then(transfer(from: bob, to: alice, amount: 500))
                .atomically()
        }.start()
    }
}
