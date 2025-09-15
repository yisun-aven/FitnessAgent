import SwiftUI
import Foundation

// MARK: - ViewModel for Goals
@MainActor
final class HomeViewModel: ObservableObject {
  @Published var goals: [Goal] = []
  @Published var isLoading = false
  @Published var showingAdd = false
  @Published var isCreating = false // block UI when generating tasks
  @Published var lastCreatedGoalId: String? = nil
  @Published var overallProgress: Double = 0 // 0..1
  @Published var overallTaskTotal: Int = 0

  private weak var api: APIClient?

  func configure(api: APIClient) { self.api = api }

  func loadGoals() async {
    guard let api else { return }
    isLoading = true
    defer { isLoading = false }
    do { goals = try await api.listGoals() } catch { /* TODO: surface error */ }
    await computeOverallTotals()
  }

  /// Create goal then wait until server finishes generating tasks before surfacing it in UI.
  func createGoalAndAwaitTasks(type: String, targetDate: Date?) async {
    guard let api else { return }
    isCreating = true
    defer { isCreating = false }

    // Format date to YYYY-MM-DD
    let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
    let dateStr = targetDate.map { fmt.string(from: $0) }

    do {
      let created = try await api.createGoal(GoalCreate(type: type, target_value: nil, target_date: dateStr))
      self.lastCreatedGoalId = created.id

      // Poll until tasks exist (server generates them asynchronously)
      for _ in 0..<10 { // up to ~10s
        do {
          let tasks = try await api.listGoalTasks(goalId: created.id)
          if !tasks.isEmpty { break }
        } catch { /* ignore during polling */ }
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
      }

      await loadGoals()
    } catch {
      // TODO: present error
    }
  }

  /// Fetch total tasks count across all goals and compute overall progress.
  private func computeOverallTotals() async {
    guard let api else { return }
    var total = 0
    for g in goals {
      do {
        let tasks = try await api.listGoalTasks(goalId: g.id)
        total += tasks.count
      } catch {
        // ignore errors for individual goals
      }
    }
    overallTaskTotal = total
    // We don't track completed counts yet; so progress is 0 / total
    overallProgress = 0
  }
}

struct Home: View {
  @EnvironmentObject private var api: APIClient
  @StateObject private var vm = HomeViewModel()
  @State private var addType: String = "Build Muscle"
  @State private var addDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
  @State private var expandedGoalId: String? = nil

