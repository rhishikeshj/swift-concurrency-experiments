//
//  DispatchQueue+Utils.swift
//  AntsColony
//
//  Created by rhishikesh on 24/04/20.
//  Copyright © 2020 Helpshift. All rights reserved.
//

import Foundation

public extension DispatchQueue {
    private static var onceTokens = [Int]()
    private static var internalQueue = DispatchQueue(label: "dispatchqueue.once")

    class func once(token: Int, closure: () -> Void) {
        internalQueue.sync {
            if onceTokens.contains(token) {
                return
            } else {
                onceTokens.append(token)
            }
            closure()
        }
    }
}
