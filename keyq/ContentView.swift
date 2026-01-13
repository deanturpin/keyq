//
//  ContentView.swift
//  keyq
//
//  Created by Dean Turpin on 12/01/2026.
//

import AudioToolbox
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    let hostModel: AudioUnitHostModel
    @State private var isSheetPresented = false
    @State private var isFilePickerPresented = false
    @State private var currentFileName = "default_audio.wav"

    var margin = 10.0
    var doubleMargin: Double {
        margin * 2.0
    }

    var body: some View {
        VStack(spacing: 16) {
            if let viewController = hostModel.viewModel.viewController {
                AUViewControllerUI(viewController: viewController)
                    .padding(.top, 8)
            }

            // Audio playback controls for standalone app
            if hostModel.viewModel.showAudioControls {
                HStack(spacing: 12) {
                    Button {
                        isFilePickerPresented = true
                    } label: {
                        Label("Open", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        hostModel.isPlaying ? hostModel.stopPlaying() : hostModel.startPlaying()
                    } label: {
                        Text(hostModel.isPlaying ? "Pause" : "Play")
                            .frame(width: 60)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Text(currentFileName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
            }
        }
        .fileImporter(
            isPresented: $isFilePickerPresented,
            allowedContentTypes: [.audio, .wav, .mp3, .aiff, .mpeg4Audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }

                // Start accessing security-scoped resource
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    currentFileName = url.lastPathComponent
                    hostModel.loadAudioFile(url)
                    // Auto-play when file is loaded
                    if !hostModel.isPlaying {
                        hostModel.startPlaying()
                    }
                } else {
                    print("Could not access file: \(url)")
                }
            case .failure(let error):
                print("File picker error: \(error)")
            }
        }
    }
}

#Preview {
    ContentView(hostModel: AudioUnitHostModel())
}
