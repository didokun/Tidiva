import SwiftUI
import StoreKit

@MainActor final class Membership: ObservableObject {
    static let shared = Membership()
    static let products = ["tidiva.premium.monthly", "tidiva.premium.yearly", "tidiva.premium.lifetime"]
    @Published private(set) var premium: Bool?
    func refresh() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, Self.products.contains(transaction.productID),
               transaction.revocationDate == nil, !transaction.isUpgraded { active = true }
        }
        premium = active
    }
    func observe() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result, Self.products.contains(transaction.productID) {
                await refresh()
                await transaction.finish()
            }
        }
    }
}

struct PremiumOptions: View {
    var onContinue: (() -> Void)? = nil
    @ObservedObject private var membership = Membership.shared
    @State private var catalog: [Product] = []
    @State private var selected = "tidiva.premium.monthly"
    @State private var busy = false
    @State private var message: LocalizedStringKey?
    @State private var loaded = false

    private var product: Product? { catalog.first { $0.id == selected } }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tidiva Premium").font(Theme.headline)
                    VStack(alignment: .leading, spacing: 12) {
                        perk("Ad-free Today", "sun.max")
                        perk("30-day activity history", "calendar")
                        perk("Activity by room", "house")
                        perk("Export activity as CSV", "square.and.arrow.up")
                    }.panel()
                    if membership.premium == true {
                        Label("Premium is active", systemImage: "checkmark.seal.fill")
                    } else {
                        ForEach(Membership.products, id: \.self) { id in
                            planRow(id)
                        }
                        if loaded && catalog.count < Membership.products.count {
                            Button("Reload prices") { Task { await load() } }
                        }
                        Text(selected.hasSuffix("lifetime") ? "One payment for lifetime access." : "Renews automatically until canceled.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("Restore purchases") { Task { await restore() } }.disabled(busy)
                    }
                    if let message { Text(message).font(.footnote) }
                }.padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(spacing: 3) {
                if membership.premium != true {
                    PrimaryButton(title: selected.hasSuffix("lifetime") ? "Get lifetime access" : "Subscribe to Premium", symbol: "arrow.right") {
                        Task { await buy() }
                    }.disabled(product == nil || busy).opacity(product == nil || busy ? 0.6 : 1)
                }
                if let onContinue {
                    Button(membership.premium == true ? "Done" : "Continue for free", action: onContinue)
                        .font(.subheadline).frame(minHeight: 44).disabled(busy)
                }
            }.padding(.vertical, 6)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await load() }
    }

    private func perk(_ title: LocalizedStringKey, _ icon: String) -> some View {
        Label(title, systemImage: icon).font(.subheadline.weight(.semibold))
    }

    private func planRow(_ id: String) -> some View {
        let item = catalog.first { $0.id == id }
        let monthly = id.hasSuffix("monthly")
        let title: LocalizedStringKey = monthly ? "Monthly" : id.hasSuffix("yearly") ? "Annual" : "Lifetime"
        return Button {
            selected = id
            message = nil
        } label: {
            HStack {
                Image(systemName: selected == id ? "checkmark.circle.fill" : "circle")
                Text(title).font(.headline)
                Spacer()
                if monthly, let item, item.priceFormatStyle.currencyCode == "USD", item.price == 5 {
                    Text(Decimal(10), format: item.priceFormatStyle).strikethrough().foregroundStyle(.secondary)
                }
                if let item { Text(item.displayPrice).font(.title3.bold()) }
                else { Text(loaded ? "Unavailable" : "Loading…").font(.caption) }
            }.padding(16).frame(maxWidth: .infinity)
            .background(selected == id ? Theme.mint : Color.clear, in: RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(Theme.leaf.opacity(selected == id ? 1 : 0.25)) }
            .contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(item == nil || busy)
        .accessibilityAddTraits(selected == id ? .isSelected : [])
    }

    private func load() async {
        catalog = (try? await Product.products(for: Membership.products)) ?? []
        if product == nil, let first = Membership.products.first(where: { id in catalog.contains { $0.id == id } }) {
            selected = first
        }
        loaded = true
    }

    private func buy() async {
        guard let product, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await membership.refresh()
                if membership.premium == true { onContinue?() }
            case .userCancelled: break
            case .pending: message = "Purchase pending approval."
            default: message = "Purchase could not be verified."
            }
        } catch { message = "Purchase could not be completed." }
    }

    private func restore() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try await AppStore.sync()
            await membership.refresh()
            if membership.premium != true { message = "No active purchase found." }
        } catch { message = "Couldn’t restore purchases." }
    }
}
