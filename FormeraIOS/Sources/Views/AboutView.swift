import SwiftUI

/// Shown from AppShellView's account menu so anyone can check which build
/// they're running -- handy when comparing a TestFlight build against what
/// was just uploaded.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var marketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Image("FormeraLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 60)
                Text("Formera")
                    .font(.title2.bold())
                Text("Version \(marketingVersion) (\(buildNumber))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.3)])
    }
}

#Preview {
    Text("").sheet(isPresented: .constant(true)) { AboutView() }
}
