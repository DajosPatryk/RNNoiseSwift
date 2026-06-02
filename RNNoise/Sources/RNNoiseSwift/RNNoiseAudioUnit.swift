//
//  RNNoiseAudioUnit.swift
//  RNNoiseSwift
//
//  Created by Patryk Dajos on 9/28/25.
//

import AVFoundation
import OSLog

/// RNNoise wrapped in a `AUAudioUnit`, capable of being used as `AVAudioUnitEffect` within an `AVAudioEngine` audio graph.
public class RNNoiseAudioUnit: AUAudioUnit {
    private let logger = Logger(subsystem: "RNNoiseAudioUnit", category: "Audio")
    
    private let denoiser                     = RNNoise()
    private var tempBuffer:                  AVAudioPCMBuffer?
    private var processingBuffer:            AVAudioPCMBuffer?
    private var inputBusArray:               AUAudioUnitBusArray!
    private var outputBusArray:              AUAudioUnitBusArray!
    private var inputToProcessingConverter:  AudioFormatConverter?   /// Format converters, this is because `RNNoise` requires mono common format `pcmFloat32` and works best at `48kHz`.
    private var processingToOutputConverter: AudioFormatConverter?
    private var processingFormat             = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 1, interleaved: false)!
    private var needsConversion              = false
    public static var isDenoising            = true
    
    // 🛠️ DEBUG: Recording to file
    //private var fileRecorder: AudioFileRecorder?
    
    public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)
        
        /// Set up the default format.
        let defaultFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        
        /// Create input and output buses.
        let inputBus   = try AUAudioUnitBus(format: defaultFormat)
        let outputBus  = try AUAudioUnitBus(format: defaultFormat)
        inputBusArray  = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [inputBus])
        outputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [outputBus])
        
        /// Create temp buffer for processing and set the maximum frames to render.
        tempBuffer = AVAudioPCMBuffer(pcmFormat: defaultFormat, frameCapacity: UInt32(denoiser.frameSize) * 10)
        maximumFramesToRender = UInt32(denoiser.frameSize) * 10
    }
    
    // MARK: - AUAudioUnit Overrides
    
    public override var inputBusses: AUAudioUnitBusArray {
        return inputBusArray
    }
    
    public override var outputBusses: AUAudioUnitBusArray {
        return outputBusArray
    }
    
    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        
        let inputFormat = inputBusses[0].format
        tempBuffer      = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: maximumFramesToRender)
        
        /// After limited testing, it seems like `RNNoise` works with any sample rate, therefore conversion is unnecessary.
        processingFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: inputFormat.sampleRate, channels: 1, interleaved: false)!
        
        /// Check if we need format conversion.
        let inputSampleRate      = inputFormat.sampleRate
        let processingSampleRate = processingFormat.sampleRate
        let inputChannels        = inputFormat.channelCount
        let processingChannels   = processingFormat.channelCount
        needsConversion          =
            //(inputSampleRate != processingSampleRate) ||
            (inputChannels != processingChannels) ||
            (inputFormat.commonFormat != processingFormat.commonFormat)
        
        if needsConversion {
            /// Create converters using `SampleRateConverter`.
            do {
                inputToProcessingConverter  = try AudioFormatConverter(from: inputFormat, to: processingFormat)
                processingToOutputConverter = try AudioFormatConverter(from: processingFormat, to: inputFormat)
            } catch {
                throw NSError(
                    domain: "RNNoiseAudioUnit",
                    code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Failed to create sample rate converters: \(error.localizedDescription)"
                    ]
                )
            }
        }
        
        // 🛠️ DEBUG: Initialize audio file recorder
        /*fileRecorder = try? AudioFileRecorder(
            dir:          "rnnoise-example_\(Date().timeIntervalSince1970)",
            tracks:       ["main"],
            sampleRate:   inputFormat.sampleRate,
            commonFormat: inputFormat.commonFormat,
            channelCount: inputFormat.channelCount,
        )*/
    }
    
    public override func deallocateRenderResources() {
        super.deallocateRenderResources()
        tempBuffer                  = nil
        processingBuffer            = nil
        inputToProcessingConverter  = nil
        processingToOutputConverter = nil
        needsConversion             = false
    }
    
    public override var canProcessInPlace: Bool {
        return true
    }
    
    /// Intercepts audio buffers and de-noises.
    ///
    /// 1.) Converts any input format to processing format.
    /// 2.) De-noises.
    /// 3.) Converts back to input format and updates output.
    public override var internalRenderBlock: AUInternalRenderBlock {
        return { [weak self] (actionFlags, timestamp, frameCount, outputBusNumber, outputData, realtimeEventListHead, pullInputBlock) -> OSStatus in
            guard let self = self,
                  let pullInputBlock = pullInputBlock,
                  let tempBuffer = self.tempBuffer else {
                return kAudioUnitErr_NoConnection
            }

            /// Pull input.
            let pullFlags = UnsafeMutablePointer<AudioUnitRenderActionFlags>.allocate(capacity: 1)
            defer { pullFlags.deallocate() }
            let err = pullInputBlock(pullFlags, timestamp, frameCount, 0, outputData)
            if err != noErr { return err }

            /// Get the output buffer pointer for writing results.
            let buffer = UnsafeMutableAudioBufferListPointer(outputData)
            guard let audioBuffer = buffer.first,
                  let outputFloatData = audioBuffer.mData?.bindMemory(to: Float.self, capacity: Int(frameCount)) else {
                return noErr
            }

            /// Copy input audio into `tempBuffer`.
            tempBuffer.frameLength = frameCount
            if let tempChannel = tempBuffer.floatChannelData?[0] {
                tempChannel.update(from: outputFloatData, count: Int(frameCount))
            }

            // 🛠️ DEBUG: If denoising is disabled, record to file and exit.
            guard RNNoiseAudioUnit.isDenoising else {
                /*do {
                    try self.fileRecorder?.recordAudioBuffer(
                        track: "main",
                        tempBuffer,
                        generateSilenceBuffers: false
                    )
                } catch {
                    self.logger.error("Recorder error: \(error)")
                }*/
                return noErr
            }

            /// Choose working buffer and track final processed buffer.
            var workingBuffer:        AVAudioPCMBuffer = tempBuffer
            var finalProcessedBuffer: AVAudioPCMBuffer = tempBuffer

            /// ➡️ Convert to processing format if needed.
            if self.needsConversion,
               let inputConv = self.inputToProcessingConverter,
               let converted = inputConv.process(buffer: tempBuffer) {
                workingBuffer = converted
            }
            
            /// 🔇 Process with `RNNoise`.
            self.denoiser.processNormalized(&workingBuffer)
            finalProcessedBuffer = workingBuffer

            /// ⬅️ Convert back to output format if needed.
            if self.needsConversion,
               let outputConv = self.processingToOutputConverter,
               let converted = outputConv.process(buffer: workingBuffer) {
                finalProcessedBuffer = converted
            }

            /// Copy final processed samples back to `outputData`.
            if let processedData = finalProcessedBuffer.floatChannelData?[0] {
                let samplesToCopy = Int(min(frameCount, finalProcessedBuffer.frameLength))
                outputFloatData.update(from: processedData, count: samplesToCopy)
                
                /// Zero any remaining samples if processed buffer is shorter.
                if samplesToCopy < Int(frameCount) {
                    outputFloatData.advanced(by: samplesToCopy).initialize(repeating: 0.0, count: Int(frameCount) - samplesToCopy)
                }
            }

            // 🛠️ DEBUG: Record the final processed buffer
            /*do {
                try self.fileRecorder?.recordAudioBuffer(
                    track: "main",
                    finalProcessedBuffer,
                    generateSilenceBuffers: false
                )
            } catch {
                self.logger.error("Recorder error: \(error)")
            }*/

            return noErr
        }
    }
}

extension RNNoiseAudioUnit {
    public static var componentDescription = AudioComponentDescription(
        componentType:         kAudioUnitType_Effect,
        componentSubType:      0x726e6e73,                               /// Hexadecimal: `rnns`
        componentManufacturer: 0x64656d6f,                               /// Hexadecimal: `demo`
        componentFlags:        AudioComponentFlags.sandboxSafe.rawValue,
        componentFlagsMask:    0
    )
    
    public static func register() {
        AUAudioUnit.registerSubclass(
            RNNoiseAudioUnit.self,
            as: componentDescription,
            name: "RNNoise Effect",
            version: 1
        )
    }
}
