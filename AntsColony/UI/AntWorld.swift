//
//  AntWorld.swift
//  AntsColony
//
//  Created by rhishikesh on 19/05/20.
//  Copyright © 2020 Helpshift. All rights reserved.
//

import AppKit
import Cocoa

class AntWorld: NSView {
    var world: [[Cell]] = []
    var config: [String: Int] = [:]

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawWorld()
    }

    private func drawWorld() {
        NSColor.white.setFill()
        bounds.fill()
        let context = NSGraphicsContext.current?.cgContext
        let scaleFactor = config["scale-factor"]!

        // MARK: Draw the home

        let homeOrigin = config["home-start"]! * scaleFactor
        let homeSize = config["home-size"]! * scaleFactor
        let homeRect = CGRect(origin: CGPoint(x: homeOrigin, y: homeOrigin),
                              size: CGSize(width: homeSize, height: homeSize))
        drawRoundedRect(rect: homeRect,
                        inContext: context,
                        radius: 2,
                        borderColor: NSColor.darkGray.cgColor,
                        fillColor: NSColor.lightGray.cgColor)

        // MARK: Draw the Ants

        let ant = "🐜" as NSString
        let attributes = [NSAttributedString.Key.font: NSFont.systemFont(ofSize: CGFloat(scaleFactor))]

        // MARK: Draw dynamic ants

        for row in world {
            for cell in row {
                if let _ = cell.ant {
                    let antOriginX = cell.location[0] * scaleFactor
                    let antOriginY = cell.location[1] * scaleFactor
                    let antRect = CGRect(origin: CGPoint(x: antOriginX,
                                                         y: antOriginY),
                                         size: CGSize(width: scaleFactor,
                                                      height: scaleFactor))
                    ant.draw(in: antRect, withAttributes: attributes)
                } else if cell.food > 0 {
                    let foodOriginX = cell.location[0] * scaleFactor
                    let foodOriginY = cell.location[1] * scaleFactor
                    let foodRect = CGRect(origin: CGPoint(x: foodOriginX,
                                                          y: foodOriginY),
                                          size: CGSize(width: scaleFactor,
                                                       height: scaleFactor))
                    NSColor(calibratedRed: 0.5, green: 0.3, blue: 0.3, alpha: CGFloat(cell.food) / 20).setFill()
                    foodRect.fill()
                }

                if cell.pher > 0 {
                    let pherOriginX = cell.location[0] * scaleFactor
                    let pherOriginY = cell.location[1] * scaleFactor
                    let pherRect = CGRect(origin: CGPoint(x: pherOriginX,
                                                          y: pherOriginY),
                                          size: CGSize(width: scaleFactor,
                                                       height: scaleFactor))
                    NSColor(calibratedRed: 0.1, green: 0.8, blue: 0.3, alpha: CGFloat(cell.pher) / 40).setFill()
                    pherRect.fill()
                }
            }
        }
    }
}

extension AntWorld {
    func drawRoundedRect(rect: CGRect, inContext context: CGContext?,
                         radius: CGFloat, borderColor: CGColor, fillColor: CGColor) {
        // 1
        let path = CGMutablePath()

        // 2
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
                    tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
                    tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
                    tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY),
                    tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: radius)
        path.closeSubpath()

        // 3
        context?.setLineWidth(1.0)
        context?.setFillColor(fillColor)
        context?.setStrokeColor(borderColor)

        // 4
        context?.addPath(path)
        context?.drawPath(using: .fillStroke)
    }
}
