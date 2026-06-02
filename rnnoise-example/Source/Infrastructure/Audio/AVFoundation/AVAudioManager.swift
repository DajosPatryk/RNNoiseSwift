//
//  AVAudioManager.swift
//  rnnoise-example
//
//  Created by Patryk Dajos on 9/22/25.
//

import SwiftUI
import AVFoundation
import AudioKit
import OSLog
import RNNoiseSwift

/// Responsible for setting up audio session, audio engine, and creating an audio graph using `AVFoundation`.
final class AVAudioManager: ObservableObject {
    private let logger = Logger(subsystem: "AudioManager", category: "Audio")    /// `OSLog` is more performant than `print`.
    private let engine = AVAudioEngine()
    private let mixer  = AVAudioMixerNode()

    /// Variable to register `RNNoise` onto.
    private var rnNoiseEffect: AVAudioUnitEffect?
    
    /// On/Off toggle for microphone tap.
    @Published var micIsEnabled: Bool = true {
        didSet {
            didSetIsMicOn()
        }
    }
    
    /// On/Off toggle for `RNNoise` denoising.
    @Published var isDenoisingEnabled: Bool = true {
        didSet {
            RNNoiseAudioUnit.isDenoising = isDenoisingEnabled
            logger.info("Denoising \(self.isDenoisingEnabled ? "enabled" : "disabled")")
        }
    }
   
    init() {
        /// Setting up audio session.
        requestMicrophonePermission()
        setAudioSessionPreferences()
        
        /// Registering `RNNoise AUAudioUnit` as `AVAudioUnitEffect`, allocating resources.
        RNNoiseAudioUnit.register()
        rnNoiseEffect = AVAudioUnitEffect(
            audioComponentDescription: RNNoiseAudioUnit.componentDescription
        )
        guard let effect = rnNoiseEffect else {
            logger.error("Failed to register RNNoise effect.")
            return
        }
        
        /// Attach nodes to the engine.
        engine.attach(effect)
        engine.attach(mixer)
        
        /// Get nodes and their formats.
        let inputNode   = engine.inputNode
        let outputNode  = engine.outputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        /// Create mono format for `RNNoise`.
        let monoFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate:   inputFormat.sampleRate,
            channels:     1,
            interleaved:  false
        )!
        
        /// Connect the audio graph: `Input -> RNNoise Effect -> Mixer -> Output`.
        engine.connect(inputNode, to: effect, format: monoFormat)
        engine.connect(effect, to: mixer, format: monoFormat)
        engine.connect(mixer, to: outputNode, format: outputNode.inputFormat(forBus: 0))
        
        // 🛠️ Debug: Log the audio graph connections
        logger.info("Audio graph setup complete:")
        logger.info("Input format: \(inputFormat)")
        logger.info("Mono format: \(monoFormat)")
        logger.info("Effect input format: \(effect.inputFormat(forBus: 0))")
        logger.info("Effect output format: \(effect.outputFormat(forBus: 0))")
        
        /// Starting the audio engine.
        didSetIsMicOn()
    }
    
    private func didSetIsMicOn() {
        if micIsEnabled {
            do {
                try engine.start()
                logger.info("Audio engine started successfully")
            } catch {
                logger.error("Failed to start audio engine: \(error)")
            }
        } else {
            engine.stop()
            logger.info("Audio engine stopped")
        }
    }
    
    private func requestMicrophonePermission() {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined:
            AVAudioApplication.requestRecordPermission { granted in
                if granted {
                    self.logger.info("Microphone permission granted.")
                } else {
                    self.logger.error("Microphone permission denied.")
                }
            }
        case .denied:
            logger.error("Microphone access denied.")
        case .granted:
            logger.info("Microphone access already granted.")
        @unknown default:
            logger.warning("Unknown microphone permission status.")
        }
    }

    private func setAudioSessionPreferences() {
        let session = AVAudioSession.sharedInstance()
        do {
            /// Standard audio session configuration for voice pick-up.
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [
                    .allowBluetoothA2DP,
                    .allowBluetoothHFP,
                    .duckOthers,
                    .allowAirPlay
                ]
            )
            
            /// RNNoise specific configuration optimized for minimal artifacts.
            try session.setPreferredSampleRate(48_000)          /// Prefer recording @ `48kHz`.
            try session.setPreferredInputNumberOfChannels(1)    /// Prefer mono.
            try session.setPreferredIOBufferDuration(0.02)      /// `20ms @ 48kHz = 960` frames.
            
            try session.setActive(true)
            logger.info("Audio session successfully configured and activated.")
        } catch {
            logger.error("AVAudioSession setup error: \(error.localizedDescription)")
        }
    }
}
