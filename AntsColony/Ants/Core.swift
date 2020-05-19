//
//  Core.swift
//  AntsColony
//
//  Created by rhishikesh on 19/05/20.
//  Copyright © 2020 Helpshift. All rights reserved.
//

import Foundation

public func createWorld(config: [String: Int]) -> [[Cell]] {
    let dim = config["dim"] ?? 20
    let homeStart = config["home-start"] ?? 0
    let homeEnd = homeStart + (config["home-size"] ?? 3)

    var world: [[Cell]] = []

    for i in 0 ..< dim {
        world.append([])
        for j in 0 ..< dim {
            if i >= homeStart, i < homeEnd,
                j >= homeStart, j < homeEnd {
                world[i].append(Cell(ant: Ant(dir: Int.random(in: 0 ..< 8), food: false),
                                     food: 0,
                                     home: true,
                                     pher: 0,
                                     location: [i, j]))
            } else {
                let isFood = (Int.random(in: 0 ..< 100) % 13) == 0
                if isFood {
                    world[i].append(Cell(ant: .none, food: 20, home: false, pher: 0, location: [i, j]))
                } else {
                    world[i].append(Cell(ant: .none, food: 0, home: false, pher: 0, location: [i, j]))
                }
            }
        }
    }

    return world
}

public func runWorld(_ w: [[Cell]], config: [String: Int]) {
    var world = w
    let initialAntP1 = config["home-start"]!
    let initialAntP2 = initialAntP1 + config["home-size"]!

    for i in initialAntP1 ..< initialAntP2 {
        for j in initialAntP1 ..< initialAntP2 {
            Thread {
                var ant = world[i][j]
                while true {
                    ant = behave(config: config, world: &world, place: &ant)
                    Thread.sleep(forTimeInterval: 0.01)
                }
            }.start()
        }
    }
}

public func evaporateWorld(_ world: [[Cell]], config: [String: Int]) {
    let worldSize = config["dim"]!
    Thread {
        for i in 0 ..< worldSize {
            for j in 0 ..< worldSize {
                let location = world[i][j]
                while true {
                    if location.pher > 0 {
                        location.pher -= 1
                    }
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }
        }
    }.start()
}
