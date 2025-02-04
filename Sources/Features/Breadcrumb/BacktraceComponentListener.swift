import Foundation

@objc class BacktraceComponentListener: NSObject {

    override init() {
        super.init()
        observeOrientationChange()
        observeMemoryStatusChanged()
        observeBatteryStatusChanged()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        self.source?.cancel()
    }

    // MARK: - Orientation Status Listener

    private func observeOrientationChange() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(notifyOrientationChange),
                                               name: UIDevice.orientationDidChangeNotification,
                                               object: nil)
    }

    @objc private func notifyOrientationChange() {
        switch UIDevice.current.orientation {
        case .portrait, .portraitUpsideDown:
            addOrientationBreadcrumb("portrait")
        case .landscapeLeft, .landscapeRight:
            addOrientationBreadcrumb("landscape")
        default:
            print("unknown")
        }
    }

    private func addOrientationBreadcrumb(_ orientation: String) {
        let attributes = ["orientation": orientation]
        _ = BacktraceClient.shared?.addBreadcrumb("Configuration changed",
                                                      attributes: attributes,
                                                      type: .system,
                                                      level: .info)
    }

    // MARK: Memory Status Listener

    @objc private func notifyMemoryStatusChange() {
        _ = BacktraceClient.shared?.addBreadcrumb("Critical low memory warning!",
                                                      type: .system,
                                                      level: .fatal)
    }

    private var source: DispatchSourceMemoryPressure?
    @objc private func observeMemoryStatusChanged() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(notifyMemoryStatusChange),
                                               name: UIApplication.didReceiveMemoryWarningNotification,
                                               object: nil)

        if let source: DispatchSourceMemoryPressure =
            DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: DispatchQueue.main) as? DispatchSource {
            let eventHandler: DispatchSourceProtocol.DispatchSourceHandler = {
                let event: DispatchSource.MemoryPressureEvent = source.data
                if source.isCancelled == false {
                    self.didReceive(event)
                }
            }
            source.setEventHandler(handler: eventHandler)
            source.setRegistrationHandler(handler: eventHandler)
            source.activate()
            self.source = source
        }
    }

    private func getMemoryWarningText(_ memoryPressureEvent: DispatchSource.MemoryPressureEvent) -> String {
        if memoryPressureEvent.rawValue == DispatchSource.MemoryPressureEvent.normal.rawValue {
            return "Normal level memory pressure event"
        } else if memoryPressureEvent.rawValue == DispatchSource.MemoryPressureEvent.critical.rawValue {
            return "Critical level memory pressure event"
        } else if memoryPressureEvent.rawValue == DispatchSource.MemoryPressureEvent.warning.rawValue {
            return "Warning level memory pressure event"
        } else {
            return "Unspecified level memory pressure event"
        }
    }

    private func getMemoryWarningLevel(_ memoryPressureEvent: DispatchSource.MemoryPressureEvent) -> BacktraceBreadcrumbLevel {
        if memoryPressureEvent.rawValue == DispatchSource.MemoryPressureEvent.normal.rawValue {
            return .warning
        } else if memoryPressureEvent.rawValue == DispatchSource.MemoryPressureEvent.critical.rawValue {
            return .fatal
        } else if memoryPressureEvent.rawValue == DispatchSource.MemoryPressureEvent.warning.rawValue {
            return .error
        } else {
            return .debug
        }
    }

    private func didReceive(_ memoryPressureEvent: DispatchSource.MemoryPressureEvent) {
        let message = getMemoryWarningText(memoryPressureEvent)
        let level = getMemoryWarningLevel(memoryPressureEvent)
        _ = BacktraceClient.shared?.addBreadcrumb(message,
                                                  type: .system,
                                                  level: level)
    }

    // MARK: - Battery Status Listener

    @objc private func observeBatteryStatusChanged() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(notifyBatteryStatusChange),
                                               name: UIDevice.batteryLevelDidChangeNotification,
                                               object: nil)
    }

    private func getBatteryWarningText() -> String {
        let batteryLevel = UIDevice.current.batteryLevel
        switch UIDevice.current.batteryState {
        case .unknown:
            return "Unknown battery level : \(batteryLevel * 100)%"
        case .unplugged:
            return "unplugged battery level : \(batteryLevel * 100)%"
        case .charging:
            return "charging battery level : \(batteryLevel * 100)%"
        case .full:
            return "full battery level : \(batteryLevel * 100)%"
        }
    }

    @objc private func notifyBatteryStatusChange() {
        _ = BacktraceClient.shared?.addBreadcrumb(getBatteryWarningText(),
                                                      type: .system,
                                                      level: .info)
    }
}
