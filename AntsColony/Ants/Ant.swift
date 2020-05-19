//
//  Ant.swift
//  AntsColony
//
//  Created by rhishikesh on 09/05/20.
//  Copyright © 2020 Helpshift. All rights reserved.
//

import Foundation

public func rankByPher(xs: [Cell]) -> [Cell: Int] {
    return rankBy({ (a: Cell, b: Cell) -> Bool in
        a.pher < b.pher
    }, xs: xs)
}

public func rankByHome(xs: [Cell]) -> [Cell: Int] {
    return rankBy({ (a, b) -> Bool in
        (a.home ? 1 : 0) < (b.home ? 1 : 0)
    }, xs: xs)
}

public func rankByFood(xs: [Cell]) -> [Cell: Int] {
    return rankBy({ (a: Cell, b: Cell) -> Bool in
        a.food < b.food
    }, xs: xs)
}

public func foraging() -> ([Cell]) -> [[Cell: Int]] {
    return { (cells: [Cell]) -> [[Cell: Int]] in
        [rankByFood(xs: cells), rankByPher(xs: cells)]
    }
}

public func homing() -> ([Cell]) -> [[Cell: Int]] {
    return { (cells: [Cell]) -> [[Cell: Int]] in
        [rankByHome(xs: cells), rankByPher(xs: cells)]
    }
}

public func randomBehavior(config: [String: Int],
                           world: inout [[Cell]],
                           behavior: ([Cell]) -> [[Cell: Int]],
                           place: inout Cell) -> Cell {
    let neighbors = nearbyPlaces(config: config,
                                 world: &world,
                                 location: place.location,
                                 direction: place.ant?.dir ?? 0)

    var newCell = place
    // take a read lock and execute
    // this will mean that writers will not be able to update
    // these 3 cells
    var ahead = neighbors[0]
    let aheadLeft = neighbors[1]
    let aheadRight = neighbors[2]

    let nearby = behavior([ahead, aheadLeft, aheadRight])
    let ranks = mergeWith(fn: { (a, b) -> Int in
        a + b
    }, maps: nearby[0], nearby[1])
    let index = roulette(of: [ahead.ant != nil ? 0 : ranks[ahead]!, ranks[aheadLeft]!, ranks[aheadRight]!])
    // take a write lock and update cell at place
    // and / or cell ahead if required
    switch index {
    case 0:
        Cell.move(from: &place, to: &ahead)
        newCell = ahead
    case 1:
        place.turn(by: -1)
    case 2:
        place.turn(by: 1)
    default:
        assert(false, "WHAT ??")
    }
    return newCell
}

public func behave(config: [String: Int],
                   world: inout [[Cell]],
                   place: inout Cell) -> Cell {
    var neighbors = nearbyPlaces(config: config,
                                 world: &world,
                                 location: place.location,
                                 direction: place.ant?.dir ?? 0)
    neighbors.append(place)
    var newCell = place

    Cell.writeAndExecute(cells: &neighbors) { (cells: inout [Cell]) in
        var ahead = cells[0]
        if let food = place.ant?.food, food == true {
            if place.home {
                place.dropFood()
                place.turnAround()
                newCell = place
            } else if ahead.home, ahead.ant == nil {
                Cell.move(from: &place, to: &ahead)
                newCell = ahead
            } else {
                newCell = randomBehavior(config: config,
                                         world: &world,
                                         behavior: homing(),
                                         place: &place)
            }
        } else {
            if place.food > 0, !place.home {
                place.takeFood()
                place.turnAround()
                newCell = place
            } else if ahead.food > 0, !ahead.home, ahead.ant == nil {
                Cell.move(from: &place, to: &ahead)
                newCell = ahead
            } else {
                newCell = randomBehavior(config: config,
                                         world: &world,
                                         behavior: foraging(),
                                         place: &place)
            }
        }
    }
    return newCell
}
