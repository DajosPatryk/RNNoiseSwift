//
//  AudioManager.swift
//  rnnoise-example
//
//  Created by Patryk Dajos on 9/4/25.
//

import SwiftUI
import AVFoundation
import AudioKit
import OSLog

/// Responsible for setting up audio session, audio engine, and creating an audio graph.
final class AKAudioManager: ObservableObject {
    private let logger = Logger(subsystem: "AudioManager", category: "Audio")    /// `OSLog` is more performant than `print`.
    
    private let engine          = AudioEngine()
    private var mic:            AudioEngine.InputNode!
    private let mixer           = Mixer()
    private var denoiserEffect: AKRNNoiseNode!
    
    /// On/Off toggle for microphone tap.
    @Published var micIsEnabled: Bool = true {
        didSet {
            didSetIsMicOn()
        }
    }
    
    /// On/Off toggle for `RNNoise` denoising.
    @Published var isDenoisingEnabled: Bool = true {
        didSet {
            denoiserEffect.isStarted = isDenoisingEnabled
        }
    }
   
    init() {
        /// Setting up audio session.
        requestMicrophonePermission()
        setAudioSessionPreferences()
        
        
        /// Creating AudioKit audio graph: `Microphone -> RNNoise Effect -> Mixer -> Output`.
        mic = engine.input
        denoiserEffect = AKRNNoiseNode(mic)
        mixer.removeAllInputs()
        mixer.addInput(denoiserEffect)
        
        engine.avEngine.attach(denoiserEffect.avAudioNode)
        engine.avEngine.attach(mixer.avAudioNode)
        
        /// Connecting `Microphone` to `AKRNNoiseNode` to `Mixer` with format `pcmFloat32` @ `48kHz`.
        /// - note: This step is required, unsure why just adding input to mixer doesn't work.
        let mono48 = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 1,
            interleaved: false
        )!
        engine.avEngine.connect(mic.avAudioNode, to: denoiserEffect.avAudioNode, format: mono48)
        engine.avEngine.connect(denoiserEffect.avAudioNode, to: mixer.avAudioNode, format: mono48)
        
        engine.output = mixer
        
        /// Starting the effect and audio engine.
        didSetIsMicOn()
    }
    
    private func didSetIsMicOn() {
        if micIsEnabled {
            do {
                try engine.start()
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