  var body: some View {
    ZStack() {
      Group {
        Rectangle()
          .foregroundColor(.clear)
          .frame(width: 354, height: 68)
          .background(Color(red: 0.17, green: 0.17, blue: 0.17))
          .cornerRadius(20)
          .offset(x: 0, y: -249)
        Rectangle()
          .foregroundColor(.clear)
          .frame(width: 40, height: 68)
          .background(Color(red: 0.24, green: 0.23, blue: 0.23))
          .cornerRadius(20)
          .offset(x: -157, y: -249)
        // Rotated month text inside the left rounded calendar segment
        ZStack {
          Text("12.2025")
            .font(Font.custom("Prompt", size: 10).weight(.medium))
            .tracking(0.50)
            .lineSpacing(10)
            .foregroundColor(.white)
            .rotationEffect(.degrees(90))
        }
        .frame(width: 40, height: 68)
        .offset(x: -157, y: -249)
        EmptyView()
      }
      // Thin divider line under the goal cards (matches Figma Vector 1 at y≈626)
      Rectangle()
        .fill(Color.white.opacity(0.15))
        .frame(width: 320, height: 1)
        .offset(x: -0.5, y: 213)
      Group {
        VStack(alignment: .leading, spacing: -6) {
          Text("Welcome Back")
            .foregroundColor(.white)
          Text("Christine")
            .foregroundColor(Color(red: 0.58, green: 1.00, blue: 0.99))
        }
        .font(Font.custom("Franie Test", size: 30).weight(.medium))
        .lineSpacing(0)
        // Constrain to frame width and align left to match Figma
        .frame(width: 327, alignment: .leading)
        .offset(x: -13.50, y: -328.50)
        Text("My Goal")
          .font(Font.custom("Franie Test", size: 30).weight(.medium))
          .lineSpacing(32)
          .foregroundColor(.white)
          .frame(width: 327, alignment: .leading)
          .offset(x: -13.50, y: -16)
          .zIndex(100)
      }
      Group {
        Rectangle()
          .foregroundColor(.clear)
          .frame(width: 354, height: 149)
          .background(Color(red: 0.17, green: 0.17, blue: 0.17))
          .cornerRadius(20)
          .offset(x: 0, y: -131.50)
        Rectangle()
          .foregroundColor(.clear)
          .frame(width: 30, height: 30)
          .background(Color(red: 0.59, green: 1, blue: 0.99))
          .cornerRadius(15)
          .offset(x: -113, y: -240)
        Text("SUN")
          .font(Font.custom("Prompt", size: 8).weight(.medium))
          .tracking(0.50)
          .lineSpacing(8)
          .foregroundColor(.white)
          .offset(x: -113, y: -263.50)
        Text("21")
          .font(Font.custom("Prompt", size: 16).weight(.semibold))
          .lineSpacing(16)
          .foregroundColor(.black)
          .offset(x: -113, y: -240.50)
        Rectangle()
          .foregroundColor(.clear)
          .frame(width: 30, height: 30)
          .background(Color(red: 0.59, green: 1, blue: 0.99))
          .cornerRadius(15)
          .offset(x: -69, y: -240)
        Text("MON")
          .font(Font.custom("Prompt", size: 8).weight(.medium))
          .tracking(0.50)
          .lineSpacing(8)
          .foregroundColor(.white)
          .offset(x: -69, y: -263.50)
        Text("22")
          .font(Font.custom("Prompt", size: 16).weight(.semibold))
          .lineSpacing(16)
          .foregroundColor(.black)
          .offset(x: -69, y: -240.50)
        Rectangle()
          .foregroundColor(.clear)
          .frame(width: 30, height: 30)
          .background(Color(red: 0.59, green: 1, blue: 0.99))
          .cornerRadius(15)
          .offset(x: -25, y: -240)
        Text("TUE")
          .font(Font.custom("Prompt", size: 8).weight(.medium))
          .tracking(0.50)
          .lineSpacing(8)
          .foregroundColor(.white)
          .offset(x: -25, y: -263.50)
        Text("23")
          .font(Font.custom("Prompt", size: 16).weight(.semibold))
          .lineSpacing(16)
          .foregroundColor(.black)
          .offset(x: -25, y: -240.50)
      }
      Group {
        Rectangle()
          .foregroundColor(.clear)
          .frame(width: 30, height: 30)
          .cornerRadius(15)
          .offset(x: 63, y: -240)
        Text("THUR")
          .font(Font.custom("Prompt", size: 8).weight(.medium))
          .tracking(0.50)
          .lineSpacing(8)
          .foregroundColor(.white)
          .offset(x: 63, y: -263.50)
        Text("25")
          .font(Font.custom("Prompt", size: 16).weight(.semibold))
          .lineSpacing(16)
          .foregroundColor(.white)
          .offset(x: 63, y: -240.50)
        Rectangle()
          .foregroundColor(.clear)
          .frame(width: 30, height: 30)
          .cornerRadius(15)
          .offset(x: 107, y: -240)
        Text("FRI")
          .font(Font.custom("Prompt", size: 8).weight(.medium))
          .tracking(0.50)
          .lineSpacing(8)
          .foregroundColor(.white)
          .offset(x: 107, y: -263.50)
        Text("26")
          .font(Font.custom("Prompt", size: 16).weight(.semibold))
          .lineSpacing(16)
          .foregroundColor(.white)
          .offset(x: 107, y: -240.50)
        Rectangle()
          .foregroundColor(.clear)
          .frame(width: 30, height: 30)
          .cornerRadius(15)
          .offset(x: 151, y: -240)
        Text("SAT")
          .font(Font.custom("Prompt", size: 8).weight(.medium))
          .tracking(0.50)
          .lineSpacing(8)
          .foregroundColor(.white)
          .offset(x: 151, y: -263.50)
        Text("27")
          .font(Font.custom("Prompt", size: 16).weight(.semibold))
          .lineSpacing(16)
          .foregroundColor(.white)
          .offset(x: 151, y: -240.50)
        Rectangle()
          .foregroundColor(.clear)
          .frame(width: 30, height: 54)
          .background(Color(red: 0.59, green: 1, blue: 0.99))
          .cornerRadius(15)
          .offset(x: 19, y: -249)
      }
      Group {
        Text("WED")
          .font(Font.custom("Prompt", size: 8).weight(.medium))
          .tracking(0.50)
          .lineSpacing(8)
          .foregroundColor(.black)
          .offset(x: 19, y: -263.50)
        Text("24")
          .font(Font.custom("Prompt", size: 16).weight(.semibold))
          .lineSpacing(16)
          .foregroundColor(.black)
          .offset(x: 19, y: -240.50)
        ZStack {
          // Summary container matching card width
          RoundedRectangle(cornerRadius: 20)
            .fill(Color(red: 0.17, green: 0.17, blue: 0.17))
            .frame(width: 354, height: 120)

          // Content aligned to 16pt from the top-left, like goal titles
          HStack(alignment: .top) {
            Text("Your Progress")
              .font(Font.custom("Prompt", size: 16).weight(.medium))
              .tracking(0.50)
              .lineSpacing(10)
              .foregroundColor(.white)
              .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            ZStack {
              // Gauge parameters
              let startTrim: CGFloat = 0.15   // 15% of circle
              let endTrim: CGFloat = 0.85     // 85% of circle (gap at bottom)
              let span: CGFloat = endTrim - startTrim
              // Ensure a small visible arc even at 0%
              let visualProgress = max(0.0005, vm.overallProgress) // 0.5% min
              let progressEnd: CGFloat = startTrim + span * CGFloat(visualProgress)

              // Track (light) with rounded ends, arc only
              Circle()
                .trim(from: startTrim, to: endTrim)
                .stroke(Color(red: 0.90, green: 0.98, blue: 0.98), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .frame(width: 88, height: 88)
                .rotationEffect(.degrees(90)) // put the gap at the bottom

              // Progress arc within the same span
              Circle()
                .trim(from: startTrim, to: progressEnd)
                .stroke(Color(red: 0.59, green: 1, blue: 0.99), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .frame(width: 88, height: 88)
                .rotationEffect(.degrees(90))

              Text("\(Int(vm.overallProgress * 100))%")
                .font(Font.custom("Prompt", size: 22).weight(.medium))
                .tracking(0.50)
                .lineSpacing(22)
                .foregroundColor(.white)
            }
            .frame(width: 88, height: 88, alignment: .center) // guarantees equal top/bottom inside padded area
            .padding(.top, 4) // nudge down slightly to match label's top spacing visually
          }
          .padding(16) // 16pt from top and left, matching cards
          .frame(width: 354, height: 120, alignment: .topLeading)
        }
        .offset(x: 0, y: -140)
        Rectangle()
          .foregroundColor(.clear)
          .frame(width: 4, height: 4)
          .background(Color(red: 0.59, green: 1, blue: 0.99))
          .cornerRadius(15)
          .offset(x: 63, y: -227)
        Rectangle()
          .foregroundColor(.clear)
          .frame(width: 4, height: 4)
          .background(Color(red: 0.59, green: 1, blue: 0.99))
          .cornerRadius(15)
          .offset(x: 151, y: -227)
        Button(action: { vm.showingAdd = true }) {
          ZStack {
            Circle()
              .fill(Color(red: 0.17, green: 0.17, blue: 0.17))
              .frame(width: 40, height: 40)
            Image(systemName: "plus")
              .font(.system(size: 18, weight: .semibold))
              .foregroundColor(Color(red: 0.58, green: 1.00, blue: 0.99)) // #95FFFD
          }
        }
        .buttonStyle(PlainButtonStyle())
        .offset(x: 155, y: -17)
        .zIndex(100)
        // Dynamic goals list (wallet-style stacking) inside a ScrollView.
        ScrollView(.vertical, showsIndicators: false) {
          VStack(spacing: 0) {
            if vm.goals.isEmpty {
              Text("No goals yet. Tap + to add one.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.65))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 12)
            } else {
              // Chronological order: oldest first (bottom), newest last (top)
              let sorted = vm.goals.sorted { $0.created_at < $1.created_at }
              ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, goal in
                let isExpanded = expandedGoalId == goal.id
                GoalCardView(goal: goal, isExpanded: isExpanded)
                  .padding(.top, idx == 0 ? 0 : -44) // overlap like Wallet
                  .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                      if expandedGoalId == goal.id {
                        // Tapping the expanded card collapses it
                        expandedGoalId = nil
                      } else {
                        // Tapping another card expands that one
                        expandedGoalId = goal.id
                      }
                    }
                  }
                  .zIndex(Double(idx)) // preserve order; expanded does not jump above following cards
              }
            }
            // small bottom padding so content can scroll past the floating tab bar
            Color.clear.frame(height: 60)
          }
          .frame(width: 354, alignment: .top)
          .padding(.top, 8)
        }
        .frame(width: 354)
        .zIndex(0) // list stays below header and plus
        .offset(x: 0, y: 360) // push further below 'My Goal' section
      }
      // Hide static goal mocks beneath; dynamic list above will render instead
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
    .task { vm.configure(api: api); await vm.loadGoals() }
    // Auto-expand the newest goal on first load and after creation
    .onChange(of: vm.goals.count) { _, _ in
      let newest = vm.goals.sorted { $0.created_at < $1.created_at }.last
      if expandedGoalId == nil { expandedGoalId = newest?.id }
    }
    .onChange(of: vm.lastCreatedGoalId) { _, newId in
      if let id = newId { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { expandedGoalId = id } }
    }
    .sheet(isPresented: $vm.showingAdd) {
      AddGoalSheet(isPresented: $vm.showingAdd) { type, date in
        Task { await vm.createGoalAndAwaitTasks(type: type, targetDate: date) }
      }
    }
    .overlay {
      if vm.isCreating {
        ZStack {
          Color.black.opacity(0.4).ignoresSafeArea()
          VStack(spacing: 12) {
            ProgressView().tint(Color(red: 0.58, green: 1.00, blue: 0.99))
            Text("Generating tasks... please wait")
              .foregroundColor(.white)
              .font(.system(size: 14))
          }
          .padding(16)
          .background(Color.black.opacity(0.7))
          .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .transition(.opacity)
      }
    }
    .disabled(vm.isCreating)
  }
}

// MARK: - Dynamic Goal Card
private struct GoalCardView: View {
  let goal: Goal
  var isExpanded: Bool

  private func bgColor(for type: String) -> Color {
    switch type.lowercased() {
    case "build muscle": return Color(red: 0.77, green: 0.63, blue: 1)
    case "sculpt body": return Color(red: 1, green: 0.71, blue: 0.71)
    case "fat loss": return Color(red: 0.58, green: 0.86, blue: 1)
    case "endurance": return Color(red: 0.65, green: 0.85, blue: 0.75)
    default: return Color(red: 0.35, green: 0.35, blue: 0.35)
    }
  }

  private func progressColor(for type: String) -> Color {
    switch type.lowercased() {
    case "build muscle":
      return Color(red: 0.62, green: 0.48, blue: 0.98) // purple
    case "sculpt body":
      return Color(red: 1.00, green: 0.50, blue: 0.55) // coral/red
    case "fat loss":
      return Color(red: 0.33, green: 0.70, blue: 1.00) // blue
    case "endurance":
      return Color(red: 0.4157, green: 0.6196, blue: 0.349) // teal
    default:
      return Color.blue.opacity(0.8)
    }
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: 20)
        .fill(bgColor(for: goal.type))
        .frame(height: isExpanded ? 200 : 100)
        .shadow(color: Color.black.opacity(0.15), radius: isExpanded ? 10 : 4, y: isExpanded ? 6 : 2)

      VStack(alignment: .leading, spacing: isExpanded ? 12 : 6) {
        // Header row: goal title on the left, due date + progress on the right
        HStack(spacing: 12) {
          Text(goal.type)
            .font(Font.custom("Franie Test", size: 16).weight(.semibold))
            .foregroundColor(.black)

          Spacer(minLength: 12)

          if let date = goal.target_date, !date.isEmpty {
            Text(date.uppercased())
              .font(Font.custom("Prompt", size: 8).weight(.semibold))
              .foregroundColor(.black.opacity(0.6))
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .background(Color.white.opacity(0.5))
              .clipShape(Capsule())
          }

          // Compact progress bar on the same line with percentage text
          let pct = Double((goal.id.hashValue & 0xFF) % 90 + 10) / 100.0
          GeometryReader { geo in
            let containerW = geo.size.width
            let fillW = max(36, containerW * pct) // ensure room for text
            ZStack(alignment: .leading) {
              Capsule().fill(Color.white.opacity(0.5))
              Capsule().fill(progressColor(for: goal.type))
                .frame(width: fillW)
                .overlay(
                  Text("\(Int(pct * 100))%")
                    .font(Font.custom("Prompt", size: 10).weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: fillW, height: 20, alignment: .center)
                , alignment: .leading)
            }
          }
          .frame(width: 96, height: 20)
        }

        if isExpanded {
          // Expanded-only detail area below the header row
          RoundedRectangle(cornerRadius: 10)
            .fill(Color.white.opacity(0.3))
            .frame(height: 2)
        }
      }
      .padding(16)
    }
  }
}

// MARK: - Add Goal Sheet
private struct AddGoalSheet: View {
  @Binding var isPresented: Bool
  var onSave: (String, Date?) -> Void

  @State private var goalType: String = "Build Muscle"
  @State private var dueDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()

  private let types = ["Build Muscle", "Sculpt Body", "Fat Loss", "Endurance"]

  var body: some View {
    NavigationView {
      Form {
        Picker("Goal Type", selection: $goalType) {
          ForEach(types, id: \.self) { Text($0) }
        }
        DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
      }
      .navigationTitle("New Goal")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { onSave(goalType, dueDate); isPresented = false }
        }
      }
    }
  }
}

#Preview {
    Home()
}