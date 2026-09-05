
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var session: SessionManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Welcome!")
                    .font(.largeTitle).bold()

                if let role = session.role {
                    Text("Role: \(role.rawValue.capitalized)")
                        .font(.headline)
                } else {
                    Text("Role: Unknown")
                        .font(.headline)
                }

                Button("Sign Out") {
                    Task { await session.signOut() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Home")
        }
    }
}

#Preview {
    MainView()
        .environmentObject(SessionManager())
}
