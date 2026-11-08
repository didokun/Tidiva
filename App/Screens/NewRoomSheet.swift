import SwiftUI

struct NewRoomSheet: View {
    let existing: [Room]
    let add: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var symbol = "square.grid.2x2"
    private let icons = [("square.grid.2x2", "Room"), ("sofa", "Living room"), ("bed.double", "Bedroom"),
                         ("fork.knife", "Kitchen"), ("shower", "Bathroom"), ("washer", "Laundry room"),
                         ("desktopcomputer", "Office"), ("hanger", "Walk-in closet"), ("car", "Garage"),
                         ("music.note", "Music"), ("leaf", "Garden"), ("puzzlepiece", "Playroom")]
    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var duplicate: Bool { existing.contains { $0.displayName.localizedCaseInsensitiveCompare(trimmed) == .orderedSame } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        Image(systemName: symbol).font(.title2).frame(width: 52, height: 52)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 15))
                        TextField("New room name", text: $name).textInputAutocapitalization(.words)
                    }.padding(14).background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
                    if duplicate { Text("This name is already used on this level.").font(.footnote) }
                    Text("Choose an icon").font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 49))], spacing: 10) {
                        ForEach(icons, id: \.0) { icon, label in
                            Button { symbol = icon } label: {
                                Image(systemName: icon).font(.title2).frame(maxWidth: .infinity, minHeight: 50)
                                    .foregroundStyle(symbol == icon ? Theme.ivory : Theme.ink)
                                    .background(symbol == icon ? Theme.pine : Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                            }.buttonStyle(.plain).accessibilityLabel(LocalizedStringKey(label))
                                .accessibilityAddTraits(symbol == icon ? .isSelected : [])
                        }
                    }
                    PrimaryButton(title: "Add a room", symbol: "plus") {
                        add(trimmed, symbol)
                        dismiss()
                    }.disabled(trimmed.isEmpty || duplicate).opacity(trimmed.isEmpty || duplicate ? 0.5 : 1)
                }.padding(20)
            }.background(Theme.paper).navigationTitle("Add a room").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }.tint(Theme.leaf).presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
}
