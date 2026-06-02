//
//  AudioFormatConverter.swift
//  RNNoiseSwift
//
//  Created by Patryk Dajos on 9/28/25.
//

import AVFoundation
import OSLog

/// Simple audio format converter using `AVFoundation` converters.
internal final class AudioFormatConverter {
    private let logger = Logger(subsystem: "AudioFormatConverter", category: "Audio")
    
    private let sourceAudioFormat: AVAudioFormat
    private let outputAudioFormat: AVAudioFormat
    private let audioConverter:    AVAudioConverter
    private let conversionRatio:   Double
    
    private enum SampleRateConverterError: Error {
        case converterInitializationFailed
        case conversionFailed
    }
    
    required init(
        from sourceAudioFormat: AVAudioFormat,
        to outputAudioFormat:   AVAudioFormat
    ) throws {
        self.sourceAudioFormat = sourceAudioFormat
        self.outputAudioFormat = outputAudioFormat

        guard let converter = AVAudioConverter(from: sourceAudioFormat, to: outputAudioFormat) else {
            throw SampleRateConverterError.converterInitializationFailed
        }
        
        /// Configure for highest quality conversion to minimize artifacts.
        converter.sampleRateConverterQuality = .max
        
        audioConverter  = converter
        conversionRatio = outputAudioFormat.sampleRate / sourceAudioFormat.sampleRate
    }
    
    /// Downsamples or upsamples an `AVAudioPCMBuffer`.
    @_optimize(speed)
    @inlinable
    func process(buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        /// Calculate frame capacity for output buffer with more generous headroom.
        /// The +10 provides buffer for edge cases in sample rate conversion.
        let outputFrameCapacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * conversionRatio)) + 10
        
        /// Output buffer in target format.
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputAudioFormat,
            frameCapacity: outputFrameCapacity
        ) else {
            logger.error("Failed to create output buffer with capacity: \(outputFrameCapacity)")
            return nil
        }
        
        /// Track if input has been consumed to prevent reuse.
        var inputConsumed = false
        
        /// Input block for the converter - critical fix for static noise.
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            /// Only provide input once, then signal no more data.
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            
            inputConsumed = true
            outStatus.pointee = .haveData
            return buffer
        }
        
        /// Perform conversion with error handling.
        var conversionError: NSError?
        let status = audioConverter.convert(
            to: outputBuffer,
            error: &conversionError,
            withInputFrom: inputBlock
        )
        
        /// Handle conversion results properly.
        switch status {
        case .haveData:
            return outputBuffer
        case .inputRanDry:
            /// This is normal - means we've consumed all input.
            return outputBuffer
        case .endOfStream:
            /// Also normal for single buffer conversion.
            return outputBuffer
        default:
            if let error = conversionError {
                logger.error("Audio conversion failed with status: \(status.rawValue), error: \(error.localizedDescription)")
            } else {
                logger.error("Audio conversion failed with status: \(status.rawValue)")
            }
            return nil
        }
    }
}
