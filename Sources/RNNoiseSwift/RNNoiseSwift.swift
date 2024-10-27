//
//  RNNoise.swift
//
//  Created by Patryk Dajos on 22.10.24.
//

import Foundation
import AVFoundation
import CRNNoise

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
    
    /// Denoises buffer sample.
    /// - Note: Buffer sample must be PCM format Float32.
    @inlinable
    public func process(_ buffer: AVAudioPCMBuffer) {
        let totalSamples     = Int(buffer.frameLength)
        let numFullFrames    = totalSamples / frameSize
        let remainingSamples = totalSamples % frameSize
    
        /// Retrieve samples.
        guard let samples = buffer.floatChannelData?[0] else {
            return
        }
    
        /// Process full frames in-place.
        for i in 0..<numFullFrames {
            let frameStart = samples.advanced(by: i * frameSize)
            rnnoise_process_frame(
                denoiseState,
                frameStart,
                frameStart
            )
        }
    
        /// Process the remaining samples by padding with zeros.
        if remainingSamples > 0 {
            /// Create a temporary input frame initialized with zeros.
            var inputFrame = [Float](repeating: 0, count: frameSize)
    
            /// Calculate the starting point for the remaining samples.
            let remainingStartIndex = numFullFrames * frameSize
            let inputFrameStart = samples.advanced(by: remainingStartIndex)
    
            /// Copy remaining samples into inputFrame.
            let samplesToCopy = remainingSamples
            let bytesToCopy = samplesToCopy * MemoryLayout<Float>.size
            memcpy(&inputFrame, inputFrameStart, bytesToCopy)
    
            rnnoise_process_frame(denoiseState, &inputFrame, inputFrame)
    
            /// Copy processed samples back into the buffer.
            memcpy(inputFrameStart, &inputFrame, bytesToCopy)
        }
    }
    
    @inlinable
    public func processBuffer(_ bufferPointer: UnsafeMutableBufferPointer<Float>) {
        let totalSamples = bufferPointer.count
        let numFullFrames = totalSamples / frameSize
        let remainingSamples = totalSamples % frameSize
    
        guard let samplesPointer = bufferPointer.baseAddress else { return }
    
        for i in 0..<numFullFrames {
            let frameStart = samplesPointer.advanced(by: i * frameSize)
            rnnoise_process_frame(
                denoiseState,
                frameStart,
                frameStart
            )
        }
    
        if remainingSamples > 0 {
            var inputFrame = [Float](repeating: 0, count: frameSize)
            let remainingStartIndex = numFullFrames * frameSize
            let inputFrameStart = samplesPointer.advanced(by: remainingStartIndex)
    
            let bytesToCopy = remainingSamples * MemoryLayout<Float>.size
            memcpy(&inputFrame, inputFrameStart, bytesToCopy)
    
            rnnoise_process_frame(denoiseState, &inputFrame, inputFrame)
    
            memcpy(inputFrameStart, &inputFrame, bytesToCopy)
        }
    }
    
    @inlinable
    public func processFrame(_ frame: UnsafeMutablePointer<Float>) {
        rnnoise_process_frame(denoiseState, frame, frame)
    }
}
