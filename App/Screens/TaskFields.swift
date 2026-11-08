import SwiftUI

struct TaskFields: View {
    @Binding var title: String
    @Binding var icon: String
    @Binding var notes: String

    private let icons: [(symbol: String, label: LocalizedStringKey)] = [
        ("sparkles", "Cleaning"), ("drop", "Water"), ("basket", "Laundry"),
        ("tshirt", "Clothes"), ("fork.knife", "Kitchen"), ("leaf", "Garden"),
        ("archivebox", "Storage"), ("bed.double", "Bedroom")
    ]

    var body: some View {
        TextField("Task name", text: $title)
        VStack(alignment: .leading, spacing: 8) {
            Text("Task icon").font(.subheadline.bold())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 48))]) {
                ForEach(icons, id: \.symbol) { choice in
                    Button { icon = choice.symbol } label: {
                        Image(systemName: choice.symbol).font(.title3)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(icon == choice.symbol ? Theme.surface : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                            .overlay { if icon == choice.symbol { RoundedRectangle(cornerRadius: 10).stroke(Theme.leaf) } }
                    }.buttonStyle(.plain).accessibilityLabel(Text(choice.label))
                        .accessibilityAddTraits(icon == choice.symbol ? .isSelected : [])
                }
            }
        }
        TextField("Description (optional)", text: $notes, axis: .vertical).lineLimit(2...5)
    }
}
