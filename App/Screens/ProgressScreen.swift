import SwiftUI
import SwiftData
import Charts
import UniformTypeIdentifiers

struct ProgressScreen: View {
    @ObservedObject private var membership = Membership.shared
    @State private var window = 7
    @State private var exporting = false
    @State private var exportFailed = false
    @Query private var resets: [Reset]
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { clock in
            let calendar = Calendar.current
            let period = membership.premium == true ? window : 7
            let days = ((1 - period)...0).compactMap { calendar.date(byAdding: .day, value: $0, to: calendar.startOfDay(for: clock.date)) }
            let completed = resets.filter { item in item.completed.map { $0 >= (days.first ?? clock.date) && $0 <= clock.date } ?? false }
            Page(title: "Progress") {
                VStack(alignment: .leading, spacing: 8) {

                    if membership.premium == true {
                        Picker("History", selection: $window) {
                            Text("Last 7 days").tag(7)
                            Text("Last 30 days").tag(30)
                        }.pickerStyle(.segmented)
                    } else { Text("Last 7 days").font(.headline) }
                    Text("\(completed.count) resets").font(Theme.headline)
                    Text("\(completed.reduce(0) { $0 + $1.minutes }) minutes completed")
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(Theme.leaf).background(Theme.surface,in: RoundedRectangle(cornerRadius: 24))
                VStack(alignment: .leading, spacing: 16) {
                    Text("Daily completions").font(.headline)
                    Chart(days, id: \.self) { day in
                        let count = completed.filter { calendar.isDate($0.completed!, inSameDayAs: day) }.count
                        BarMark(x: .value("Day", day, unit: .day), y: .value("Resets", count)).foregroundStyle(Theme.leaf).cornerRadius(4)
                    }.chartYScale(domain: 0...max(completed.count, 1))
                    .chartXAxis { AxisMarks(values: days.enumerated().compactMap { $0.offset % (period == 7 ? 1 : 5) == 0 ? $0.element : nil }) { if period == 7 { AxisValueLabel(format: .dateTime.weekday(.narrow)) } else { AxisValueLabel(format: .dateTime.day()) } } }.frame(height: 160)
                }.panel()
                if membership.premium == true && !completed.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Activity by room").font(.headline)
                        let groups = Dictionary(grouping: completed, by: \.roomLabel)
                        ForEach(groups.keys.sorted(), id: \.self) { name in
                            HStack {
                                Text(verbatim: name)
                                Spacer()
                                Text("\(groups[name, default: []].reduce(0) { $0 + $1.minutes }) min")
                            }
                        }
                        Button { exporting = true } label: { Label("Export activity as CSV", systemImage: "square.and.arrow.up") }
                    }.panel()
                    .fileExporter(isPresented: $exporting, document: ActivityCSV(items: completed), contentType: .commaSeparatedText, defaultFilename: "Tidiva") { result in
                        if case .failure = result { exportFailed = true }
                    }.alert("Export failed", isPresented: $exportFailed) { Button("OK") {} }
                }
                if completed.isEmpty { Text("Finish a task to see your first activity here.").foregroundStyle(.secondary) }
            }
        }.browsingAdvertising()
    }
}

private struct ActivityCSV: FileDocument {
    static let readableContentTypes: [UTType] = [.commaSeparatedText]
    private let data: Data
    init(items: [Reset]) {
        let rows = items.compactMap { item -> String? in
            guard let date = item.completed else { return nil }
            let columns = [date.ISO8601Format(), item.roomLabel, NSLocalizedString(item.title, comment: ""), String(item.minutes)]
            return columns.map { value in
                let safe = value.first.map { "=+-@\t\r".contains($0) } == true ? "'" + value : value
                return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }.joined(separator: ",")
        }
        data = Data((["Date,Room,Task,Minutes"] + rows.sorted()).joined(separator: "\r\n").utf8)
    }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
