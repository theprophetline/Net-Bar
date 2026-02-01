import SwiftUI
import Combine
import LaunchAtLogin
import SystemConfiguration
import NetTrafficStat

class MenuBarState: ObservableObject {
    // LaunchAtLogin handles the storage and state automatically
    // We can expose a binding or just use LaunchAtLogin.isEnabled directly in the view
    // But keeping a published property to sync might be useful if we want to observe changes,
    // though LaunchAtLogin.observable seems better. For now let's just leave it out of here
    // and use LaunchAtLogin directly in the view, OR wrapper it.
    // Let's wrapping it for simplicity in the View code we have.
    
    var autoLaunchEnabled: Bool {
        get { LaunchAtLogin.isEnabled }
        set { LaunchAtLogin.isEnabled = newValue }
    }
    
    @AppStorage("displayMode") var displayMode: DisplayMode = .both
    @AppStorage("showArrows") var showArrows: Bool = true
    @AppStorage("unitType") var unitType: UnitType = .bytes
    @AppStorage("fixedUnit") var fixedUnit: FixedUnit = .auto
    @AppStorage("fontSize") var fontSize: Double = 9.0
    @AppStorage("textSpacing") var textSpacing: Double = 0.0
    @AppStorage("characterSpacing") var characterSpacing: Double = 0.0
    
    @Published var menuText = ""
    
    var currentIcon: NSImage {
        return MenuBarIconGenerator.generateIcon(
            text: menuText,
            font: .monospacedSystemFont(ofSize: fontSize, weight: .semibold),
            spacing: textSpacing,
            kern: characterSpacing
        )
    }
    
    private var timer: Timer?
    private var primaryInterface: String?
    private var netTrafficStat = NetTrafficStatReceiver()
    
    private var uploadSpeed: Double = 0.0
    private var downloadSpeed: Double = 0.0
    private let byteMetrics: [String] = [" B", "KB", "MB", "GB", "TB"]
    private let bitMetrics: [String] = [" b", "Kb", "Mb", "Gb", "Tb"]
    
    private func findPrimaryInterface() -> String? {
        let storeRef = SCDynamicStoreCreate(nil, "FindCurrentInterfaceIpMac" as CFString, nil, nil)
        let global = SCDynamicStoreCopyValue(storeRef, "State:/Network/Global/IPv4" as CFString)
        let primaryInterface = global?.value(forKey: "PrimaryInterface") as? String
        return primaryInterface
    }
    
    private func formatSpeed(_ speed: Double) -> (String, String) {
        // Convert to bits if needed
        let value = unitType == .bits ? speed * 8 : speed
        
        let metrics = unitType == .bits ? bitMetrics : byteMetrics
        var scaledValue = value
        var metricIndex = 0
        
        if fixedUnit == .kb {
            scaledValue = value / 1024.0
            metricIndex = 1
        } else if fixedUnit == .mb {
            scaledValue = value / (1024.0 * 1024.0)
            metricIndex = 2
        } else {
            // Auto
            while scaledValue > 1024.0 && metricIndex < metrics.count - 1 {
                scaledValue /= 1024.0
                metricIndex += 1
            }
        }
        
        return (String(format: "%6.2lf", scaledValue), metrics[metricIndex] + (unitType == .bits ? "ps" : "/s"))
    }
    
    private func startTimer() {
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.primaryInterface = self.findPrimaryInterface()
                if (self.primaryInterface == nil) { return }
                
                if let netTrafficStatMap = self.netTrafficStat.getNetTrafficStatMap() {
                    if let netTrafficStat = netTrafficStatMap.object(forKey: self.primaryInterface!) as? NetTrafficStatOC  {
                        self.downloadSpeed = netTrafficStat.ibytes_per_sec as! Double
                        self.uploadSpeed = netTrafficStat.obytes_per_sec as! Double
                        
                        let (downVal, downUnit) = self.formatSpeed(self.downloadSpeed)
                        let (upVal, upUnit) = self.formatSpeed(self.uploadSpeed)
                        
                        var text = ""
                        
                        if self.displayMode == .both || self.displayMode == .uploadOnly {
                            text += "\(self.showArrows ? "↑ " : "")\(upVal) \(upUnit)\n"
                        }
                        
                        if self.displayMode == .both || self.displayMode == .downloadOnly {
                            text += "\(self.showArrows ? "↓ " : "")\(downVal) \(downUnit)"
                        }
                        
                        self.menuText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        RunLoop.current.add(timer, forMode: .common)
        self.timer = timer
    }
    
    private func stopTimer() {
        self.timer?.invalidate()
        self.timer = nil
    }
    
    init() {
        DispatchQueue.main.async {
            // Ensure valid display mode default
            if self.menuText.isEmpty { self.menuText = "..." }
            self.startTimer()
        }
    }
    
    deinit {
        DispatchQueue.main.async {
            self.stopTimer()
        }
    }
}

