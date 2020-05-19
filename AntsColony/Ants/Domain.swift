//
//  Domain.swift
//  AntsColony
//
//  Created by rhishikesh on 09/05/20.
//  Copyright © 2020 Helpshift. All rights reserved.
//

import Foundation

public struct Ant: Equatable, Hashable, CustomStringConvertible {
    var dir: Int
    var food: Bool
    // agent:DispatchQueue : do we need one ?

    public static func == (lhs: Ant, rhs: Ant) -> Bool {
        return lhs.dir == rhs.dir &&
            lhs.food == rhs.food
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(dir)
        hasher.combine(food)
    }

    init(dir: Int, food: Bool) {
        self.dir = dir
        self.food = food
    }

    public var description: String { return "Ant:: Dir -> \(dir) Food -> \(food)" }
}

public class Cell: Hashable, CustomStringConvertible {
    static var LOCK_RANK = Atom(withValue: 0)

    var ant: Ant?
    var food: Int = 0
    var home: Bool = false
    var location: [Int] = [0, 0]
    var pher: Int = 0
    var lock = pthread_rwlock_t()
    var lockRank = Cell.LOCK_RANK.swap(usingFn: { $0 + 1 })

    init(ant: Ant?, food: Int, home: Bool, pher: Int, location: [Int]) {
        pthread_rwlock_init(&lock, nil)
        self.ant = ant
        self.food = food
        self.home = home
        self.pher = pher
        self.location = location
    }

    convenience init(from: Cell, with: [String: Any?]) {
        self.init(ant: from.ant,
                  food: from.food,
                  home: from.home,
                  pher: from.pher,
                  location: from.location)

        if let food = with["food"] {
            self.food = food as! Int
        }
        if let home = with["home"] {
            self.home = home as! Bool
        }
        if let pher = with["pher"] {
            self.pher = pher as! Int
        }
        if let ant = with["ant"] {
            self.ant = ant as? Ant
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ant)
        hasher.combine(food)
        hasher.combine(home)
        hasher.combine(pher)
        hasher.combine(location)
    }

    public var description: String { return "Cell:: Ant -> \(ant) Food -> \(food) Home -> \(home) Pher -> \(pher) at location \(location)" }

    public static func == (lhs: Cell, rhs: Cell) -> Bool {
        return lhs.ant == rhs.ant &&
            lhs.food == rhs.food &&
            lhs.home == rhs.home &&
            lhs.location == rhs.location &&
            lhs.pher == rhs.pher
    }

    public func dropFood() {
        food += 1
        ant?.food = false
    }

    public func trail() {
        pher = home ? 0 : pher + 1
    }

    public static func move(from: inout Cell, to: inout Cell) {
        to.ant = from.ant
        from.ant = .none
        from.trail()
    }

    public func takeFood() {
        food -= 1
        ant?.food = true
    }

    public func turn(by: Int) {
        if ant == nil {
            assert(false, "No ant, why behave ? \(self)")
        }
        ant!.dir = bound(by: 8, n: ant!.dir + by)
    }

    public func turnAround() {
        turn(by: 4)
    }

    public static func readAndExecute(cells: [Cell], fn: ([Cell]) -> Void) {
        let sortedCells = cells.sorted { (c1, c2) -> Bool in
            c1.lockRank < c2.lockRank
        }
        for cell in sortedCells {
            let c = cell
            pthread_rwlock_rdlock(&c.lock)
        }
        fn(cells)
        // unlock
        for cell in sortedCells {
            let c = cell
            pthread_rwlock_unlock(&c.lock)
        }
    }

    public static func writeAndExecute(cells: inout [Cell], fn: (inout [Cell]) -> Void) {
        let sortedCells = cells.sorted { (c1, c2) -> Bool in
            c1.lockRank < c2.lockRank
        }
        // lock
        for cell in sortedCells {
            let c = cell
            pthread_rwlock_wrlock(&c.lock)
        }
        fn(&cells)

        // unlock
        for cell in sortedCells {
            let c = cell
            pthread_rwlock_unlock(&c.lock)
        }
    }
}
