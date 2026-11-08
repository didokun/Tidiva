import SwiftUI
import SwiftData

@main struct TidivaApp: App {
    private let container: ModelContainer? = {
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("-sampleHome") {
            return try? sampleContainer()
        }
        #endif
        // Preserve the existing store name so the rebrand does not abandon local data.
        let config = ModelConfiguration("HomeReset", cloudKitDatabase: .none)
        return try? ModelContainer(for: Reset.self, configurations: config)
    }()
    @MainActor private static func sampleContainer() throws -> ModelContainer {
        let container = try ModelContainer(for: Reset.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        try Reset.seed(in: container.mainContext)
        let items = try container.mainContext.fetch(FetchDescriptor<Reset>(sortBy: [SortDescriptor(\.scheduled)]))
        items.first?.completed = .now
        return container
    }
    var body: some Scene {
        WindowGroup {
            if let container { Dashboard().modelContainer(container) }
            else { ContentUnavailableView("Storage unavailable", systemImage: "externaldrive", description: Text("Check available storage and reopen Tidiva.")) }
        }
    }
}

struct Dashboard: View {
    @AppStorage("tidiva.onboardingComplete") private var ready = false
    @Environment(\.scenePhase) private var phase
    @State var tab = 0
    @State private var settings = false
    var body: some View {
        Group {
            if ready {
                TabView(selection: $tab) {
                    NavigationStack { TodayScreen().toolbar { settingsButton } }
                        .tabItem { Label("Today", systemImage: "sun.max") }.tag(0)
                    NavigationStack { TaskCalendarScreen() }.tabItem { Label("Calendar", systemImage: "calendar") }.tag(4)
                    RoomsScreen().tabItem { Label("My Home", systemImage: "house") }.tag(1)
                    NavigationStack { PlannerScreen() }.tabItem { Label("Routines", systemImage: "books.vertical") }.tag(2)
                    NavigationStack { ProgressScreen() }.tabItem { Label("Progress", systemImage: "chart.bar") }.tag(3)
                }.tint(Theme.leaf)
            } else { OnboardingScreen { ready = true } }
        }.sheet(isPresented: $settings) { SettingsScreen {
            settings = false
            tab = 0
            ready = false
        } }
        .task { await Membership.shared.observe() }
        .task(id: phase) { if phase == .active { await Membership.shared.refresh() } }
    }
    private var settingsButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { settings = true } label: { Image(systemName: "gearshape") }
                .foregroundStyle(Theme.leaf).accessibilityLabel("Settings")
        }
    }
}

@MainActor private struct SamplePreview<Content: View>: View {
    let container: ModelContainer
    let content: Content

    init(@ViewBuilder content: () -> Content) throws {
        container = try ModelContainer(for: Reset.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        try Reset.seed(in: container.mainContext)
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Sample home").font(.caption).foregroundStyle(.secondary)
            content
        }.modelContainer(container)
    }
}

#Preview("Today · Sample home") { try! SamplePreview { NavigationStack { TodayScreen() } } }
#Preview("My Home · Sample home") { try! SamplePreview { RoomsScreen() } }
#Preview("AI Planner · Sample home") { try! SamplePreview { NavigationStack { PlannerScreen() } } }
#Preview("Progress · Sample home") { try! SamplePreview { NavigationStack { ProgressScreen() } } }
#Preview("Welcome") { OnboardingScreen {} }
