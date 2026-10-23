import SwiftUI

/// yeah carwright moscow rules
struct NameEntryView: View {
    @ObservedObject private var auth = AuthManager.shared
    @State private var name = ""
    @FocusState private var focused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Image(systemName: "person.crop.circle")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(Color(red: 0.35, green: 0.65, blue: 1.0))

            Text("What should we call you?")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Your name is saved with your account. You can change it later in Settings.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)

            TextField("", text: $name, prompt: Text("Your name").foregroundColor(.white.opacity(0.3)))
                .textContentType(.name)
                .submitLabel(.continue)
                .focused($focused)
                .font(.system(size: 17))
                .foregroundColor(.white)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.09)))
                .onChange(of: name) { _, newValue in
                    if newValue.count > 50 { name = String(newValue.prefix(50)) }
                }
                .onSubmit(save)

            Button(action: save) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Capsule().fill(trimmed.isEmpty ? Color.white.opacity(0.25) : Color.white))
                    .foregroundStyle(.black)
            }
            .disabled(trimmed.isEmpty)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
        .background(
            LinearGradient(colors: [Color(red: 0.055, green: 0.085, blue: 0.145), .black],
                           startPoint: .top, endPoint: .center).ignoresSafeArea()
        )
        .onAppear { focused = true }
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        auth.saveName(trimmed)
    }
}
/// aje patient le hu ayvi tyare hatta 
