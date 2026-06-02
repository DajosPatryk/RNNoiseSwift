//
//  AKRNNoiseNode.swift
//  rnnoise-example
//
//  Created by Patryk Dajos on 9/22/25.
//

import AVFoundation
import AudioKit
import OSLog
import RNNoiseSwift

/// Wraps `RNNoiseAudioUnit` in an AudioKit `Node` so it can be used like any other effect.
class AKRNNoiseNode: Node {
    private let logger = Logger(subsystem: "AKRNNoiseNode", category: "Audio")

    var connections: [AudioKit.Node]
    var avAudioNode: AVAudioNode

    /// Start/stop processing (maps to AU bypass + your static switch)
    var isStarted: Bool = true {
        didSet {
            RNNoiseAudioUnit.isDenoising = isStarted
            logger.debug("RNNoise node \(self.isStarted ? "started" : "stopped")")
        }
    }

    /// Create the RNNoise node, taking an upstream AudioKit Node (e.g., `mic`).
    init(_ input: Node) {
        self.connections = [input]
        
        RNNoiseAudioUnit.register()
        self.avAudioNode = AVAudioUnitEffect(audioComponentDescription: RNNoiseAudioUnit.componentDescription)
    }
}
