import UIKit
import UserNotifications
import com_awareframework_ios_core

extension Notification.Name {
    public static let actionAwareNotification = Notification.Name(NotificationSensor.ACTION_AWARE_NOTIFICATION)
    public static let actionAwareNotificationStart = Notification.Name(NotificationSensor.ACTION_AWARE_NOTIFICATION_START)
    public static let actionAwareNotificationStop = Notification.Name(NotificationSensor.ACTION_AWARE_NOTIFICATION_STOP)
    public static let actionAwareNotificationSync = Notification.Name(NotificationSensor.ACTION_AWARE_NOTIFICATION_SYNC)
    public static let actionAwareNotificationSetLabel = Notification.Name(NotificationSensor.ACTION_AWARE_NOTIFICATION_SET_LABEL)
    public static let actionAwareNotificationSyncCompletion = Notification.Name(NotificationSensor.ACTION_AWARE_NOTIFICATION_SYNC_COMPLETION)
    public static let actionAwareNotificationReceived = Notification.Name(NotificationSensor.ACTION_AWARE_NOTIFICATION_RECEIVED)
    public static let actionAwareNotificationTokenUpdated = Notification.Name(NotificationSensor.ACTION_AWARE_NOTIFICATION_TOKEN_UPDATED)
    public static let actionAwareNotificationSilentPushReceived = Notification.Name(NotificationSensor.ACTION_AWARE_NOTIFICATION_SILENT_PUSH_RECEIVED)
    public static let actionAwareNotificationCommandSync = Notification.Name(NotificationSensor.ACTION_AWARE_NOTIFICATION_COMMAND_SYNC)
    public static let actionAwareNotificationCommandRestart = Notification.Name(NotificationSensor.ACTION_AWARE_NOTIFICATION_COMMAND_RESTART)
    public static let actionAwareNotificationCommandConfigUpdate = Notification.Name(NotificationSensor.ACTION_AWARE_NOTIFICATION_COMMAND_CONFIG_UPDATE)
    public static let actionAwareNotificationCommandCustom = Notification.Name(NotificationSensor.ACTION_AWARE_NOTIFICATION_COMMAND_CUSTOM)
}

public protocol NotificationObserver {
    func onNotificationReceived(data: NotificationData)
    func onDeviceTokenUpdated(data: NotificationTokenData)
    func onSilentPushReceived(data: SilentPushData)
    func onCommandReceived(command: NotificationCommand, data: SilentPushData)
}

public class NotificationSensor: AwareSensor {

    public static let TAG = "Aware::Notification"

    public static let ACTION_AWARE_NOTIFICATION = "com.awareframework.ios.sensor.notification"
    public static let ACTION_AWARE_NOTIFICATION_START = "com.awareframework.ios.sensor.notification.SENSOR_START"
    public static let ACTION_AWARE_NOTIFICATION_STOP = "com.awareframework.ios.sensor.notification.SENSOR_STOP"
    public static let ACTION_AWARE_NOTIFICATION_SYNC = "com.awareframework.ios.sensor.notification.SYNC"
    public static let ACTION_AWARE_NOTIFICATION_SYNC_COMPLETION = "com.awareframework.ios.sensor.notification.SENSOR_SYNC_COMPLETION"
    public static let ACTION_AWARE_NOTIFICATION_SET_LABEL = "com.awareframework.ios.sensor.notification.SET_LABEL"
    public static let ACTION_AWARE_NOTIFICATION_RECEIVED = "com.awareframework.ios.sensor.notification.RECEIVED"
    public static let ACTION_AWARE_NOTIFICATION_TOKEN_UPDATED = "com.awareframework.ios.sensor.notification.TOKEN_UPDATED"
    public static let ACTION_AWARE_NOTIFICATION_SILENT_PUSH_RECEIVED = "com.awareframework.ios.sensor.notification.SILENT_PUSH_RECEIVED"
    public static let ACTION_AWARE_NOTIFICATION_COMMAND_SYNC = "com.awareframework.ios.sensor.notification.COMMAND_SYNC"
    public static let ACTION_AWARE_NOTIFICATION_COMMAND_RESTART = "com.awareframework.ios.sensor.notification.COMMAND_RESTART"
    public static let ACTION_AWARE_NOTIFICATION_COMMAND_CONFIG_UPDATE = "com.awareframework.ios.sensor.notification.COMMAND_CONFIG_UPDATE"
    public static let ACTION_AWARE_NOTIFICATION_COMMAND_CUSTOM = "com.awareframework.ios.sensor.notification.COMMAND_CUSTOM"

    public static let EXTRA_DATA = "data"
    public static let EXTRA_LABEL = "label"
    public static let EXTRA_STATUS = "status"
    public static let EXTRA_ERROR = "error"
    public static let EXTRA_TOKEN = "token"
    public static let EXTRA_PAYLOAD = "payload"
    public static let EXTRA_COMMAND = "command"
    public static let EXTRA_CONFIG_URL = "configUrl"

