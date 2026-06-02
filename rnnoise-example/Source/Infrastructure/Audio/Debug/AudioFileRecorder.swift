//
//  AudioFileRecorder.swift
//  rnnoise-example
//
//  Created by Patryk Dajos on 9/13/25.
//

import AVFoundation
import OSLog

/// Simple audio file recorder using `AVFoundation` functions.
final class AudioFileRecorder: @unchecked Sendable {
    private let logger = Logger(subsystem: "AudioFileRecorder", category: "Audio")
    private let queue  = DispatchQueue(label: "AudioFileRecorder.Sync", qos: .userInitiated)
    
    private let startedAt           = Date()
    private let dir:                String
    let format:                     AVAudioFormat
    private var audioTracks:        [String:AudioFileRecorderTrack] = [:]
    private var lastSampleTime:     [String:AVAudioFramePosition] = [:]
    private let gapFramesTolerance: UInt32
    
    private enum AudioFileRecorderError: Error {
        case noAccessToDocumentsDirectory
        case conversionFailed
    }
    
    private struct AudioFileRecorderTrack {
        var audioFile:     AVAudioFile?
        let audioFileURL:  URL
    }
    
    init(
        dir:                String,
        tracks:             [String],
        sampleRate:         Double = 48000,
        commonFormat:       AVAudioCommonFormat = .pcmFormatInt16,
        channelCount:       UInt32 = 1,
        gapFramesTolerance: UInt32 = 2048
    ) throws {
        self.dir = dir
        self.gapFramesTolerance = gapFramesTolerance
        
        format = AVAudioFormat(
            settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channelCount,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsNonInterleaved: false,
                AVLinearPCMIsBigEndianKey: false,
            ]
        )!
        
        try queue.sync {
            try initializeFiles(tracks: tracks)
        }
        
        logger.debug("Starting recording to: \(dir)")
    }
    
    @_optimize(speed)
    @inlinable
    func recordAudioBuffer(
        track: String,
        _ buffer: AVAudioPCMBuffer,
        at date: Date = Date(),
        generateSilenceBuffers: Bool = true
    ) throws {
        try queue.sync {
            let timestamp          = self.timestamp(for: date)
            let incomingSampleTime = timestamp.sampleTime
            
            if generateSilenceBuffers, let previousSampleTime = lastSampleTime[track] {
                let gapFrames = incomingSampleTime - previousSampleTime
                
                if gapFrames > gapFramesTolerance {
                    if let silenceBuffer = AVAudioPCMBuffer.silenceBuffer(format: format, frameCount: AVAudioFrameCount(gapFrames)) {
                        try audioTracks[track]?.audioFile?.write(from: silenceBuffer)
                    }
                }
            }
            
            let outputBuffer = format == buffer.format ? buffer : try buffer.convert(to: format)
            try audioTracks[track]?.audioFile?.write(from: outputBuffer)
            
            lastSampleTime[track] = incomingSampleTime + AVAudioFramePosition(outputBuffer.frameLength)
        }
    }
    
    @_optimize(speed)
    private func initializeFiles(tracks: [String]) throws {
        for track in tracks {
            try initializeFile(track: track)
        }
    }
}

extension AudioFileRecorder {
    @_optimize(speed)
    private func initializeFile(track: String) throws {
        let fileName = "\(track).wav"

        guard let documentsDirectory = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first else {
            throw AudioFileRecorderError.noAccessToDocumentsDirectory
        }

        /// Create New subdirectory.
        let directoryURL = documentsDirectory.appendingPathComponent(dir)
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        
        let fileURL = directoryURL.appendingPathComponent(fileName)
        let audioFile = try AVAudioFile(
            forWriting:   fileURL,
            settings:     format.settings,
            commonFormat: format.commonFormat,
            interleaved:  format.isInterleaved
        )
        
        audioTracks[track] = AudioFileRecorderTrack(
            audioFile: audioFile,
            audioFileURL: fileURL
        )
        lastSampleTime[track] = timestamp(for: startedAt).sampleTime
    }
    
    @_optimize(speed)
    private func timestamp(for date: Date = Date()) -> AVAudioTime {
        let elapsedSeconds = date.timeIntervalSince(startedAt)
        let sampleTime     = AVAudioFramePosition(elapsedSeconds * format.sampleRate)
        
        return AVAudioTime(
            sampleTime: sampleTime,
            atRate: format.sampleRate
        )
    }
}

extension AVAudioPCMBuffer {
    private enum ConversionError: Error {
        case unableToCreateConverter
        case unableToCreateBuffer
        case conversionFailed(String)
    }

    /// Simple and fast audio format converter.
    @_optimize(speed)
    func convert(to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
      guard let converter = AVAudioConverter(from: self.format, to: format) else {
        throw ConversionError.unableToCreateConverter
      }
      guard let outputBuffer = AVAudioPCMBuffer(
              pcmFormat: format,
              frameCapacity: self.frameCapacity
            ) else {
        throw ConversionError.unableToCreateBuffer
      }

      do {
        try converter.convert(
          to: outputBuffer,
          from: self
        )
      } catch {
        throw ConversionError.conversionFailed(error.localizedDescription)
      }
      return outputBuffer
    }
    
    /// Generates silent audio frames.
    /// Usually used as placeholders in audio file recording for when microphone tap returns no buffers.
    @_optimize(speed)
    @inlinable
    static func silenceBuffer(format: AVAudioFormat, frameCount: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        guard let silenceBuffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        ) else {
            return nil
        }
        silenceBuffer.frameLength = frameCount
        
        let channelCount = Int(format.channelCount)
        
        if let int16Data = silenceBuffer.int16ChannelData {
            for channel in 0 ..< channelCount {
                memset(
                    int16Data[channel],
                    0,
                    Int(frameCount) * MemoryLayout<Int16>.size
                )
            }
        }
        else if let float32Data = silenceBuffer.floatChannelData {
            for channel in 0 ..< channelCount {
                memset(
                    float32Data[channel],
                    0,
                    Int(frameCount) * MemoryLayout<Float>.size
                )
            }
        }
        
        return silenceBuffer
    }
}
