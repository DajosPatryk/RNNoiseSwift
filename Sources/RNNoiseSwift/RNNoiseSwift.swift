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
    public func process(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let totalSamples     = Int(buffer.frameLength)
        let numFullFrames    = totalSamples / frameSize
        let remainingSamples = totalSamples % frameSize

        /// Retrieve input samples.
        guard let inputSamples = buffer.floatChannelData?[0] else {
            return nil
        }

        /// Create an output buffer.
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity) else {
            return nil
        }
        outputBuffer.frameLength = buffer.frameLength

        /// Create output samples container.
        guard let outputSamples = outputBuffer.floatChannelData?[0] else {
            return nil
        }

        /// Process full frames.
        for i in 0..<numFullFrames {
            rnnoise_process_frame(
                denoiseState,
                outputSamples.advanced(by: i * frameSize),
                inputSamples.advanced(by: i * frameSize)
            )
        }

        /// Process the remaining samples by padding with zeros.
        if remainingSamples > 0 {
            var inputFrame      = [Float](repeating: 0, count: frameSize)
            let inputFrameStart = inputSamples.advanced(by: numFullFrames * frameSize)
            
            /// Copy remaining samples into inputFrame.
            let bytesToCopy = remainingSamples * MemoryLayout<Float>.size
            memcpy(&inputFrame, inputFrameStart, bytesToCopy)
            
            var outputFrame = [Float](repeating: 0, count: frameSize)
            rnnoise_process_frame(denoiseState, &outputFrame, inputFrame)
            
            let outputFrameStart = outputSamples.advanced(by: numFullFrames * frameSize)
            
            /// Copy processed samples back to output buffer.
            memcpy(outputFrameStart, &outputFrame, bytesToCopy)
        }

        return outputBuffer
    }
}
