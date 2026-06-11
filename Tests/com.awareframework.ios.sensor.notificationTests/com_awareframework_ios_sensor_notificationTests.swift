import XCTest
@testable import com_awareframework_ios_sensor_notification

final class NotificationSensorTests: XCTestCase {

    func testDefaultConfig() {
        let config = NotificationSensor.Config()
        XCTAssertEqual(config.dbPath, "aware_notification")
        XCTAssertTrue(config.requestPermission)
        XCTAssertNil(config.sensorObserver)
    }

    func testConfigApply() {
        let config = NotificationSensor.Config().apply { c in
            c.debug = true
            c.label = "test"
            c.requestPermission = false
        }
        XCTAssertTrue(config.debug)
        XCTAssertEqual(config.label, "test")
        XCTAssertFalse(config.requestPermission)
    }

    func testNotificationDataInit() {
        let data = NotificationData()
        XCTAssertEqual(data.os, "iOS")
        XCTAssertEqual(data.jsonVersion, 1)
        XCTAssertEqual(data.notificationId, "")
        XCTAssertEqual(data.title, "")
        XCTAssertEqual(data.body, "")
    }

    func testNotificationDataFromDict() {
        let dict: [String: Any] = [
            "timestamp": Int64(1000),
            "notificationId": "test-id",
            "title": "Hello",
            "body": "World",
            "categoryIdentifier": "cat",
            "bundleIdentifier": "com.example.app",
            "sound": "default",
            "badge": 3,
            "threadIdentifier": "thread-1",
            "interruptionLevel": 1,
        ]
        let data = NotificationData(dict)
        XCTAssertEqual(data.timestamp, 1000)
        XCTAssertEqual(data.notificationId, "test-id")
        XCTAssertEqual(data.title, "Hello")
        XCTAssertEqual(data.body, "World")
        XCTAssertEqual(data.categoryIdentifier, "cat")
        XCTAssertEqual(data.bundleIdentifier, "com.example.app")
        XCTAssertEqual(data.sound, "default")
        XCTAssertEqual(data.badge, 3)
        XCTAssertEqual(data.threadIdentifier, "thread-1")
        XCTAssertEqual(data.interruptionLevel, 1)
    }

    func testNotificationDataToDictionary() {
        var data = NotificationData(timestamp: 2000, label: "lbl")
        data.notificationId = "nid"
        data.title = "T"
        data.body = "B"
        let dict = data.toDictionary()
        XCTAssertEqual(dict["timestamp"] as? Int64, 2000)
        XCTAssertEqual(dict["label"] as? String, "lbl")
        XCTAssertEqual(dict["notificationId"] as? String, "nid")
        XCTAssertEqual(dict["title"] as? String, "T")
        XCTAssertEqual(dict["body"] as? String, "B")
        XCTAssertEqual(dict["os"] as? String, "iOS")
        XCTAssertEqual(dict["jsonVersion"] as? Int, 1)
    }

    func testSensorInit() {
        let sensor = NotificationSensor()
        XCTAssertNotNil(sensor)
        XCTAssertEqual(sensor.CONFIG.dbPath, "aware_notification")
    }

