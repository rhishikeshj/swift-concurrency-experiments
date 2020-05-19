//
//  World.swift
//  AntsColony
//
//  Created by rhishikesh on 09/05/20.
//  Copyright © 2020 Helpshift. All rights reserved.
//

import Foundation

var directionDelta: [Int: (Int, Int)] = [
    0: (0, -1),
    1: (1, -1),
    2: (1, 0),
    3: (1, 1),
    4: (0, 1),
    5: (-1, 1),
    6: (-1, 0),
    7: (-1, -1),
]

public func deltaLocation(config: [String: Int], location: [Int], direction: Int) -> (Int, Int) {
    let t = directionDelta[bound(by: 8, n: direction)]!
    let l = (location[0] + t.0, location[1] + t.1)
    return (bound(by: config["dim"]!, n: l.0),
            bound(by: config["dim"]!, n: l.1))
}

public func nearbyPlaces(config: [String: Int],
                         world: inout [[Cell]],
                         location: [Int],
                         direction: Int) -> [Cell] {
    let t = (direction, direction - 1, direction + 1)
    let l = (deltaLocation(config: config, location: location, direction: t.0),
             deltaLocation(config: config, location: location, direction: t.1),
             deltaLocation(config: config, location: location, direction: t.2))
    let places = [world[l.0.0][l.0.1], world[l.1.0][l.1.1], world[l.2.0][l.2.1]]
    return places
}
