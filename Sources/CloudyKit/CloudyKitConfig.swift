import Foundation
#if os(Linux)
import FoundationNetworking
#endif

public class CloudyKitConfig {
    public enum Environment: String {
        case development = "development"
        case production = "production"
    }
    
    public nonisolated(unsafe) static var environment: Environment = .development
    public nonisolated(unsafe) static var serverKeyID: String = "Make sure to update this with your server key."
    public nonisolated(unsafe) static var serverPrivateKey: CKPrivateKey? = nil
    public nonisolated(unsafe) static var debug = false
    
    internal nonisolated(unsafe) static var urlSession: NetworkSession = URLSession(configuration: .default)

    internal static let host = "https://api.apple-cloudkit.com"
    internal static var decoder: JSONDecoder { JSONDecoder() }
    internal static var encoder: JSONEncoder { JSONEncoder() }

    internal static func iso8601DateString(from date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
    
}
