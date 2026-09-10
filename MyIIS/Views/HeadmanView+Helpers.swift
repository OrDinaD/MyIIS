import SwiftUI

extension SummaryTable {
    nonisolated static func compareDateStrings(_ lhs: String, _ rhs: String) -> Bool {
        let lhsParts = lhs.split(separator: ".")
        let rhsParts = rhs.split(separator: ".")
        if lhsParts.count == 3, rhsParts.count == 3,
           let lDay = Int(lhsParts[0]), let lMonth = Int(lhsParts[1]), let lYear = Int(lhsParts[2]),
           let rDay = Int(rhsParts[0]), let rMonth = Int(rhsParts[1]), let rYear = Int(rhsParts[2]) {
            if lYear != rYear { return lYear < rYear }
            if lMonth != rMonth { return lMonth < rMonth }
            return lDay < rDay
        }
        return lhs < rhs
    }

    func aggregateForDate(_ date: String, student: HeadmanSummaryStudent) -> (text: String, color: Color) {
        let lessons = student.lessons.filter { $0.dateString == date }
        guard !lessons.isEmpty else {
            return ("", .primary)
        }

        let totalHours = lessons.reduce(0) { $0 + $1.gradeBookOmissions }
        guard totalHours > 0 else {
            return ("", .primary)
        }

        let hasNonRespectful = lessons.contains {
            $0.gradeBookOmissions > 0 && !$0.isRespectfulOmission
        }
        return (String(totalHours), hasNonRespectful ? .red : .green)
    }
}

struct ResponsibleStudentRow: View {
    let student: HeadmanStudent
    @Bindable var viewModel: HeadmanViewModel

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(student.fio)
                    .font(.body)
                Text(student.username)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.updatingResponsibleIDs.contains(student.id) {
                ProgressView()
            } else {
                Toggle("", isOn: Binding(
                    get: { viewModel.responsibleStudentIDs.contains(student.id) },
                    set: { value in Task { await viewModel.setResponsible(value, for: student) } }
                ))
                .labelsHidden()
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(viewModel.responsibleStudentIDs.contains(student.id) ? Color.yellow.opacity(0.12) : nil)
    }
}

#Preview {
    NavigationStack {
        HeadmanView()
    }
}
