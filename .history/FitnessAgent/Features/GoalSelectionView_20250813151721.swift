import SwiftUI

struct GoalSelectionView: View {
    @EnvironmentObject private var api: APIClient
    @EnvironmentObject private var auth: AuthViewModel
    @State private var goalType: String = "weight_loss"
    @State private var targetValueText: String = ""
    @State private var targetDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select your goal").font(.title2).bold()

            Picker("Goal Type", selection: $goalType) {
                Text("Weight Loss").tag("weight_loss")
                Text("muscle_gain").tag("muscle_gain")
                Text("endurance").tag("endurance")
            }
            .pickerStyle(.segmented)

            TextField("Target value (optional)", text: $targetValueText)
                .keyboardType(.decimalPad)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)

            DatePicker("Target date (optional)", selection: $targetDate, displayedComponents: .date)
                .datePickerStyle(.compact)

            Button("Continue") {
                Task { await createGoalAndGenerate() }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .foregroundColor(.black)
            .cornerRadius(8)
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sign Out") { Task { await auth.signOut() } }
            }
        }
    }

    private func createGoalAndGenerate() async {
        do {
            let dateStr = ISO8601DateFormatter().string(from: targetDate)
            let tv = Double(targetValueText)
            let goal = try await api.createGoal(.init(type: goalType, target_value: tv, target_date: String(dateStr.prefix(10))))
            _ = try await api.generateTasks(goalType: goal.type, targetValue: goal.target_value, targetDate: goal.target_date)
            onContinue()
        } catch {
            print("goal create error: \(error)")
        }
    }
}

#Preview {
    GoalSelectionView(onContinue: {})
        .environmentObject(APIClient())
        .environmentObject(AuthViewModel())
}
