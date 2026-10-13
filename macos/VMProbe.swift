// Milestone 1 experimental viewer. No isolation-success or authorization claims.
// Build and acceptance testing on Apple Silicon are still required.
import AppKit
import Virtualization
import Darwin

final class Probe: NSObject, NSApplicationDelegate, VZVirtualMachineDelegate, NSWindowDelegate {
    var window: NSWindow!
    var machine: VZVirtualMachine!
    var log: FileHandle!
    var lockFD: Int32 = -1
    var activity: NSObjectProtocol?
    var observers: [NSObjectProtocol] = []
    var stopping = false
    var stopped = false
    var reportDirectory: URL?
    let managedState = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Focus Isolation Probe", isDirectory: true)

    func installMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let actions = NSMenu()
        appItem.submenu = actions
        for (title, selector, shortcut) in [
            ("Start Installed Guest", #selector(startInstalled), ""),
            ("Install from ARM64 ISO…", #selector(installGuest), ""),
            ("Show Host Reports", #selector(showReports), ""),
            ("Show Test Instructions", #selector(showInstructions), ""),
            ("Quit Focus Isolation Probe", #selector(quit), "q")
        ] {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: shortcut)
            item.target = self
            actions.addItem(item)
        }
        NSApp.mainMenu = menu
    }

    @objc func quit() { NSApp.terminate(nil) }
    @objc func showReports() {
        NSWorkspace.shared.open(reportDirectory ?? managedState)
    }
    @objc func showInstructions() {
        if let url = Bundle.main.url(forResource: "MAC-TEST", withExtension: "md") {
            NSWorkspace.shared.open(url)
        }
    }
    func canStart() -> Bool {
        if machine != nil {
            let alert = NSAlert()
            alert.messageText = "One guest per app launch"
            alert.informativeText = "Shut down the guest and quit, then reopen the app to start another session."
            alert.runModal()
            return false
        }
        return true
    }
    @objc func startInstalled() {
        guard canStart() else { return }
        let disk = managedState.appendingPathComponent("linux.raw")
        guard FileManager.default.fileExists(atPath: disk.path) else {
            installGuest()
            return
        }
        begin([CommandLine.arguments[0], managedState.path, disk.path], managedDisk: true)
    }
    @objc func installGuest() {
        guard canStart() else { return }
        let chooser = NSOpenPanel()
        chooser.title = "Choose an ARM64 Linux installer ISO"
        chooser.message = "The guest runs locally. Use an ARM64/aarch64 Linux image from its official publisher."
        chooser.allowedFileTypes = ["iso"]
        chooser.canChooseDirectories = false
        chooser.allowsMultipleSelection = false
        guard chooser.runModal() == .OK, let iso = chooser.url else { return }
        begin([CommandLine.arguments[0], managedState.path,
               managedState.appendingPathComponent("linux.raw").path, iso.path], managedDisk: true)
    }

    func record(_ type: String) {
        let item: [String: Any] = ["type": type,
            "wallMs": Date().timeIntervalSince1970 * 1000,
            "uptimeMs": ProcessInfo.processInfo.systemUptime * 1000]
        do {
            var data = try JSONSerialization.data(withJSONObject: item, options: [.sortedKeys])
            data.append(0x0A)
            try log.write(contentsOf: data)
            try log.synchronize()
        } catch {
            window?.title = "RECORDING FAILED — acceptance run invalid"
            NSLog("Host observation log failed: %@", error.localizedDescription)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMenu()
        if CommandLine.arguments.count > 1 {
            begin(CommandLine.arguments)
            return
        }
        let alert = NSAlert()
        alert.messageText = "Focus Isolation Probe"
        alert.informativeText = "Experimental local Linux VM viewer. Focus isolation is unverified until the diagnostic passes. The first run needs an ARM64 Linux installer and guest Chromium."
        if FileManager.default.fileExists(atPath: managedState.appendingPathComponent("linux.raw").path) {
            alert.addButton(withTitle: "Start Guest")
            alert.addButton(withTitle: "Attach Installer")
            alert.addButton(withTitle: "Cancel")
            let answer = alert.runModal()
            if answer == .alertFirstButtonReturn { startInstalled() }
            else if answer == .alertSecondButtonReturn { installGuest() }
        } else {
            alert.addButton(withTitle: "Choose Installer")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn { installGuest() }
        }
    }

    func begin(_ args: [String], managedDisk: Bool = false) {
        do {
            // Explicit paths: dedicated VM state directory, raw disk, optional installer ISO.
            guard args.count == 3 || args.count == 4 else {
                throw NSError(domain: "Probe", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Usage: VMProbe STATE_DIRECTORY RAW_DISK [ARM64_INSTALLER_ISO]"])
            }
            let state = URL(fileURLWithPath: args[1], isDirectory: true)
            try FileManager.default.createDirectory(at: state, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            if lockFD < 0 {
                lockFD = open(state.appendingPathComponent("session.lock").path, O_CREAT | O_RDWR, 0o600)
            }
            guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
                throw NSError(domain: "Probe", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Another probe owns this VM state directory."])
            }
            reportDirectory = state
            if managedDisk && !FileManager.default.fileExists(atPath: args[2]) {
                let diskFD = open(args[2], O_CREAT | O_EXCL | O_RDWR, 0o600)
                guard diskFD >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
                let resized = ftruncate(diskFD, 24 * 1024 * 1024 * 1024)
                let resizeError = errno
                close(diskFD)
                guard resized == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(resizeError)) }
            }
            let reportURL = state.appendingPathComponent("host-\(UUID().uuidString).jsonl")
            guard FileManager.default.createFile(atPath: reportURL.path, contents: nil,
                attributes: [.posixPermissions: 0o600]) else {
                throw NSError(domain: "Probe", code: 3)
            }
            log = try FileHandle(forWritingTo: reportURL)
            let config = VZVirtualMachineConfiguration()
            config.cpuCount = 4
            config.memorySize = 4 * 1024 * 1024 * 1024
            let platform = VZGenericPlatformConfiguration()
            let identifierURL = state.appendingPathComponent("machine-id")
            if FileManager.default.fileExists(atPath: identifierURL.path) {
                guard let identifier = VZGenericMachineIdentifier(dataRepresentation: try Data(contentsOf: identifierURL)) else {
                    throw NSError(domain: "Probe", code: 4)
                }
                platform.machineIdentifier = identifier
            } else {
                let identifier = VZGenericMachineIdentifier()
                try identifier.dataRepresentation.write(to: identifierURL, options: .atomic)
                platform.machineIdentifier = identifier
            }
            config.platform = platform
            let boot = VZEFIBootLoader()
            let variables = state.appendingPathComponent("efi-vars")
            if FileManager.default.fileExists(atPath: variables.path) {
                boot.variableStore = VZEFIVariableStore(url: variables)
            } else {
                boot.variableStore = try VZEFIVariableStore(creatingVariableStoreAt: variables)
            }
            config.bootLoader = boot
            let disk = VZVirtioBlockDeviceConfiguration(attachment:
                try VZDiskImageStorageDeviceAttachment(url: URL(fileURLWithPath: args[2]), readOnly: false))
            config.storageDevices = [disk]
            if args.count == 4 {
                config.storageDevices.append(VZUSBMassStorageDeviceConfiguration(attachment:
                    try VZDiskImageStorageDeviceAttachment(url: URL(fileURLWithPath: args[3]), readOnly: true)))
            }
            // Read-only test media contains only the bundled observer, never host files.
            if let testISO = Bundle.main.url(forResource: "FocusTests", withExtension: "iso") {
                config.storageDevices.append(VZUSBMassStorageDeviceConfiguration(attachment:
                    try VZDiskImageStorageDeviceAttachment(url: testISO, readOnly: true)))
            }
            let graphics = VZVirtioGraphicsDeviceConfiguration()
            graphics.scanouts = [VZVirtioGraphicsScanoutConfiguration(widthInPixels: 1280, heightInPixels: 800)]
            config.graphicsDevices = [graphics]
            config.keyboards = [VZUSBKeyboardConfiguration()]
            config.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
            let network = VZVirtioNetworkDeviceConfiguration()
            network.attachment = VZNATNetworkDeviceAttachment()
            config.networkDevices = [network]
            config.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]
            // Intentionally no host filesystem shares, clipboard bridge, or guest management socket.
            try config.validate()
            machine = VZVirtualMachine(configuration: config)
            machine.delegate = self
            let viewer = VZVirtualMachineView(frame: NSRect(x: 0, y: 0, width: 1280, height: 800))
            viewer.virtualMachine = machine
            viewer.capturesSystemKeys = false // Preserve host Cmd-Tab for real switching.
            window = NSWindow(contentRect: viewer.frame,
                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "VM focus probe — UNVERIFIED — not a licensed product"
            window.contentView = viewer
            window.delegate = self
            window.isReleasedWhenClosed = false
            window.center()
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(viewer)
            for (name, type) in [(NSApplication.didResignActiveNotification, "host-inactive"),
                                 (NSApplication.didBecomeActiveNotification, "host-active")] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: NSApp, queue: .main) {
                    [weak self] _ in self?.record(type)
                })
            }
            for (name, type) in [(NSWorkspace.willSleepNotification, "host-sleep"),
                                 (NSWorkspace.didWakeNotification, "host-wake")] {
                observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) {
                    [weak self] _ in self?.record(type)
                })
            }
            // Request normal active scheduling, without manufacturing page activity.
            activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled],
                reason: "Measure VM behavior during host application switching")
            record("probe-start")
            print("Host observations: \(reportURL.path)")
            NSApp.activate(ignoringOtherApps: true)
            machine.start { [weak self] result in
                switch result {
                case .success: self?.record("vm-running")
                case .failure(let error): self?.record("vm-start-failed"); self?.show(error)
                }
            }
        } catch { show(error) }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.terminate(nil)
        return false
    }

    func show(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Probe unavailable — isolation unverified"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard machine != nil, !stopped, machine.state == .running else { return .terminateNow }
        if stopping { return .terminateCancel }
        do {
            try machine.requestStop()
            stopping = true
            record("shutdown-requested")
            return .terminateLater
        } catch { show(error); return .terminateCancel }
    }
    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        stopped = true;record("vm-stopped")
        window?.title = "VM stopped — isolation unavailable"
        if stopping { NSApp.reply(toApplicationShouldTerminate: true) }
    }
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        stopped = true;record("vm-failed")
        window?.title = "VM failed — isolation unavailable"
        if stopping { NSApp.reply(toApplicationShouldTerminate: true) } else { show(error) }
    }
    func applicationWillTerminate(_ notification: Notification) {
        if log != nil { record("probe-stop");try? log.close() }
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        if lockFD >= 0 { close(lockFD) }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = Probe()
app.delegate = delegate
app.run()
