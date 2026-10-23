import SwiftUI
struct LegalDocumentView: View {
    let title: String
    let bodyText: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(bodyText)
                    .font(.system(.body, design: .default))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    LegalDocumentView(title: "Privacy Policy", bodyText: LegalDocumentText.privacyPolicy)
}
