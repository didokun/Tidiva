import SwiftUI

enum Theme {
    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat(rgb >> 16) / 255, green: CGFloat((rgb >> 8) & 255) / 255, blue: CGFloat(rgb & 255) / 255, alpha: 1)
        })
    }
    // Four logo colors: pine, fern, sage and ivory. Surface tints use opacity.
    static let pine = adaptive(0x05331F, 0x05331F)
    static let ivory = adaptive(0xF5EBD6, 0xF5EBD6)
    static let ink = adaptive(0x05331F, 0xF5EBD6)
    static let leaf = adaptive(0x426443, 0xA7BC89)
    static let mint = adaptive(0xA7BC89, 0xA7BC89).opacity(0.25)
    static let paper = adaptive(0xF5EBD6, 0x05331F)
    static let headline = Font.system(.largeTitle, design: .rounded).bold()


}

struct Page<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(LocalizedStringKey(title)).font(Theme.headline).accessibilityAddTraits(.isHeader)

                }
                content()
            }.frame(maxWidth: 610, alignment: .leading).padding(22).frame(maxWidth: .infinity)
        }.background(Theme.paper).foregroundStyle(Theme.ink)
    }
}

struct PrimaryButton: View {
    let title: String
    var symbol = "arrow.right"
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack { Text(LocalizedStringKey(title)); Spacer(); Image(systemName: symbol) }
                .font(.headline).padding(18).frame(maxWidth: .infinity)
                .foregroundStyle(Theme.ivory).background(Theme.pine, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
    }
}

extension View {
    func panel() -> some View {
        padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.mint, in: RoundedRectangle(cornerRadius: 20))
    }
}
