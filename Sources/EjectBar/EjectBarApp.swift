import AppKit
import SwiftUI

@main
struct EjectBarApp: App {
    @StateObject private var volumeManager = VolumeManager()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("EjectBar", systemImage: volumeManager.menuBarSymbol) {
            MenuBarView(volumeManager: volumeManager)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(volumeManager: volumeManager)
        }
    }
}

private struct MenuBarView: View {
    @ObservedObject var volumeManager: VolumeManager
    @AppStorage("automaticEject") private var automaticEject = true
    @AppStorage("remountOnWake") private var remountOnWake = true

    var body: some View {
        Group {
            if volumeManager.volumes.isEmpty {
                Text("No external volumes mounted")
            } else {
                ForEach(volumeManager.volumes) { volume in
                    Button("Eject \(volume.name)") {
                        volumeManager.eject(volume)
                    }
                }

                Divider()
                Button("Eject All External Volumes") {
                    volumeManager.ejectAll()
                }
            }

            if let message = volumeManager.statusMessage {
                Text(message)
                    .foregroundStyle(volumeManager.lastError == nil ? Color.secondary : Color.red)
            }

            Divider()
            Toggle("Eject before sleep", isOn: $automaticEject)
            Toggle("Remount after wake", isOn: $remountOnWake)
            Button("Settings…") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            Button("Refresh Volumes") {
                volumeManager.refresh()
            }
            Divider()
            Button("Quit EjectBar") {
                NSApp.terminate(nil)
            }
        }
        .onChange(of: automaticEject) { _ in
            volumeManager.updatePreferences(
                automaticEject: automaticEject,
                remountOnWake: remountOnWake
            )
        }
        .onChange(of: remountOnWake) { _ in
            volumeManager.updatePreferences(
                automaticEject: automaticEject,
                remountOnWake: remountOnWake
            )
        }
        .onAppear {
            volumeManager.updatePreferences(
                automaticEject: automaticEject,
                remountOnWake: remountOnWake
            )
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var volumeManager: VolumeManager
    @AppStorage("automaticEject") private var automaticEject = true
    @AppStorage("remountOnWake") private var remountOnWake = true

    var body: some View {
        Form {
            Toggle("Eject external volumes before sleep", isOn: $automaticEject)
            Toggle("Remount ejected volumes after wake", isOn: $remountOnWake)

            Text("Ejecting is best-effort while macOS is entering sleep. Volumes must remain connected to be remounted.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 380)
        .onChange(of: automaticEject) { _ in
            volumeManager.updatePreferences(
                automaticEject: automaticEject,
                remountOnWake: remountOnWake
            )
        }
        .onChange(of: remountOnWake) { _ in
            volumeManager.updatePreferences(
                automaticEject: automaticEject,
                remountOnWake: remountOnWake
            )
        }
        .onAppear {
            volumeManager.updatePreferences(
                automaticEject: automaticEject,
                remountOnWake: remountOnWake
            )
        }
    }
}
