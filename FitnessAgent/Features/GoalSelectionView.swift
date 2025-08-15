import SwiftUI

struct GoalSelectionView: View {
    @EnvironmentObject private var api: APIClient
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var goalType: String = "weight_loss"
    @State private var targetValueText: String = ""
    @State private var targetDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var isSubmitting = false
    @State private var errorText: String?

    var onContinue: () -> Void

    var body: some View {
        ThemedBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    card {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Goal Type").font(.subheadline).foregroundStyle(AppTheme.textSecondary)
                            Picker("Goal Type", selection: $goalType) {
                                Text("Weight Loss").tag("weight_loss")
                                Text("Muscle Gain").tag("muscle_gain")
                                Text("Endurance").tag("endurance")
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    card {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Target").font(.subheadline).foregroundStyle(AppTheme.textSecondary)
                            TextField("Target value (optional)", text: $targetValueText)
                                .keyboardType(.decimalPad)
                                .padding(12)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(10)

                            DatePicker("Target date (optional)", selection: $targetDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                        }
                    }

                    Button(action: { Task { await createGoalAndGenerate() } }) {
                        HStack {
                            if isSubmitting { ProgressView().tint(.black) }
                            Text(isSubmitting ? "Working..." : "Continue")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.accent)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                    }
                    .disabled(isSubmitting)

                    if let errorText { Text(errorText).font(.footnote).foregroundStyle(.red) }
                }
                .padding(20)
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sign Out") { Task { await auth.signOut() } }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Set Your Goal")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text("Tell us what you want to achieve.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            Rectangle()
                .fill(AppTheme.accent.opacity(0.6))
                .frame(width: 56, height: 2)
                .cornerRadius(1)
        }
    }

    @ViewBuilder private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }

    private func createGoalAndGenerate() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorText = nil
        do {
            let dateStr = ISO8601DateFormatter().string(from: targetDate)
            let tv = Double(targetValueText)
            let goal = try await api.createGoal(.init(type: goalType, target_value: tv, target_date: String(dateStr.prefix(10))))

            // Navigate immediately after goal creation succeeds
            onContinue()
            dismiss()

            // Fire-and-forget task generation so navigation isn’t blocked
            Task.detached { [goalType, tv] in
                try? await api.generateTasks(goalType: goalType, targetValue: tv, targetDate: goal.target_date)
            }
        } catch {
            let nsErr = error as NSError
            // Treat user-cancelled network as non-fatal (common when views transition)
            if nsErr.domain == NSURLErrorDomain && nsErr.code == NSURLErrorCancelled {
                onContinue()
                dismiss()
            } else {
                errorText = error.localizedDescription
            }
        }
        isSubmitting = false
    }
}

#Preview {
    GoalSelectionView(onContinue: {})
        .environmentObject(APIClient())
        .environmentObject(AuthViewModel())
}