    private var notificationCenter_UN: UNUserNotificationCenter {
        return UNUserNotificationCenter.current()
    }

    private weak var previousDelegate: (UNUserNotificationCenterDelegate & AnyObject)?
    private let delegateProxy = NotificationDelegateProxy()

    public var CONFIG = Config()

    public class Config: SensorConfig {
        public var sensorObserver: NotificationObserver? = nil
        public var requestPermission: Bool = true

        public override init() {
            super.init()
            dbPath = "aware_notification"
        }

        public func apply(closure: (_ config: NotificationSensor.Config) -> Void) -> Self {
            closure(self)
            return self
        }
    }

    public override convenience init() {
        self.init(NotificationSensor.Config())
    }

    public init(_ config: NotificationSensor.Config) {
        super.init()
        CONFIG = config
        initializeDbEngine(config: config)
        super.syncConfig = DbSyncConfig().apply { syncConfig in
            syncConfig.debug = config.debug
            syncConfig.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.notification.sync.queue")
            syncConfig.completionHandler = { status, error in
                var userInfo: [String: Any] = [NotificationSensor.EXTRA_STATUS: status]
                if let error = error {
                    userInfo[NotificationSensor.EXTRA_ERROR] = error
                }
                self.notificationCenter.post(
                    name: .actionAwareNotificationSyncCompletion,
                    object: self,
                    userInfo: userInfo)
            }
        }
        initializeTable()
    }

    public override func start() {
        delegateProxy.sensor = self
        previousDelegate = notificationCenter_UN.delegate as? (UNUserNotificationCenterDelegate & AnyObject)
        delegateProxy.chainedDelegate = previousDelegate
        notificationCenter_UN.delegate = delegateProxy

        if CONFIG.requestPermission {
            notificationCenter_UN.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if self.CONFIG.debug {
                    if let error = error {
                        print(NotificationSensor.TAG, "Permission error:", error)
                    } else {
                        print(NotificationSensor.TAG, "Permission granted:", granted)
                    }
                }
            }
        }

