import Foundation
import Combine

class SpeedTestService: ObservableObject {
    static let shared = SpeedTestService()
    
    @Published var isTesting = false
    @Published var downloadSpeed: Double? // Mbps
    @Published var uploadSpeed: Double?   // Mbps
    @Published var responsiveness: String? // Low, Medium, High
    @Published var error: String?
    
    private var process: Process?
    
    func startTest() {
        guard !isTesting else { return }
        
        isTesting = true
        downloadSpeed = nil
        uploadSpeed = nil
        responsiveness = nil
        error = nil
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/networkQuality")
        // -c for computer-readable output (JSON), though it's often easier to parse the standard output for simple use
        // We'll use standard output and parse it as it's more human-readable and standard across versions
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        self.process = process
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
                
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    self.parseOutput(output)
                }
                
                DispatchQueue.main.async {
                    self.isTesting = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = "Failed to start speed test"
                    self.isTesting = false
                }
            }
        }
    }
    
    private func parseOutput(_ output: String) {
        // networkQuality output example:
        // Uplink capacity: 15.42 Mbps
        // Downlink capacity: 245.10 Mbps
        // Responsiveness: High (2450 RPM)
        
        let lines = output.components(separatedBy: .newlines)
        
        var dl: Double?
        var ul: Double?
        var resp: String?
        
        for line in lines {
            if line.contains("Downlink capacity:") {
                dl = extractSpeed(line)
            } else if line.contains("Uplink capacity:") {
                ul = extractSpeed(line)
            } else if line.contains("Responsiveness:") {
                if let range = line.range(of: "Responsiveness: ") {
                    let parts = line[range.upperBound...].components(separatedBy: " ")
                    resp = parts.first
                }
            }
        }
        
        DispatchQueue.main.async {
            self.downloadSpeed = dl
            self.uploadSpeed = ul
            self.responsiveness = resp
            if dl == nil && ul == nil {
                self.error = "Could not parse results"
            }
        }
    }
    
    private func extractSpeed(_ line: String) -> Double? {
        let parts = line.components(separatedBy: CharacterSet.decimalDigits.inverted.union(CharacterSet(charactersIn: "."))).filter { !$0.isEmpty }
        if let first = parts.first, let val = Double(first) {
            return val
        }
        return nil
    }
    
    func cancel() {
        process?.terminate()
        isTesting = false
    }
}
