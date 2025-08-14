import Foundation

struct GoalCreate: Codable {
    let type: String
    let target_value: Double?
    let target_date: String? // ISO date (YYYY-MM-DD)
}

struct Goal: Codable, Identifiable {
    let id: String
    let user_id: String
    let type: String
    let target_value: Double?
    let target_date: String?
    let created_at: String
}

struct TaskCreate: Codable {
    let goal_id: String?
    let title: String
    let description: String?
    let due_at: String? // ISO8601 datetime
}

struct TaskItem: Codable, Identifiable {
    let id: String
    let user_id: String
    let goal_id: String?
    let title: String
    let description: String?
    let due_at: String?
    let status: String
    let calendar_event_id: String?
    let created_at: String
}

struct GenerateTasksRequest: Codable {
    struct GoalPayload: Codable {
        let type: String
        let target_value: Double?
        let target_date: String?
    }
    let goal: GoalPayload
}

struct GenerateTasksResponse: Codable {
    struct GeneratedTask: Codable {
        let title: String
        let description: String?
        let due_at: String?
    }
    let tasks: [GeneratedTask]
}
