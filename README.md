# AWARE: Notification

[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)

This sensor module captures push notification events using the UserNotifications framework. It records notifications received while the app is in the foreground, stores APNs device tokens, and handles silent push notifications — including built-in commands for triggering data sync, restarting sensors, or applying remote configuration updates.

## Requirements
iOS 13 or later

## Installation

1. Open Package Manager Windows
    * Open `Xcode` -> Select `Menu Bar` -> `File` -> `App Package Dependencies...`

2. Find the package using the manager
    * Select `Search Package URL` and type `https://github.com/awareframework/com.awareframework.ios.sensor.notification.git`

3. Import the package into your target.

4. Enable **Push Notifications** and **Background Modes → Remote notifications** capabilities in Xcode.

## AppDelegate integration

The sensor must receive APNs callbacks from your `AppDelegate`:

```swift
// AppDelegate.swift
func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    notificationSensor.setDeviceToken(deviceToken)
}

func application(_ application: UIApplication,
                 didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                 fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    notificationSensor.handleSilentPush(userInfo: userInfo, fetchCompletionHandler: completionHandler)
}
```

## Public functions

### NotificationSensor

+ `init(_ config: NotificationSensor.Config)`: Initializes the sensor with the given configuration.
+ `start()`: Installs the notification delegate proxy and optionally requests permission.
+ `stop()`: Removes the delegate proxy and restores the previous delegate.
+ `sync(force:)`: Syncs stored data to the configured host.
+ `set(label:)`: Sets a custom label applied to all subsequent data points.
+ `setDeviceToken(_ deviceToken: Data)`: Call from `AppDelegate` when an APNs token is received. Stores the token and notifies observers.
+ `handleSilentPush(userInfo:fetchCompletionHandler:)`: Call from `AppDelegate` to handle silent push notifications. Dispatches recognized commands and stores the raw payload.

### NotificationSensor.Config

Class to hold the configuration of the sensor.

#### Fields

+ `sensorObserver: NotificationObserver?`: Callback for live data updates.
+ `requestPermission: Bool`: If `true`, requests notification authorization on `start()`. (default = `true`)
+ `enabled: Bool`: Sensor is enabled or not. (default = `false`)
+ `debug: Bool`: Enable/disable logging. (default = `false`)
+ `label: String`: Label for the data. (default = "")
+ `deviceId: String`: Id of the device associated with the events. (default = "")
+ `dbEncryptionKey`: Encryption key for the database. (default = `nil`)
+ `dbType: Engine`: Which db engine to use for saving data. (default = `Engine.DatabaseType.NONE`)
+ `dbPath: String`: Path of the database. (default = "aware_notification")
+ `dbHost: String`: Host for syncing the database. (default = `nil`)

## Silent push commands

Silent push payloads (with `content-available: 1`) may include an `aware_command` key to trigger built-in sensor actions:

| Command         | Payload                                                                    | Description                                  |
| --------------- | -------------------------------------------------------------------------- | -------------------------------------------- |
| `sync`          | `{"aware_command": "sync"}`                                               | Triggers an immediate data sync to the server |
| `restart`       | `{"aware_command": "restart"}`                                            | Fires the restart notification; the app handles actual restart |
| `config_update` | `{"aware_command": "config_update", "aware_config_url": "https://..."}`   | Fires the config update notification with the URL |
| custom          | `{"aware_command": "<any_other_string>"}`                                 | Passed through to the observer as `.custom`  |

## Broadcasts

### Fired Broadcasts

+ `NotificationSensor.ACTION_AWARE_NOTIFICATION_RECEIVED`: fired when a foreground notification is received.
+ `NotificationSensor.ACTION_AWARE_NOTIFICATION_TOKEN_UPDATED`: fired when the APNs device token is updated.
+ `NotificationSensor.ACTION_AWARE_NOTIFICATION_SILENT_PUSH_RECEIVED`: fired when a silent push is received.
+ `NotificationSensor.ACTION_AWARE_NOTIFICATION_COMMAND_SYNC`: fired for a `sync` command.
+ `NotificationSensor.ACTION_AWARE_NOTIFICATION_COMMAND_RESTART`: fired for a `restart` command.
+ `NotificationSensor.ACTION_AWARE_NOTIFICATION_COMMAND_CONFIG_UPDATE`: fired for a `config_update` command.
+ `NotificationSensor.ACTION_AWARE_NOTIFICATION_COMMAND_CUSTOM`: fired for unrecognized commands.

