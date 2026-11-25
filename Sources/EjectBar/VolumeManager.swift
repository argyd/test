import AppKit
import DiskArbitration
import Foundation

struct ExternalVolume: Identifiable {
    let url: URL
    let name: String

    var id: String { url.path }
}

enum VolumePolicy {
    static func shouldManage(isInternal: Bool?, isRemovable: Bool?, isEjectable: Bool?) -> Bool {
        guard isInternal != true else { return false }
        return isRemovable == true || isEjectable == true
    }
}

struct VolumePreferences {
    let automaticEject: Bool
    let remountOnWake: Bool

    init(defaults: UserDefaults = .standard) {
        automaticEject = defaults.object(forKey: "automaticEject") as? Bool ?? true
        remountOnWake = defaults.object(forKey: "remountOnWake") as? Bool ?? true
    }
}

@MainActor
final class VolumeManager: ObservableObject {
    @Published private(set) var volumes: [ExternalVolume] = []
    @Published private(set) var statusMessage: String?
    @Published private(set) var lastError: String?

    private(set) var automaticEject: Bool
    private(set) var remountOnWake: Bool
    private var session: DASession?
    private var disksToRemount: [String: DADisk] = [:]
    private var workspaceObservers: [NSObjectProtocol] = []

    var menuBarSymbol: String {
        volumes.isEmpty ? "externaldrive" : "externaldrive.badge.eject"
    }

    init() {
        let preferences = VolumePreferences()
        automaticEject = preferences.automaticEject
        remountOnWake = preferences.remountOnWake

        session = DASessionCreate(kCFAllocatorDefault)
        if let session {
            DASessionSetDispatchQueue(session, DispatchQueue.main)
        }

        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) {
                [weak self] _ in
                Task { @MainActor in
                    guard let self, self.automaticEject else { return }
                    self.eject(self.volumes, rememberForWake: true)
                }
            }
        )
        workspaceObservers.append(
            center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) {
                [weak self] _ in
                Task { @MainActor in
                    guard let self, self.remountOnWake else { return }
                    self.remountEjectedVolumes()
                }
            }
        )
        refresh()
    }

    deinit {
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    func updatePreferences(automaticEject: Bool, remountOnWake: Bool) {
        self.automaticEject = automaticEject
        self.remountOnWake = remountOnWake
    }

    func refresh() {
        let keys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeIsInternalKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey
        ]
        let mountedURLs = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys),
            options: [.skipHiddenVolumes]
        ) ?? []

        volumes = mountedURLs.compactMap { url in
            guard
                let values = try? url.resourceValues(forKeys: keys),
                VolumePolicy.shouldManage(
                    isInternal: values.volumeIsInternal,
                    isRemovable: values.volumeIsRemovable,
                    isEjectable: values.volumeIsEjectable
                )
            else {
                return nil
            }
            return ExternalVolume(url: url, name: values.volumeName ?? url.lastPathComponent)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func ejectAll() {
        eject(volumes, rememberForWake: false)
    }

    func eject(_ volume: ExternalVolume) {
        eject([volume], rememberForWake: false)
    }

    private func eject(_ selectedVolumes: [ExternalVolume], rememberForWake: Bool) {
        guard let session else {
            showError("Disk Arbitration is unavailable.")
            return
        }

        let disks = selectedVolumes.compactMap {
            DADiskCreateFromVolumePath(kCFAllocatorDefault, session, $0.url as CFURL)
        }
        var seenBSDNames = Set<String>()
        let uniqueDisks = disks.filter { disk in
            guard let name = Self.bsdName(for: disk) else { return false }
            return seenBSDNames.insert(name).inserted
        }
        guard !uniqueDisks.isEmpty else {
            showError("No ejectable external volumes were found.")
            return
        }

        for disk in uniqueDisks {
            guard let name = Self.bsdName(for: disk) else { continue }
            if rememberForWake {
                disksToRemount[name] = disk
            }
            DADiskEject(disk, DADiskEjectOptions(kDADiskEjectOptionDefault), { _, dissenter, context in
                guard let context else { return }
                let operation = Unmanaged<DiskOperation>.fromOpaque(context).takeRetainedValue()
                Task { @MainActor in
                    operation.manager?.finishEject(
                        name: operation.bsdName,
                        status: dissenter.map { DADissenterGetStatus($0) }
                    )
                }
            }, Unmanaged.passRetained(DiskOperation(manager: self, bsdName: name, disk: disk)).toOpaque())
        }
        statusMessage = "Ejecting \(uniqueDisks.count) disk(s)…"
        lastError = nil
    }

    private func remountEjectedVolumes() {
        guard !disksToRemount.isEmpty else { return }

        let pending = disksToRemount
        for (name, disk) in pending {
            DADiskMount(disk, nil, DADiskMountOptions(kDADiskMountOptionDefault), { _, dissenter, context in
                guard let context else { return }
                let operation = Unmanaged<DiskOperation>.fromOpaque(context).takeRetainedValue()
                Task { @MainActor in
                    operation.manager?.finishMount(
                        name: operation.bsdName,
                        status: dissenter.map { DADissenterGetStatus($0) }
                    )
                }
            }, Unmanaged.passRetained(DiskOperation(manager: self, bsdName: name, disk: disk)).toOpaque())
        }
        statusMessage = "Remounting previously ejected disks…"
        lastError = nil
    }

    private func finishEject(name: String, status: Int32?) {
        if let status {
            disksToRemount.removeValue(forKey: name)
            showError("Could not eject \(name) (Disk Arbitration error \(status)). Close files on the volume and try again.")
        } else {
            lastError = nil
            statusMessage = "Ejected \(name)."
            refresh()
        }
    }

    private func finishMount(name: String, status: Int32?) {
        if let status {
            showError("Could not remount \(name) (Disk Arbitration error \(status)). It may be disconnected.")
        } else {
            disksToRemount.removeValue(forKey: name)
            lastError = nil
            statusMessage = "Remounted \(name)."
            refresh()
        }
    }

    private func showError(_ message: String) {
        lastError = message
        statusMessage = message
    }

    private static func bsdName(for disk: DADisk) -> String? {
        guard let name = DADiskGetBSDName(disk) else { return nil }
        return String(cString: name)
    }
}

private final class DiskOperation {
    weak var manager: VolumeManager?
    let bsdName: String
    let disk: DADisk

    init(manager: VolumeManager, bsdName: String, disk: DADisk) {
        self.manager = manager
        self.bsdName = bsdName
        self.disk = disk
    }
}