    func testSensorSetLabel() {
        let sensor = NotificationSensor(NotificationSensor.Config().apply { c in
            c.debug = false
        })
        let expectation = XCTestExpectation(description: "label notification")
        let observer = NotificationCenter.default.addObserver(
            forName: .actionAwareNotificationSetLabel, object: nil, queue: .main
        ) { notification in
            let label = notification.userInfo?[NotificationSensor.EXTRA_LABEL] as? String
            XCTAssertEqual(label, "new-label")
            expectation.fulfill()
        }
        sensor.set(label: "new-label")
        XCTAssertEqual(sensor.CONFIG.label, "new-label")
        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testNotificationNames() {
        XCTAssertEqual(Notification.Name.actionAwareNotification.rawValue, NotificationSensor.ACTION_AWARE_NOTIFICATION)
        XCTAssertEqual(Notification.Name.actionAwareNotificationStart.rawValue, NotificationSensor.ACTION_AWARE_NOTIFICATION_START)
        XCTAssertEqual(Notification.Name.actionAwareNotificationStop.rawValue, NotificationSensor.ACTION_AWARE_NOTIFICATION_STOP)
        XCTAssertEqual(Notification.Name.actionAwareNotificationSync.rawValue, NotificationSensor.ACTION_AWARE_NOTIFICATION_SYNC)
        XCTAssertEqual(Notification.Name.actionAwareNotificationReceived.rawValue, NotificationSensor.ACTION_AWARE_NOTIFICATION_RECEIVED)
        XCTAssertEqual(Notification.Name.actionAwareNotificationTokenUpdated.rawValue, NotificationSensor.ACTION_AWARE_NOTIFICATION_TOKEN_UPDATED)
    }

    func testTokenDataInit() {
        let data = NotificationTokenData()
        XCTAssertEqual(data.os, "iOS")
        XCTAssertEqual(data.jsonVersion, 1)
        XCTAssertEqual(data.token, "")
    }

    func testTokenDataFromDict() {
        let dict: [String: Any] = [
            "timestamp": Int64(3000),
            "token": "abcd1234ef567890",
            "label": "research",
        ]
        let data = NotificationTokenData(dict)
        XCTAssertEqual(data.timestamp, 3000)
        XCTAssertEqual(data.token, "abcd1234ef567890")
        XCTAssertEqual(data.label, "research")
    }

    func testSilentPushDataInit() {
        let data = SilentPushData()
        XCTAssertEqual(data.os, "iOS")
        XCTAssertEqual(data.jsonVersion, 1)
        XCTAssertEqual(data.payload, "")
    }

    func testSilentPushDataFromDict() {
        let dict: [String: Any] = [
            "timestamp": Int64(5000),
            "payload": "{\"aps\":{\"content-available\":1}}",
            "label": "study",
        ]
        let data = SilentPushData(dict)
        XCTAssertEqual(data.timestamp, 5000)
        XCTAssertEqual(data.payload, "{\"aps\":{\"content-available\":1}}")
        XCTAssertEqual(data.label, "study")
    }

    func testHandleSilentPush() {
        let sensor = NotificationSensor()
        let receiveExpectation = XCTestExpectation(description: "silent push notification")
        let completionExpectation = XCTestExpectation(description: "fetch completion handler called")

        let observer = NotificationCenter.default.addObserver(
            forName: .actionAwareNotificationSilentPushReceived, object: nil, queue: .main
        ) { notification in
            let payload = notification.userInfo?[NotificationSensor.EXTRA_PAYLOAD] as? String
            XCTAssertNotNil(payload)
            XCTAssertTrue(payload?.contains("content-available") == true)
            receiveExpectation.fulfill()
        }

        let userInfo: [AnyHashable: Any] = [
            "aps": ["content-available": 1],
            "customKey": "customValue",
        ]
        sensor.handleSilentPush(userInfo: userInfo) { result in
            XCTAssertEqual(result, .newData)
            completionExpectation.fulfill()
        }

        wait(for: [receiveExpectation, completionExpectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    // MARK: - Command tests

    func testCommandSyncParsed() {
        let userInfo: [AnyHashable: Any] = ["aps": ["content-available": 1], "aware_command": "sync"]
        let command = NotificationCommand(userInfo: userInfo)
        XCTAssertEqual(command, .sync)
    }

    func testCommandRestartParsed() {
        let userInfo: [AnyHashable: Any] = ["aware_command": "restart"]
        XCTAssertEqual(NotificationCommand(userInfo: userInfo), .restart)
    }

    func testCommandConfigUpdateParsed() {
        let url = URL(string: "https://example.com/config.json")!
        let userInfo: [AnyHashable: Any] = [
            "aware_command": "config_update",
            "aware_config_url": "https://example.com/config.json",
        ]
        XCTAssertEqual(NotificationCommand(userInfo: userInfo), .configUpdate(url: url))
    }

    func testCommandConfigUpdateMissingURLFallsToCustom() {
        let userInfo: [AnyHashable: Any] = ["aware_command": "config_update"]
        XCTAssertEqual(NotificationCommand(userInfo: userInfo), .custom("config_update"))
    }

    func testCommandCustomParsed() {
        let userInfo: [AnyHashable: Any] = ["aware_command": "my_action"]
        XCTAssertEqual(NotificationCommand(userInfo: userInfo), .custom("my_action"))
    }

    func testNoCommandKeyReturnsNil() {
        let userInfo: [AnyHashable: Any] = ["aps": ["content-available": 1]]
        XCTAssertNil(NotificationCommand(userInfo: userInfo))
    }

    func testCommandSyncDispatchesNotification() {
        let sensor = NotificationSensor()
        let expectation = XCTestExpectation(description: "sync command notification")

        let observer = NotificationCenter.default.addObserver(
            forName: .actionAwareNotificationCommandSync, object: nil, queue: .main
        ) { notification in
            let cmd = notification.userInfo?[NotificationSensor.EXTRA_COMMAND] as? String
            XCTAssertEqual(cmd, NotificationCommand.commandSync)
            expectation.fulfill()
        }

        sensor.handleSilentPush(
            userInfo: ["aps": ["content-available": 1], "aware_command": "sync"]
        ) { _ in }

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testCommandRestartDispatchesNotification() {
        let sensor = NotificationSensor()
        let expectation = XCTestExpectation(description: "restart command notification")

        let observer = NotificationCenter.default.addObserver(
            forName: .actionAwareNotificationCommandRestart, object: nil, queue: .main
        ) { _ in expectation.fulfill() }

        sensor.handleSilentPush(
            userInfo: ["aps": ["content-available": 1], "aware_command": "restart"]
        ) { _ in }

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testCommandConfigUpdateDispatchesNotification() {
        let sensor = NotificationSensor()
        let expectation = XCTestExpectation(description: "config_update command notification")

        let observer = NotificationCenter.default.addObserver(
            forName: .actionAwareNotificationCommandConfigUpdate, object: nil, queue: .main
        ) { notification in
            let url = notification.userInfo?[NotificationSensor.EXTRA_CONFIG_URL] as? URL
            XCTAssertEqual(url?.absoluteString, "https://example.com/config.json")
            expectation.fulfill()
        }

        sensor.handleSilentPush(userInfo: [
            "aps": ["content-available": 1],
            "aware_command": "config_update",
            "aware_config_url": "https://example.com/config.json",
        ]) { _ in }

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testCommandCustomDispatchesNotification() {
        let sensor = NotificationSensor()
        let expectation = XCTestExpectation(description: "custom command notification")

        let observer = NotificationCenter.default.addObserver(
            forName: .actionAwareNotificationCommandCustom, object: nil, queue: .main
        ) { notification in
            let cmd = notification.userInfo?[NotificationSensor.EXTRA_COMMAND] as? String
            XCTAssertEqual(cmd, "my_custom_action")
            expectation.fulfill()
        }

        sensor.handleSilentPush(
            userInfo: ["aps": ["content-available": 1], "aware_command": "my_custom_action"]
        ) { _ in }

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testSetDeviceToken() {
        let sensor = NotificationSensor()
        let expectation = XCTestExpectation(description: "token notification")

        let observer = NotificationCenter.default.addObserver(
            forName: .actionAwareNotificationTokenUpdated, object: nil, queue: .main
        ) { notification in
            let token = notification.userInfo?[NotificationSensor.EXTRA_TOKEN] as? String
            XCTAssertEqual(token, "deadbeef")
            expectation.fulfill()
        }

        // Simulate AppDelegate passing the token (2 bytes = "deadbeef" for test)
        let fakeToken = Data([0xde, 0xad, 0xbe, 0xef])
        sensor.setDeviceToken(fakeToken)

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
}