        self.notificationCenter.post(name: .actionAwareNotificationStart, object: self)
        if CONFIG.debug { print(NotificationSensor.TAG, "started") }
    }

    public override func stop() {
        if notificationCenter_UN.delegate === delegateProxy {
            notificationCenter_UN.delegate = previousDelegate
        }
        delegateProxy.sensor = nil
        self.notificationCenter.post(name: .actionAwareNotificationStop, object: self)
        if CONFIG.debug { print(NotificationSensor.TAG, "stopped") }
    }

    public override func sync(force: Bool = false) {
        guard let engine = self.dbEngine else { return }
        engine.startSync(DbSyncConfig().apply { config in
            config.debug = self.CONFIG.debug
            config.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.notification.sync.queue")
            config.completionHandler = { status, error in
                var userInfo: [String: Any] = [NotificationSensor.EXTRA_STATUS: status]
                if let error = error {
                    userInfo[NotificationSensor.EXTRA_ERROR] = error
                }
                self.notificationCenter.post(
                    name: .actionAwareNotificationSyncCompletion,
                    object: self,
                    userInfo: userInfo)
            }
        })
        self.notificationCenter.post(name: .actionAwareNotificationSync, object: self)
    }

    public override func set(label: String) {
        CONFIG.label = label
        self.notificationCenter.post(
            name: .actionAwareNotificationSetLabel,
            object: self,
            userInfo: [NotificationSensor.EXTRA_LABEL: label])
    }

    func handle(notification: UNNotification) {
        let content = notification.request.content
        var data = NotificationData()
        data.notificationId = notification.request.identifier
        data.title = content.title
        data.body = content.body
        data.categoryIdentifier = content.categoryIdentifier
        data.bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        data.sound = content.sound != nil ? "default" : ""
        data.badge = content.badge?.intValue ?? 0
        data.threadIdentifier = content.threadIdentifier
        if #available(iOS 15.0, *) {
            data.interruptionLevel = Int(content.interruptionLevel.rawValue)
        }
        data.label = CONFIG.label

        saveModel(data)

        CONFIG.sensorObserver?.onNotificationReceived(data: data)

        self.notificationCenter.post(
            name: .actionAwareNotificationReceived,
            object: self,
            userInfo: [NotificationSensor.EXTRA_DATA: data])
    }

    /// Call this from AppDelegate's `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
    /// Stores the APNs device token and notifies observers.
    public func setDeviceToken(_ deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        if CONFIG.debug { print(NotificationSensor.TAG, "APNs token:", tokenString) }

        var tokenData = NotificationTokenData()
        tokenData.token = tokenString
        tokenData.label = CONFIG.label

        saveTokenModel(tokenData)

        CONFIG.sensorObserver?.onDeviceTokenUpdated(data: tokenData)

        self.notificationCenter.post(
            name: .actionAwareNotificationTokenUpdated,
            object: self,
            userInfo: [NotificationSensor.EXTRA_TOKEN: tokenString])
    }

    /// Call this from AppDelegate's `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`.
    /// Handles silent push notifications (payload must include `content-available: 1`).
    /// The sensor saves the raw payload, dispatches any recognized command, and calls the completion handler.
    public func handleSilentPush(
        userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let payloadString = serializePayload(userInfo)
        if CONFIG.debug { print(NotificationSensor.TAG, "Silent push received:", payloadString) }

        var data = SilentPushData()
        data.payload = payloadString
        data.label = CONFIG.label

        saveSilentPushModel(data)

        self.notificationCenter.post(
            name: .actionAwareNotificationSilentPushReceived,
            object: self,
            userInfo: [NotificationSensor.EXTRA_DATA: data,
                       NotificationSensor.EXTRA_PAYLOAD: payloadString])

        CONFIG.sensorObserver?.onSilentPushReceived(data: data)

        if let command = NotificationCommand(userInfo: userInfo) {
            dispatchCommand(command, data: data)
        }

        completionHandler(.newData)
    }

    private func dispatchCommand(_ command: NotificationCommand, data: SilentPushData) {
        if CONFIG.debug { print(NotificationSensor.TAG, "Command received:", command.rawValue) }

        CONFIG.sensorObserver?.onCommandReceived(command: command, data: data)

        switch command {
        case .sync:
            sync(force: true)
            self.notificationCenter.post(
                name: .actionAwareNotificationCommandSync,
                object: self,
                userInfo: [NotificationSensor.EXTRA_DATA: data,
                           NotificationSensor.EXTRA_COMMAND: command.rawValue])

        case .restart:
            self.notificationCenter.post(
                name: .actionAwareNotificationCommandRestart,
                object: self,
                userInfo: [NotificationSensor.EXTRA_DATA: data,
                           NotificationSensor.EXTRA_COMMAND: command.rawValue])

        case .configUpdate(let url):
            self.notificationCenter.post(
                name: .actionAwareNotificationCommandConfigUpdate,
                object: self,
                userInfo: [NotificationSensor.EXTRA_DATA: data,
                           NotificationSensor.EXTRA_COMMAND: command.rawValue,
                           NotificationSensor.EXTRA_CONFIG_URL: url])

        case .custom(let value):
            self.notificationCenter.post(
                name: .actionAwareNotificationCommandCustom,
                object: self,
                userInfo: [NotificationSensor.EXTRA_DATA: data,
                           NotificationSensor.EXTRA_COMMAND: value])
        }
    }

    private func serializePayload(_ userInfo: [AnyHashable: Any]) -> String {
        // Convert AnyHashable keys to String for JSON serialization
        var stringKeyed: [String: Any] = [:]
        for (key, value) in userInfo {
            stringKeyed["\(key)"] = value
        }
        guard let data = try? JSONSerialization.data(withJSONObject: stringKeyed),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private func initializeTable() {
        guard let queue = (self.dbEngine as? SQLiteEngine)?.getSQLiteInstance() else { return }
        do {
            try NotificationData.createTable(queue: queue)
            try NotificationTokenData.createTable(queue: queue)
            try SilentPushData.createTable(queue: queue)
        } catch {
            if CONFIG.debug { print(NotificationSensor.TAG, "Table creation error:", error) }
        }
    }

    private func saveModel(_ model: NotificationData) {
        guard let engine = self.dbEngine as? SQLiteEngine else { return }
        engine.save([model])
    }

    private func saveTokenModel(_ model: NotificationTokenData) {
        guard let engine = self.dbEngine as? SQLiteEngine else { return }
        engine.save([model])
    }

    private func saveSilentPushModel(_ model: SilentPushData) {
        guard let engine = self.dbEngine as? SQLiteEngine else { return }
        engine.save([model])
    }
}

// Proxy that receives UNUserNotificationCenter delegate callbacks and forwards to NotificationSensor.
// Using a separate class keeps NotificationSensor free of the Sendable requirement on NSObjectProtocol.
final class NotificationDelegateProxy: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    weak var sensor: NotificationSensor?
    weak var chainedDelegate: (UNUserNotificationCenterDelegate & AnyObject)?

    // Called when a notification is delivered while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        sensor?.handle(notification: notification)
        if let chained = chainedDelegate,
           chained.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:))) {
            chained.userNotificationCenter?(center, willPresent: notification, withCompletionHandler: completionHandler)
        } else {
            completionHandler([.banner, .sound, .badge])
        }
    }

    // Called when the user interacts with a notification (tap, dismiss, action).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        sensor?.handle(notification: response.notification)
        if let chained = chainedDelegate,
           chained.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:))) {
            chained.userNotificationCenter?(center, didReceive: response, withCompletionHandler: completionHandler)
        } else {
            completionHandler()
        }
    }
}
