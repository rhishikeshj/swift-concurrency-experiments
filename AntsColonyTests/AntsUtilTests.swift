//
//  AntsUtilTests.swift
//  AntsColonyTests
//
//  Created by rhishikesh on 09/05/20.
//  Copyright © 2020 Helpshift. All rights reserved.
//

@testable import AntsColony
import XCTest

class AntsUtilTests: XCTestCase {
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testRankBy() {
        let ints = [1, 2, 3, 4, 50]
        let ranks = rankBy({ (a, b) -> Bool in
            a < b
        }, xs: ints)
        XCTAssert(ranks[1] == 0)
        XCTAssert(ranks[2] == 1)
        XCTAssert(ranks[3] == 2)
        XCTAssert(ranks[4] == 3)
        XCTAssert(ranks[50] == 4)
    }

    func testBound() {
        XCTAssert(bound(by: 5, n: 21) == 1)
        XCTAssert(bound(by: 5, n: -21) == 4)
        XCTAssert(bound(by: 31, n: 121) == 28)
    }

    func testRoulette() {
        for _ in 0 ..< 100 {
            let r = roulette(of: [4, 4, 4, 1, 1, 1])
            XCTAssert(r < 6)
            XCTAssert(r != -1)
        }
    }

    func testJuxt() {
        let transforms = juxt(fns: { (str: String, delims: [String]) -> Any in
            let new: String = str + delims.joined()
            return String(new.reversed())
        }, { (str: String, _: [String]) -> Any in
            str.uppercased()
        }, { (str: String, _: [String]) -> Any in
            str.lowercased()
        }, { (str: String, _: [String]) -> Any in
            str + str
        })

        XCTAssert(transforms("Swift", ["::"]) as! [String] == ["::tfiwS", "SWIFT", "swift", "SwiftSwift"])

        let operations = juxt(fns: { (input: Int, args: [Int]) -> Any in
            input + args.reduce(0) { (r, i) -> Int in
                r + i
            }
        }, { (input: Int, args: [Int]) -> Any in
            input * args.reduce(1) { (r, i) -> Int in
                r * i
            }
        }, { (input: Int, args: [Int]) -> Any in
            input - args.reduce(0) { (r, i) -> Int in
                r + i
            }
        }, { (input: Int, args: [Int]) -> Any in
            input / args.reduce(0) { (r, i) -> Int in
                r + i
            }
        })

        XCTAssert(operations(21000, [1, 3, 5, 7, 9]) as! [Int] == [21025, 19_845_000, 20975, 840])
    }

    func testPartial() {
        let incrementer = partial(fn: { (args: Any...) -> Any in
            (args[0] as! Array).reduce(0) { (acc, a) -> Any in
                (acc as! Int) + a
            }
        }, some: 10, 20, 33)

        print(incrementer(3, 4))

        let prefixer = partial(fn: { (args: Any...) -> Any in
            (args[0] as! Array).reduce("") { (acc, b) -> Any in
                (acc as! String) + b
            }
        }, some: "prefix1", "prefix2")

        print(prefixer("Rhi", "Joshi"))
    }

    func testMergeWith() {
        let m1 = ["a": 1, "b": 2]
        let m2 = ["a": 2, "b": 2]
        let m3 = ["a": 3, "b": 2]
        let m4 = ["a": 4, "b": 2]
        let m5 = ["a": 5, "b": 2]
        let merged = mergeWith(fn: { (a, b) -> Int in
            a + b
        }, maps: m1, m2, m3, m4, m5)
        XCTAssert(merged["a"] == 15 && merged["b"] == 10)

        let d1 = [m1: 1, m2: 3]
        let d2 = [m1: 2, m2: 4]

        let dmerged = mergeWith(fn: { (a, b) -> Int in
            a + b
        }, maps: d1, d2)
        XCTAssert(dmerged[m1] == 3 && dmerged[m2] == 7)
    }

    func testRandomBehavior() {
        let dim = 7
        var world: [[Cell]] = []

        for i in 0 ..< dim {
            world.append([])
            for j in 0 ..< dim {
                if i == 4, j == 3 {
                    world[i].append(Cell(ant: Ant(dir: 0, food: true),
                                         food: 20,
                                         home: true,
                                         pher: 0,
                                         location: [i, j]))
                } else {
                    world[i].append(Cell(ant: .none, food: 20, home: true, pher: 0, location: [i, j]))
                }
            }
        }
        var place = world[4][3]
        randomBehavior(config: ["dim": dim],
                       world: &world,
                       behavior: homing(),
                       place: &place)
    }

    func testBehave() {
        let dim = 20
        let initialAntP1 = 5, initialAntP2 = 8
        var world: [[Cell]] = []

        for i in 0 ..< dim {
            world.append([])
            for j in 0 ..< dim {
                if i < 3, j < 3 {
                    world[i].append(Cell(ant: .none,
                                         food: 0,
                                         home: true,
                                         pher: 0,
                                         location: [i, j]))
                } else if i >= initialAntP1, i < initialAntP2,
                    j >= initialAntP1, j < initialAntP2 {
                    world[i].append(Cell(ant: Ant(dir: 0, food: false),
                                         food: 0,
                                         home: false,
                                         pher: 0,
                                         location: [i, j]))
                } else {
                    world[i].append(Cell(ant: .none, food: 20, home: false, pher: 0, location: [i, j]))
                }
            }
        }

        for i in initialAntP1 ..< initialAntP2 {
            for j in initialAntP1 ..< initialAntP2 {
                Thread {
                    var ant = world[i][j]
                    while true {
                        ant = behave(config: ["dim": dim], world: &world, place: &ant)
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                }.start()
            }
        }

        Thread.sleep(forTimeInterval: 30)
        for i in 0 ..< dim {
            for j in 0 ..< dim {
                print("Place is \(world[i][j])")
            }
        }
    }

    func testCellLocking() {
        let dim = 7
        var world: [[Cell]] = []

        for i in 0 ..< dim {
            world.append([])
            for j in 0 ..< dim {
                world[i].append(Cell(ant: .none, food: 20, home: true, pher: 0, location: [i, j]))
            }
        }

        for _ in 0 ..< 100 {
            Thread {
                for _ in 0 ..< 100 {
                    var cells = world[1]
                    Cell.writeAndExecute(cells: &cells) { (cells: inout [Cell]) in
                        for (i, _) in cells.enumerated() {
                            cells[i].pher += 1
                        }
                    }
                }
            }.start()
        }

        Thread.sleep(forTimeInterval: 0.5)
        Cell.readAndExecute(cells: world[1]) { cells in
            for c in cells {
                print("Cell pher is \(c.pher)")
            }
        }
    }

    func testThreadLocals() {
        let array = ThreadLocal(value: [1, 2, 3])

        Thread {
            // array = ThreadLocal(value: [4, 5, 6])
            array.inner.value = [4, 5, 6]
            var arr = array.inner.value
            arr.append(21)
            print(arr)
        }.start()

        Thread {
            Thread.sleep(forTimeInterval: 1)
            var arr = array.inner.value
            arr.append(42)
            print(arr)
        }.start()

        Thread.sleep(forTimeInterval: 4)
    }
}
