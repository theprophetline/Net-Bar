import Foundation
import AppKit

struct ConnectedApp: Identifiable, Hashable {
    let id = UUID()
    let pid: Int32
    let name: String
    let icon: NSImage
}

class ProcessMonitor: ObservableObject {
    @Published var connectedApps: [ConnectedApp] = []
    private var timer: Timer?
    
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        // Run immediately then every 5 seconds
        updateProcesses()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateProcesses()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateProcesses() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            let apps = self?.fetchNetworkProcesses() ?? []
            DispatchQueue.main.async {
                self?.connectedApps = apps
            }
        }
    }
    
    private func fetchNetworkProcesses() -> [ConnectedApp] {
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        // -i: select IPv[46] files
        // -n: no host names
        // -P: no port names
        task.arguments = ["-i", "-n", "-P"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            var seenPids = Set<Int32>()
            var apps: [ConnectedApp] = []
            
            let lines = output.components(separatedBy: "\n")
            // Skip header
            for line in lines.dropFirst() {
                let columns = line.split(separator: " ", omittingEmptySubsequences: true)
                guard columns.count >= 2,
                      let pid = Int32(columns[1]),
                      !seenPids.contains(pid) else { continue }
                
                // Get app info
                if let app = NSRunningApplication(processIdentifier: pid),
                   let name = app.localizedName,
                   let icon = app.icon {
                    
                    seenPids.insert(pid)
                    apps.append(ConnectedApp(pid: pid, name: name, icon: icon))
                }
            }
            
            return apps.sorted { $0.name < $1.name }
            
        } catch {
            print("Error running lsof: \(error)")
            return []
        }
    }
}
