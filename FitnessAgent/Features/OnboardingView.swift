import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var api: APIClient

    // MVP fields
    @State private var sex: String = ""
    @State private var dob: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var unitPref: String = "metric" // metric | imperial
    @State private var heightCm: String = ""
    @State private var weightKg: String = ""
    @State private var activityLevel: String = "moderate"
    @State private var fitnessLevel: String = "beginner"
    @State private var timezone: String = TimeZone.current.identifier

    @State private var isSaving = false
    @State private var errorMessage: String?

    var onComplete: () -> Void

    private var dobRange: ClosedRange<Date> {
        let now = Date()
        let min = Calendar.current.date(byAdding: .year, value: -120, to: now) ?? now
        return min...now
    }

    // Multi-step flow
    private enum Step: Int, CaseIterable { case sex, dob, units, body, fitness, activity, timezone, review }
    @State private var stepIndex: Int = 0
    private var step: Step { Step(rawValue: stepIndex) ?? .sex }
    private var progress: Double { Double(stepIndex + 1) / Double(Step.allCases.count) }

    var body: some View {
        ThemedBackground {
            VStack(spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    if #available(iOS 17.0, *) {
                        Image(systemName: "bolt.heart.fill")
                            .foregroundStyle(AppTheme.accent)
                            .font(.system(size: 24))
                            .symbolEffect(.pulse.byLayer, options: .repeating)
                    } else {
                        Image(systemName: "bolt.heart.fill")
                            .foregroundStyle(AppTheme.accent)
                            .font(.system(size: 24))
                    }
                    Text(titleForStep(step))
                        .font(.largeTitle.bold())
                    Spacer()
                }

                // Card container
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06)))
                    stepView(step)
                        .padding()
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 280)
                .animation(.easeInOut, value: stepIndex)

                if let err = errorMessage {
                    Text(err).foregroundColor(.red).font(.subheadline)
                }

                // Nav buttons
                HStack {
                    Button("Back") { withAnimation { stepIndex = max(0, stepIndex - 1) } }
                        .buttonStyle(.bordered)
                        .opacity(stepIndex == 0 ? 0 : 1)
                        .disabled(stepIndex == 0 || isSaving)
                    Spacer()
                    Button(stepIndex == Step.allCases.count - 1 ? "Finish" : "Next") {
                        Task { await nextTapped() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    .disabled(isSaving)
                }

                // Progress bar
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progress)
                        .tint(AppTheme.accent)
                    Text("Step \(stepIndex + 1) of \(Step.allCases.count)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(20)
            .navigationTitle("Onboarding")
        }
    }

    private func save() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        let payload = ProfileUpsert(
            sex: sex.isEmpty ? nil : sex,
            dob: formattedDob(),
            height_cm: Double(heightCm),
            weight_kg: Double(weightKg),
            unit_pref: unitPref,
            activity_level: activityLevel,
            fitness_level: fitnessLevel,
            resting_hr: nil,
            max_hr: nil,
            body_fat_pct: nil,
            medical_conditions: nil,
            injuries: nil,
            timezone: timezone,
            locale: Locale.current.identifier,
            availability_days: nil
        )

        do {
            _ = try await api.upsertProfile(payload)
            onComplete()
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }

    private func formattedDob() -> String? {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .iso8601)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: dob)
    }

    // MARK: - Step Helpers
    private func titleForStep(_ step: Step) -> String {
        switch step {
        case .sex: return "Who are you?"
        case .dob: return "Your birthday"
        case .units: return "Preferred units"
        case .body: return "Your body stats"
        case .fitness: return "Fitness level"
        case .activity: return "Activity level"
        case .timezone: return "Your timezone"
        case .review: return "Review & confirm"
        }
    }

    @ViewBuilder private func stepView(_ step: Step) -> some View {
        switch step {
        case .sex:
            VStack(alignment: .leading, spacing: 16) {
                Text("How do you identify?")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textSecondary)
                TagPicker(tags: ["male", "female", "other"], selection: $sex)
            }
            .padding()

        case .dob:
            VStack(alignment: .leading, spacing: 16) {
                Text("Select your date of birth")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textSecondary)
                DatePicker("Date of birth", selection: $dob, in: dobRange, displayedComponents: .date)
                    .datePickerStyle(.graphical)
            }
            .padding()

        case .units:
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose your units")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textSecondary)
                Picker("Units", selection: $unitPref) {
                    Text("Metric").tag("metric")
                    Text("Imperial").tag("imperial")
                }
                .pickerStyle(.segmented)
            }
            .padding()

        case .body:
            VStack(alignment: .leading, spacing: 16) {
                Text("Enter your body stats")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textSecondary)
                HStack {
                    TextField(unitPref == "metric" ? "Height (cm)" : "Height (in)", text: $heightCm)
                        .keyboardType(.decimalPad)
                    TextField(unitPref == "metric" ? "Weight (kg)" : "Weight (lb)", text: $weightKg)
                        .keyboardType(.decimalPad)
                }
            }
            .padding()

        case .fitness:
            VStack(alignment: .leading, spacing: 16) {
                Text("What is your fitness level?")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textSecondary)
                TagPicker(tags: ["beginner", "intermediate", "advanced"], selection: $fitnessLevel)
            }
            .padding()

        case .activity:
            VStack(alignment: .leading, spacing: 16) {
                Text("Typical daily activity")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textSecondary)
                TagPicker(tags: ["sedentary", "light", "moderate", "active", "very_active"], selection: $activityLevel)
            }
            .padding()

        case .timezone:
            VStack(alignment: .leading, spacing: 16) {
                Text("Confirm your timezone")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textSecondary)
                TextField("Timezone", text: $timezone)
                    .textInputAutocapitalization(.never)
            }
            .padding()

        case .review:
            VStack(alignment: .leading, spacing: 12) {
                Text("Review your info")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textSecondary)
                Group {
                    InfoRow(label: "Sex", value: sex)
                    InfoRow(label: "DOB", value: formattedDob() ?? "")
                    InfoRow(label: "Units", value: unitPref)
                    InfoRow(label: "Height", value: heightCm)
                    InfoRow(label: "Weight", value: weightKg)
                    InfoRow(label: "Fitness", value: fitnessLevel)
                    InfoRow(label: "Activity", value: activityLevel)
                    InfoRow(label: "Timezone", value: timezone)
                }
            }
            .padding()
        }
    }

    private func nextTapped() async {
        if stepIndex < Step.allCases.count - 1 {
            withAnimation { stepIndex += 1 }
        } else {
            await save()
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text(value)
        }
        .padding(.vertical, 4)
        .overlay(Divider(), alignment: .bottom)
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .environmentObject(APIClient())
}
