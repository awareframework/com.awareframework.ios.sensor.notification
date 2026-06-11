import Foundation

/// Commands that can be dispatched via silent push notification payload.
///
/// Payload format:
/// ```json
/// { "aps": {"content-available": 1}, "aware_command": "<command>" }
/// ```
public enum NotificationCommand: Equatable {
    /// Trigger an immediate data sync to the server.
    /// Payload: `{"aware_command": "sync"}`
    case sync

    /// Restart sensors. The observer is responsible for stopping and restarting sensors.
    /// Payload: `{"aware_command": "restart"}`
    case restart

    /// Download and apply a new configuration from the given URL.
    /// The observer is responsible for fetching and applying the config.
    /// Payload: `{"aware_command": "config_update", "aware_config_url": "https://..."}`
    case configUpdate(url: URL)

    /// An app-defined command not handled by the sensor itself.
    /// Payload: `{"aware_command": "<any_other_string>"}`
    case custom(String)

    // MARK: - Payload keys

    public static let payloadKey = "aware_command"
    public static let configURLKey = "aware_config_url"

    // MARK: - Command strings

    public static let commandSync = "sync"
    public static let commandRestart = "restart"
    public static let commandConfigUpdate = "config_update"

    // MARK: - Init

    /// Returns nil if `aware_command` key is absent from the payload.
    public init?(userInfo: [AnyHashable: Any]) {
        guard let commandString = userInfo[Self.payloadKey] as? String else { return nil }
        switch commandString {
        case Self.commandSync:
            self = .sync
        case Self.commandRestart:
            self = .restart
        case Self.commandConfigUpdate:
            let urlString = userInfo[Self.configURLKey] as? String ?? ""
            if let url = URL(string: urlString), url.scheme != nil {
                self = .configUpdate(url: url)
            } else {
                self = .custom(commandString)
            }
        default:
            self = .custom(commandString)
        }
    }

    /// Raw string value of the command.
    public var rawValue: String {
        switch self {
        case .sync:              return Self.commandSync
        case .restart:           return Self.commandRestart
        case .configUpdate:      return Self.commandConfigUpdate
        case .custom(let value): return value
        }
    }
}
