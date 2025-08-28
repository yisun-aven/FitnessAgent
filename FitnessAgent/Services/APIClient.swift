import Foundation

@MainActor
final class APIClient: ObservableObject {
    private weak var auth: AuthViewModel?

    func configure(auth: AuthViewModel) {
        self.auth = auth
    }

    private func request<T: Decodable>(_ path: String,
                                       method: String = "GET",
                                       body: Encodable? = nil,
                                       queryItems: [URLQueryItem]? = nil,
                                       decode: T.Type) async throws -> T {
        guard let token = auth?.accessToken else { throw URLError(.userAuthenticationRequired) }
        var url = AppConfig.backendBaseURL
        url.append(path: path)

        if let queryItems {
            if var comps = URLComponents(url: url, resolvingAgainstBaseURL: true) {
                comps.queryItems = queryItems
                if let u = comps.url { url = u }
            }
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body = body {
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "API", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: text])
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: Goals
    func listGoals() async throws -> [Goal] {
        try await request("/goals", decode: [Goal].self)
    }

    func createGoal(_ payload: GoalCreate) async throws -> Goal {
        // Legacy path: server used to return Goal; now it returns {goal, agent_output}.
        // Keep backward compatibility by reading CreateGoalResponse and returning .goal.
        let resp = try await request("/goals", method: "POST", body: payload, decode: CreateGoalResponse.self)
        return resp.goal
    }

    /// New helper if you want the agent_output as well.
    func createGoalWithAgent(_ payload: GoalCreate) async throws -> CreateGoalResponse {
        try await request("/goals", method: "POST", body: payload, decode: CreateGoalResponse.self)
    }

    // Delete a goal owned by the current user (204/200 on success)
    func deleteGoal(goalId: String) async throws {
        guard let token = auth?.accessToken else { throw URLError(.userAuthenticationRequired) }
        var url = AppConfig.backendBaseURL
        url.append(path: "/goals/\(goalId)")
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "API", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "DELETE /goals failed with status \(http.statusCode)"])
        }
    }

    // MARK: Tasks
    // Legacy: listTasks(goalId:) now delegates to the goals endpoint
    func listTasks(goalId: String? = nil) async throws -> [TaskItem] {
        guard let goalId else {
            throw NSError(domain: "API", code: -1, userInfo: [NSLocalizedDescriptionKey: "listTasks() without goalId is deprecated. Use listGoalTasks(goalId:)"])
        }
        return try await listGoalTasks(goalId: goalId)
    }

    // Explicit endpoint that aligns with backend /goals/{goal_id}/tasks
    func listGoalTasks(goalId: String) async throws -> [TaskItem] {
        try await request("/goals/\(goalId)/tasks", decode: [TaskItem].self)
    }

    // Legacy: parameterless listTasks is deprecated and disabled
    func listTasks() async throws -> [TaskItem] {
        throw NSError(domain: "API", code: -1, userInfo: [NSLocalizedDescriptionKey: "listTasks() is deprecated. Use listGoalTasks(goalId:)"])
    }

    func createTask(_ payload: TaskCreate) async throws -> TaskItem {
        try await request("/tasks", method: "POST", body: payload, decode: TaskItem.self)
    }

    // Deprecated: do not call. Server generates tasks during goal creation.
    @available(*, deprecated, message: "Use POST /goals which persists tasks; then GET /goals/{goal_id}/tasks")
    func generateTasks(goalType: String, targetValue: Double?, targetDate: String?) async throws -> GenerateTasksResponse {
        throw NSError(domain: "API", code: -1, userInfo: [NSLocalizedDescriptionKey: "generateTasks() is deprecated. Tasks are generated on goal creation and fetched via GET /goals/{goal_id}/tasks."])
    }

    // MARK: Coach
    struct CoachChatResponse: Codable { let role: String; let content: String }
    func coachChat(message: String, goalId: String? = nil) async throws -> CoachChatResponse {
        struct Payload: Encodable { let user_id: String; let message: String; let goal_id: String? }
        // Try to pull a stable user id from auth session
        guard let rawUserId = auth?.session?.user.id else { throw URLError(.userAuthenticationRequired) }
        let uid = String(describing: rawUserId)
        return try await request("/coach/chat", method: "POST", body: Payload(user_id: uid, message: message, goal_id: goalId), decode: CoachChatResponse.self)
    }

    // MARK: Chat History
    struct ChatHistoryAPIMessage: Codable { let role: String; let content: [String:String]?; let created_at: String? }
    struct ChatHistoryResponse: Codable { let conversation_id: String?; let messages: [ChatHistoryAPIMessage] }

    func fetchChatHistory(goalId: String? = nil, limit: Int = 200) async throws -> ChatHistoryResponse {
        var items = [URLQueryItem(name: "limit", value: String(limit))]
        if let gid = goalId { items.append(URLQueryItem(name: "goal_id", value: gid)) }
        return try await request("/coach/history", queryItems: items, decode: ChatHistoryResponse.self)
    }

    // MARK: Profile
    func fetchMyProfile() async throws -> Profile? {
        try await request("/profile/me", decode: Profile?.self)
    }

    func upsertProfile(_ payload: ProfileUpsert) async throws -> Profile {
        try await request("/profile", method: "POST", body: payload, decode: Profile.self)
    }
}

// MARK: - Goal create response with agent output
struct CreateGoalResponse: Codable {
    let goal: Goal
    let agent_output: [TaskDraft]? // server returns parsed tasks as an array of dictionaries
}

struct TaskDraft: Codable {
    let title: String
    let description: String?
    let due_at: String?
    let status: String?
}

// MARK: - Profile Models
struct Profile: Codable, Identifiable {
    let id: String
    let created_at: String?
    var sex: String?
    var dob: String? // ISO date string "YYYY-MM-DD"
    var height_cm: Double?
    var weight_kg: Double?
    var unit_pref: String?
    var activity_level: String?
    var fitness_level: String?
    var resting_hr: Double?
    var max_hr: Double?
    var body_fat_pct: Double?
    var medical_conditions: String?
    var injuries: String?
    var timezone: String?
    var locale: String?
    var availability_days: [Int]?
}

struct ProfileUpsert: Codable {
    var sex: String?
    var dob: String?
    var height_cm: Double?
    var weight_kg: Double?
    var unit_pref: String?
    var activity_level: String?
    var fitness_level: String?
    var resting_hr: Double?
    var max_hr: Double?
    var body_fat_pct: Double?
    var medical_conditions: String?
    var injuries: String?
    var timezone: String?
    var locale: String?
    var availability_days: [Int]?
}

// Helper for Encoding any Encodable
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ encodable: Encodable) { self._encode = encodable.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}