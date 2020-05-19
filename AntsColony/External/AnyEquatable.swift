//
//  AnyEquatable.swift
//  AntsColony
//
//  Created by rhishikesh on 11/05/20.
//  Copyright © 2020 Helpshift. All rights reserved.
//  Taken from : https://gist.github.com/JadenGeller/f0d05a4699ddd477a2c1

import Foundation

public struct AnyEquatable {
    private let value: Any
    private let equals: (Any) -> Bool

    public init<T: Equatable>(_ value: T) {
        self.value = value
        equals = { ($0 as? T == value) }
    }
}

extension AnyEquatable: Equatable {
    public static func == (lhs: AnyEquatable, rhs: AnyEquatable) -> Bool {
        return lhs.equals(rhs.value)
    }
}
