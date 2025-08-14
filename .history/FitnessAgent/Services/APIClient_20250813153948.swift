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
                                       decode: T.Type) async throws -> T {
        guard let token = auth?.accessToken else { throw URLError(.userAuthenticationRequired) }
        var url = AppConfig.backendBaseURL
        url.append(path: path)

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
        try await request("/goals/", decode: [Goal].self)
    }

    func createGoal(_ payload: GoalCreate) async throws -> Goal {
        try await request("/goals/", method: "POST", body: payload, decode: Goal.self)
    }

    // MARK: Tasks
    func listTasks() async throws -> [TaskItem] {
        try await request("/tasks/", decode: [TaskItem].self)
    }

    func createTask(_ payload: TaskCreate) async throws -> TaskItem {
        try await request("/tasks/", method: "POST", body: payload, decode: TaskItem.self)
    }

    func generateTasks(goalType: String, targetValue: Double?, targetDate: String?) async throws -> GenerateTasksResponse {
        let req = GenerateTasksRequest(goal: .init(type: goalType, target_value: targetValue, target_date: targetDate))
        return try await request("/tasks/generate", method: "POST", body: req, decode: GenerateTasksResponse.self)
    }
}

// Helper for Encoding any Encodable
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ encodable: Encodable) { self._encode = encodable.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}
