//
//  ContentView.swift
//  rnnoise-example
//
//  Created by Patryk Dajos on 9/4/25.
//

import SwiftUI

struct AppView: View {
    @StateObject private var audioManager = AKAudioManager()
    
    var body: some View {
        VStack {
            Text("RNNoise Example")
            
            Toggle("Denoising", isOn: $audioManager.isDenoisingEnabled)
        }
        .padding()
    }
}
