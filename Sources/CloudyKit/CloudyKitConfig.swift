import Foundation
#if os(Linux)
import FoundationNetworking
#endif

public class CloudyKitConfig {
    
    public enum Environment: String {
        case development = "development"
        case `public` = "public"
    }
    
    public static var environment: Environment = .development
    
    internal static var urlSession: NetworkSession = URLSession(configuration: .default)
    internal static let host = "https://api.apple-cloudkit.com"
    internal static let dateFormatter = ISO8601DateFormatter()
    internal static let decoder = JSONDecoder()
    
}
