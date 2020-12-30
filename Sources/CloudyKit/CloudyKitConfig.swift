import Foundation
#if os(Linux)
import FoundationNetworking
#endif

public class CloudyKitConfig {
    
    public enum Environment: String {
        case development = "development"
        case production = "production"
    }
    
    public static var environment: Environment = .development
    public static var serverKeyID: String = "Make sure to update this with your server key."
    public static var serverPrivateKey: CKPrivateKey? = nil
    public static var debug = false
    
    internal static var urlSession: NetworkSession = URLSession(configuration: .default)
    internal static let host = "https://api.apple-cloudkit.com"
    internal static let dateFormatter = ISO8601DateFormatter()
    internal static let decoder = JSONDecoder()
    internal static let encoder = JSONEncoder()
    
}
