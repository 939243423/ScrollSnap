import Foundation

public final class CrossProcessNotifier {
    public static func post(name: String) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let cfName = CFNotificationName(name as CFString)
        CFNotificationCenterPostNotification(center, cfName, nil, nil, true)
    }
    
    public static func observe(name: String, queue: OperationQueue = .main, handler: @escaping () -> Void) -> DarwinNotificationToken {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let token = DarwinNotificationToken(name: name, handler: handler)
        let observerPointer = Unmanaged.passRetained(token).toOpaque()
        
        let cfName = CFNotificationName(name as CFString)
        CFNotificationCenterAddObserver(
            center,
            observerPointer,
            { _, observer, name, _, _ in
                guard let observer = observer else { return }
                let instance = Unmanaged<DarwinNotificationToken>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async {
                    instance.handler()
                }
            },
            cfName.rawValue,
            nil,
            .deliverImmediately
        )
        return token
    }
}

public final class DarwinNotificationToken {
    fileprivate let name: String
    fileprivate let handler: () -> Void
    
    fileprivate init(name: String, handler: @escaping () -> Void) {
        self.name = name
        self.handler = handler
    }
    
    deinit {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let cfName = CFNotificationName(name as CFString)
        let pointer = Unmanaged.passRetained(self).toOpaque()
        CFNotificationCenterRemoveObserver(center, pointer, cfName, nil)
    }
}
