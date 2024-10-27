//
//  RNNoise.swift
//
//  Created by Patryk Dajos on 22.10.24.
//

import Foundation
import AVFoundation
import CRNNoise
import Accelerate

public class RNNoise {
    public let denoiseState: OpaquePointer
    public let frameSize:    Int

    /// Creates RNNoise instance with default model.
    public init() {
        denoiseState = rnnoise_create(nil)
        frameSize    = Int(rnnoise_get_frame_size())
    }

    deinit {
        rnnoise_destroy(denoiseState)
    }
    
    /// Denoises `AVAudioPCMBuffer` buffer.
    /// - Note: Buffer samples must be PCM format Float32.
    @inlinable
    public func process(_ buffer: AVAudioPCMBuffer) {
        let totalSamples  = Int(buffer.frameLength)
        let numFullFrames = totalSamples / frameSize

        guard let samples = buffer.floatChannelData?.pointee else {
            return
        }

        /// Process each full frame.
        (0..<numFullFrames).forEach { i in
            let frameStart = samples.advanced(by: i * frameSize)
            rnnoise_process_frame(denoiseState, frameStart, frameStart)
        }
    }
    
    /// Denoises buffer pointer.
    /// - Note: Buffer samples must be PCM format Float32.
    @inlinable
    public func processBuffer(_ bufferPointer: UnsafeMutableBufferPointer<Float>) {
        let totalSamples  = bufferPointer.count
        let numFullFrames = totalSamples / frameSize

        guard let samplesPointer = bufferPointer.baseAddress else { return }

        /// Process each full frame.
        (0..<numFullFrames).forEach { i in
            let frameStart = samplesPointer.advanced(by: i * frameSize)
            rnnoise_process_frame(denoiseState, frameStart, frameStart)
        }
    }
}
