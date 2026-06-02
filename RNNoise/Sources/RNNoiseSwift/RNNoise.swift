//
//  RNNoise.swift
//
//  Created by Patryk Dajos on 22.10.24.
//

import Foundation
import AVFoundation
import CRNNoise
import Accelerate

/// RNNoise wrapper for Swift.
///
/// - note: Object needs to stay initialized for the entire duration of the audio stream.
public class RNNoise: Sendable {
    private let logger = Logger(subsystem: "RNNoise", category: "Audio")
    
    public let denoiseState:  OpaquePointer
    public let frameSize:     Int
    private var inputBuffer:  [Float] = []
    private var outputBuffer: [Float] = []
    
    public init() {
        denoiseState = rnnoise_create(nil)
        frameSize    = Int(rnnoise_get_frame_size())
    }
    
    deinit {
        rnnoise_destroy(denoiseState)
    }
    
    /// Denoises `AVAudioPCMBuffer` buffer.
    ///
    /// Buffer samples must fulfill the following criteria:
    /// - Works best at `48kHz`.
    /// - Common format `PCM format Float32`.
    /// - Not normalized, range `-32768 to 32768`.
    ///
    /// - note: Failing to meet one of these criteria will make `RNNoise` fail to denoise the buffer or create artifacts.
    @_optimize(speed)
    public func process(_ buffer: inout AVAudioPCMBuffer) {
        precondition(buffer.format.commonFormat == .pcmFormatFloat32, "Float32 expected")
        //precondition(buffer.format.sampleRate == 48000, "48kHz expected")
        precondition(buffer.format.channelCount == 1, "Mono expected")
        
        guard let samples = buffer.floatChannelData?[0] else { return }
        let sampleCount   = Int(buffer.frameLength)
        
        /// Add input samples to buffer (scale to RNNoise range).
        for i in 0..<sampleCount {
            inputBuffer.append(samples[i])
        }
        
        /// Process complete frames.
        while inputBuffer.count >= frameSize {
            var frame = Array(inputBuffer.prefix(frameSize))
            inputBuffer.removeFirst(frameSize)
            
            frame.withUnsafeMutableBufferPointer { framePtr in
                rnnoise_process_frame(denoiseState, framePtr.baseAddress!, framePtr.baseAddress!)
            }
            
            /// Add processed samples to output buffer.
            for sample in frame {
                outputBuffer.append(sample)
            }
        }
        
        /// Always return exactly `sampleCount` processed frames. Else exit.
        if outputBuffer.count >= sampleCount {
            /// We have enough processed samples - return them.
            for i in 0..<sampleCount {
                samples[i] = outputBuffer[i]
            }
            outputBuffer.removeFirst(sampleCount)
        }
        
        /// Not enough processed samples yet - return silence.
        else {
            logger.warning("RNNoise output buffer is not primed (\(self.outputBuffer.count) < \(sampleCount)), returning silence.")
            for i in 0..<sampleCount {
                samples[i] = 0.0
            }
        }
    }
    
    /// Denoises `AVAudioPCMBuffer` buffer.
    ///
    /// Buffer samples must fulfill the following criteria:
    /// - Works best at `48kHz`.
    /// - Common format `PCM format Float32`.
    /// - Normalized, range `-1.0 to 1.0`.
    ///
    /// - note: Failing to meet one of these criteria will make `RNNoise` fail to denoise the buffer or create artifacts.
    @_optimize(speed)
    public func processNormalized(_ buffer: inout AVAudioPCMBuffer) {
        precondition(buffer.format.commonFormat == .pcmFormatFloat32, "Float32 expected")
        //precondition(buffer.format.sampleRate == 48000, "48kHz expected")
        precondition(buffer.format.channelCount == 1, "Mono expected")
        
        guard let samples = buffer.floatChannelData?[0] else { return }
        let sampleCount   = Int(buffer.frameLength)
        
        /// Add input samples to buffer (scale to RNNoise range).
        for i in 0..<sampleCount {
            inputBuffer.append(samples[i] * 32768.0)
        }
        
        /// Process complete frames.
        while inputBuffer.count >= frameSize {
            var frame = Array(inputBuffer.prefix(frameSize))
            inputBuffer.removeFirst(frameSize)
            
            frame.withUnsafeMutableBufferPointer { framePtr in
                rnnoise_process_frame(denoiseState, framePtr.baseAddress!, framePtr.baseAddress!)
            }
            
            /// Add processed samples to output buffer.
            for sample in frame {
                outputBuffer.append(sample / 32768.0)
            }
        }
        
        /// Always return exactly `sampleCount` processed frames. Else exit.
        if outputBuffer.count >= sampleCount {
            /// We have enough processed samples - return them.
            for i in 0..<sampleCount {
                samples[i] = outputBuffer[i]
            }
            outputBuffer.removeFirst(sampleCount)
        }
        
        /// Not enough processed samples yet - return silence.
        else {
            logger.warning("RNNoise output buffer is not primed (\(self.outputBuffer.count) < \(sampleCount)), returning silence.")
            for i in 0..<sampleCount {
                samples[i] = 0.0
            }
        }
    }
}
