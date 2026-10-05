import Charts
import SwiftUI

struct HeadmanJournalSummary: View {
    private struct Row: Identifiable {
        let id: Int
        let name: String
        let respectful: Int
        let other: Int
    }

    private let rows: [Row]
    private let totalRespectful: Int
    private let totalOther: Int

    init(students: [HeadmanJournalStudent], data: HeadmanJournalData) {
        let names = Dictionary(students.map { ($0.id, $0.fullName) }, uniquingKeysWith: { _, last in last })
        rows = data.attendance.map { attendance in
            let records = attendance.lessonRecords.values.compactMap { $0 }
            return Row(
                id: attendance.studentId,
                name: names[attendance.studentId] ?? String(localized: "Студент"),
                respectful: records.filter { $0.respectfulOmission == true }.reduce(0) { $0 + max($1.missedHours ?? 0, 0) },
                other: records.filter { $0.respectfulOmission != true }.reduce(0) { $0 + max($1.missedHours ?? 0, 0) }
            )
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        totalRespectful = rows.reduce(0) { $0 + $1.respectful }
        totalOther = rows.reduce(0) { $0 + $1.other }
    }

    var body: some View {
        Section {
            LabeledContent("По уважительной причине", value: "\(totalRespectful) ч")
            LabeledContent("По неуважительной причине", value: "\(totalOther) ч")
            if totalRespectful + totalOther > 0 {
                Chart {
                    BarMark(x: .value("Причина", String(localized: "Уважительная")),
                            y: .value("Часы", totalRespectful))
                        .foregroundStyle(Color.green)
                    BarMark(x: .value("Причина", String(localized: "Неуважительная")),
                            y: .value("Часы", totalOther))
                        .foregroundStyle(Color.orange)
                }
                .frame(height: 180)
                .accessibilityLabel("Пропущенные часы по выбранной дисциплине")
            }
        } header: {
            Text("Пропущенные часы")
        } footer: {
            Text("Сводка только по выбранному предмету и типу занятия. Пустые записи не подтверждают присутствие; процент посещаемости по ним не рассчитывается.")
        }
        Section("По студентам") {
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 5) {
                    Text(row.name)
                    Text("У: \(row.respectful) ч · Н: \(row.other) ч · Всего: \(row.respectful + row.other) ч")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