### Received Broadcasts

+ `NotificationSensor.ACTION_AWARE_NOTIFICATION_START`: received broadcast to start the sensor.
+ `NotificationSensor.ACTION_AWARE_NOTIFICATION_STOP`: received broadcast to stop the sensor.
+ `NotificationSensor.ACTION_AWARE_NOTIFICATION_SYNC`: received broadcast to send sync attempt to the host.
+ `NotificationSensor.ACTION_AWARE_NOTIFICATION_SET_LABEL`: received broadcast to set the data label.

## Data Representations

### NotificationData

Contains notification event data.

| Field              | Type   | Description                                               |
| ------------------ | ------ | --------------------------------------------------------- |
| notificationId     | String | UNNotificationRequest identifier                          |
| title              | String | Notification title                                        |
| body               | String | Notification body text                                    |
| categoryIdentifier | String | Category identifier for actionable notifications          |
| bundleIdentifier   | String | Bundle ID of the app that received the notification       |
| sound              | String | Sound name ("default" if sound was set, empty otherwise)  |
| badge              | Int    | Badge count set by the notification                       |
| threadIdentifier   | String | Thread identifier for grouping notifications              |
| interruptionLevel  | Int    | Interruption level (iOS 15+)                              |
| label              | String | Customizable label                                        |
| deviceId           | String | AWARE device UUID                                         |
| timestamp          | Int64  | Unixtime milliseconds since 1970                          |
| timezone           | Int    | Timezone of the device                                    |
| os                 | String | Operating system of the device (iOS)                      |
| jsonVersion        | Int    | JSON schema version                                       |

### NotificationTokenData

Contains the APNs device token.

| Field       | Type   | Description                       |
| ----------- | ------ | --------------------------------- |
| token       | String | APNs device token as a hex string |
| label       | String | Customizable label                |
| deviceId    | String | AWARE device UUID                 |
| timestamp   | Int64  | Unixtime milliseconds since 1970  |
| timezone    | Int    | Timezone of the device            |
| os          | String | Operating system of the device (iOS) |
| jsonVersion | Int    | JSON schema version               |

### SilentPushData

Contains the raw silent push payload.

| Field       | Type   | Description                                    |
| ----------- | ------ | ---------------------------------------------- |
| payload     | String | JSON-serialized push notification payload      |
| label       | String | Customizable label                             |
| deviceId    | String | AWARE device UUID                              |
| timestamp   | Int64  | Unixtime milliseconds since 1970               |
| timezone    | Int    | Timezone of the device                         |
| os          | String | Operating system of the device (iOS)           |
| jsonVersion | Int    | JSON schema version                            |

## Example usage

```swift
import com_awareframework_ios_sensor_notification
```

```swift
let sensor = NotificationSensor(NotificationSensor.Config().apply { config in
    config.sensorObserver = Observer()
    config.requestPermission = true
    config.debug = true
})

sensor.start()

// Later...
sensor.stop()
```

```swift
class Observer: NotificationObserver {
    func onNotificationReceived(data: NotificationData) {
        print("Notification:", data.title, data.body)
    }

    func onDeviceTokenUpdated(data: NotificationTokenData) {
        print("APNs token:", data.token)
    }

    func onSilentPushReceived(data: SilentPushData) {
        print("Silent push payload:", data.payload)
    }

    func onCommandReceived(command: NotificationCommand, data: SilentPushData) {
        print("Command:", command.rawValue)
    }
}
```

## Author
Yuuki Nishiyama (The University of Tokyo), nishiyama@csis.u-tokyo.ac.jp

## Related Links
* [Apple | UserNotifications](https://developer.apple.com/documentation/usernotifications)
* [Apple | Registering Your App with APNs](https://developer.apple.com/documentation/usernotifications/registering_your_app_with_apns)

## License
Copyright (c) 2018 AWARE Mobile Context Instrumentation Middleware/Framework (http://www.awareframework.com)

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0 Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.