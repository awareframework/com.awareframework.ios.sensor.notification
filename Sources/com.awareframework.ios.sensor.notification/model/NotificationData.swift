import Foundation
import GRDB
import com_awareframework_ios_core

public struct NotificationData: BaseDbModelSQLite {
    public static let databaseTableName = "notificationData"
    public static let TABLE_NAME = databaseTableName

    public var id: Int64?
    public var timestamp: Int64
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String = ""
    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "iOS"
    public var jsonVersion: Int = 1

    public var notificationId: String = ""
    public var title: String = ""
    public var body: String = ""
    public var categoryIdentifier: String = ""
    public var bundleIdentifier: String = ""
    public var sound: String = ""
    public var badge: Int = 0
    public var threadIdentifier: String = ""
    public var interruptionLevel: Int = 0

    public init(timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000), label: String = "") {
        self.timestamp = timestamp
        self.label = label
    }

    public init(_ dict: [String: Any]) {
        self.id = dict["id"] as? Int64
        self.timestamp = dict["timestamp"] as? Int64 ?? Int64(Date().timeIntervalSince1970 * 1000)
        self.deviceId = dict["deviceId"] as? String ?? AwareUtils.getCommonDeviceId()
        self.label = dict["label"] as? String ?? ""
        self.notificationId = dict["notificationId"] as? String ?? ""
        self.title = dict["title"] as? String ?? ""
        self.body = dict["body"] as? String ?? ""
        self.categoryIdentifier = dict["categoryIdentifier"] as? String ?? ""
        self.bundleIdentifier = dict["bundleIdentifier"] as? String ?? ""
        self.sound = dict["sound"] as? String ?? ""
        self.badge = dict["badge"] as? Int ?? 0
        self.threadIdentifier = dict["threadIdentifier"] as? String ?? ""
        self.interruptionLevel = dict["interruptionLevel"] as? Int ?? 0
    }

    public func toDictionary() -> [String: Any] {
        [
            "id": id ?? -1,
            "timestamp": timestamp,
            "deviceId": deviceId,
            "label": label,
            "timezone": timezone,
            "os": os,
            "jsonVersion": jsonVersion,
            "notificationId": notificationId,
            "title": title,
            "body": body,
            "categoryIdentifier": categoryIdentifier,
            "bundleIdentifier": bundleIdentifier,
            "sound": sound,
            "badge": badge,
            "threadIdentifier": threadIdentifier,
            "interruptionLevel": interruptionLevel,
        ]
    }

    public static func createTable(queue: DatabaseQueue) throws {
        try queue.write { db in
            try db.create(table: databaseTableName, ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .integer).notNull()
                t.column("deviceId", .text).notNull()
                t.column("label", .text)
                t.column("timezone", .integer).notNull()
                t.column("os", .text).notNull()
                t.column("jsonVersion", .integer).notNull()
                t.column("notificationId", .text).notNull()
                t.column("title", .text).notNull()
                t.column("body", .text).notNull()
                t.column("categoryIdentifier", .text).notNull()
                t.column("bundleIdentifier", .text).notNull()
                t.column("sound", .text).notNull()
                t.column("badge", .integer).notNull()
                t.column("threadIdentifier", .text).notNull()
                t.column("interruptionLevel", .integer).notNull()
            }
        }
    }
}
