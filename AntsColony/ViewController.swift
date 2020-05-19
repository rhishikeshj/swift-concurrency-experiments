//
//  ViewController.swift
//  AntsColony
//
//  Created by rhishikesh on 04/04/20.
//  Copyright © 2020 Helpshift. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let config = ["dim": 120,
                      "home-start": 40,
                      "home-size": 10,
                      "scale-factor": 5]
        let world = createWorld(config: config)
        worldView.world = world
        worldView.config = config
        runWorld(world, config: config)
        evaporateWorld(world, config: config)
        _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { _ in
            self.worldView.needsDisplay = true
        })
    }

    @IBOutlet var worldView: AntWorld!

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
}
