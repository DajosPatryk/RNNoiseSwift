//
//  AVExtensions.swift
//  rnnoise-example
//
//  Created by Patryk Dajos on 9/13/25.
//

import AVFoundation

extension AVAudioCommonFormat {
    /// Converts common audio formats to string for debugging.
    func toString() -> String {
        switch self {
        case .pcmFormatFloat32: return "Float32"
        case .pcmFormatFloat64: return "Float64"
        case .pcmFormatInt16: return "Int16"
        case .pcmFormatInt32: return "Int32"
        default: return "Unknown"
        }
    }
}
