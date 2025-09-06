import Foundation

public struct ChatMessage: Identifiable, Hashable, Codable {
    public let id: UUID = UUID()
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}
