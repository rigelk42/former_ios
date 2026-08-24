import SwiftUI

/// Mirrors web's DashboardPage.tsx, which is itself just a placeholder
/// heading today -- there's no dashboard aggregation endpoint on the
/// backend yet, so this stays a stub for parity rather than inventing new
/// charts/metrics as part of the migration.
struct DashboardView: View {
    var body: some View {
        Text("Dashboard")
            .font(.largeTitle.bold())
            .foregroundStyle(Color.accentColor)
            .navigationTitle("Dashboard")
    }
}

#Preview {
    NavigationStack { DashboardView() }
}
