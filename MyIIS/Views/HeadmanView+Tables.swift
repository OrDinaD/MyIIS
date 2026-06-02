import SwiftUI

struct SummaryTable: View {
    let students: [HeadmanSummaryStudent]
    let responsibleStudentIDs: Set<Int>
    private let numberColumnWidth: CGFloat = 44
    private let nameColumnWidth: CGFloat = 240
    private let totalColumnWidth: CGFloat = 64
    private let dateColumnWidth: CGFloat = 62

    private var dates: [String] {
        Array(Set(students.flatMap { student in
            student.lessons.map(\.dateString)
        })).sorted(by: SummaryTable.compareDateStrings)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: 0) {
                summaryHeader
                ForEach(Array(students.enumerated()), id: \.element.id) { index, student in
                    summaryRow(index: index + 1, student: student)
                }
            }
            .font(.footnote)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            )
            .padding(.vertical, 4)
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: 0) {
            cell("№", width: numberColumnWidth, isHeader: true, rowBackground: Color(uiColor: .tertiarySystemFill))
            cell("ФИО", width: nameColumnWidth, isHeader: true, alignment: .leading, rowBackground: Color(uiColor: .tertiarySystemFill))
            cell("Часы", width: totalColumnWidth, isHeader: true, rowBackground: Color(uiColor: .tertiarySystemFill))
            ForEach(dates, id: \.self) { date in
                cell(
                    String(date.prefix(5)),
                    width: dateColumnWidth,
                    isHeader: true,
                    rowBackground: Color(uiColor: .tertiarySystemFill)
                )
            }
        }
    }

    private func summaryRow(index: Int, student: HeadmanSummaryStudent) -> some View {
        let rowBackground = (index % 2 == 0) ? Color(uiColor: .systemGray6).opacity(0.4) : Color.clear
        return HStack(spacing: 0) {
            cell(String(index), width: numberColumnWidth, rowBackground: rowBackground)
            cell(
                student.fio,
                width: nameColumnWidth,
                alignment: .leading,
                isResponsible: responsibleStudentIDs.contains(student.id),
                rowBackground: rowBackground
            )
            cell(String(student.totalMissedHours), width: totalColumnWidth, rowBackground: rowBackground)
            ForEach(dates, id: \.self) { date in
                let aggregate = aggregateForDate(date, student: student)
                cell(
                    aggregate.text,
                    width: dateColumnWidth,
                    foreground: aggregate.color,
                    rowBackground: rowBackground
                )
            }
        }
    }

    private func cell(
        _ text: String,
        width: CGFloat,
        isHeader: Bool = false,
        alignment: Alignment = .center,
        foreground: Color = .primary,
        isResponsible: Bool = false,
        rowBackground: Color = .clear
    ) -> some View {
        Text(text)
            .fontWeight(isHeader ? .semibold : .regular)
            .foregroundColor(isHeader ? .secondary : foreground)
            .lineLimit(2)
            .frame(width: width, alignment: alignment)
            .frame(minHeight: 36)
            .padding(.horizontal, 6)
            .background(
                Group {
                    if isResponsible {
                        Color.yellow.opacity(0.16)
                    } else {
                        rowBackground
                    }
                }
            )
            .overlay(alignment: .bottom) {
                Divider()
            }
            .overlay(alignment: .trailing) {
                Divider()
            }
    }

}

struct WeeklySummaryTable: View {
    let students: [HeadmanWeeklyStudentSummary]
    let responsibleStudentIDs: Set<Int>

    private let numberColumnWidth: CGFloat = 44
    private let nameColumnWidth: CGFloat = 220
    private let valueColumnWidth: CGFloat = 56
    private let totalColumnWidth: CGFloat = 70

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: 0) {
                headerRow
                ForEach(Array(students.enumerated()), id: \.element.id) { index, student in
                    dataRow(index: index + 1, student: student)
                }
            }
            .font(.footnote)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            )
            .padding(.vertical, 4)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            cell("№", width: numberColumnWidth, isHeader: true)
            cell("ФИО", width: nameColumnWidth, isHeader: true, alignment: .leading)
            cell("Ув ЛК", width: valueColumnWidth, isHeader: true)
            cell("Ув ЛР", width: valueColumnWidth, isHeader: true)
            cell("Ув ПЗ", width: valueColumnWidth, isHeader: true)
            cell("Ув Σ", width: totalColumnWidth, isHeader: true)
            cell("Неув ЛК", width: valueColumnWidth, isHeader: true)
            cell("Неув ЛР", width: valueColumnWidth, isHeader: true)
            cell("Неув ПЗ", width: valueColumnWidth, isHeader: true)
            cell("Неув Σ", width: totalColumnWidth, isHeader: true)
        }
    }

    private func dataRow(index: Int, student: HeadmanWeeklyStudentSummary) -> some View {
        let rowBackground = (index % 2 == 0) ? Color(uiColor: .systemGray6).opacity(0.4) : Color.clear
        return HStack(spacing: 0) {
            cell("\(index)", width: numberColumnWidth, rowBackground: rowBackground)
            cell(
                student.fio,
                width: nameColumnWidth,
                alignment: .leading,
                isResponsible: responsibleStudentIDs.contains(student.id),
                rowBackground: rowBackground
            )
            cell("\(student.totals.respectfulHours(for: .lecture))", width: valueColumnWidth, foreground: .green, rowBackground: rowBackground)
            cell("\(student.totals.respectfulHours(for: .lab))", width: valueColumnWidth, foreground: .green, rowBackground: rowBackground)
            cell("\(student.totals.respectfulHours(for: .practice))", width: valueColumnWidth, foreground: .green, rowBackground: rowBackground)
            cell("\(student.totals.respectfulTotal)", width: totalColumnWidth, foreground: .green, rowBackground: rowBackground)
            cell("\(student.totals.unrespectfulHours(for: .lecture))", width: valueColumnWidth, foreground: .red, rowBackground: rowBackground)
            cell("\(student.totals.unrespectfulHours(for: .lab))", width: valueColumnWidth, foreground: .red, rowBackground: rowBackground)
            cell("\(student.totals.unrespectfulHours(for: .practice))", width: valueColumnWidth, foreground: .red, rowBackground: rowBackground)
            cell("\(student.totals.unrespectfulTotal)", width: totalColumnWidth, foreground: .red, rowBackground: rowBackground)
        }
    }

    private func cell(
        _ text: String,
        width: CGFloat,
        isHeader: Bool = false,
        alignment: Alignment = .center,
        foreground: Color = .primary,
        isResponsible: Bool = false,
        rowBackground: Color = Color(uiColor: .tertiarySystemFill)
    ) -> some View {
        Text(text)
            .fontWeight(isHeader ? .semibold : .regular)
            .foregroundStyle(isHeader ? .secondary : foreground)
            .lineLimit(2)
            .frame(width: width, alignment: alignment)
            .frame(minHeight: 36)
            .padding(.horizontal, 6)
            .background(
                Group {
                    if isResponsible {
                        Color.yellow.opacity(0.16)
                    } else if isHeader {
                        Color(uiColor: .tertiarySystemFill)
                    } else {
                        rowBackground
                    }
                }
            )
            .overlay(alignment: .bottom) {
                Divider()
            }
            .overlay(alignment: .trailing) {
                Divider()
            }
    }
}
