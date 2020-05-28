//
//  BankTransaction.swift
//  AntsColony
//
//  Created by rhishikesh on 11/05/20.
//  Copyright © 2020 Helpshift. All rights reserved.
//

import Foundation

public struct BankAccount: Hashable {
    var name: String
    var balance: Int

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(balance)
    }

    public static func deposit(account: BankAccount, amount: Int) -> BankAccount {
        return BankAccount(name: account.name, balance: account.balance + amount)
    }

    public static func withdraw(account: BankAccount, amount: Int) -> BankAccount {
        if account.balance >= amount {
            return BankAccount(name: account.name, balance: account.balance - amount)
        }
        return account
    }
}
