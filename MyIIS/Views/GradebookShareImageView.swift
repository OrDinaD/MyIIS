import SwiftUI
import UIKit

struct GradebookShareSnapshot {
    let number: String
    let semesterKey: String
    let semesterAverageText: String
    let overallAverageText: String
    let generatedAt: Date
    let subjects: [GradebookShareSubject]

    var semesterTitle: String {
        String(format: NSLocalizedString("gradebook_share_semester_format", comment: ""), semesterKey)
    }
}

struct GradebookShareSubject: Identifiable {
    let id: String
    let abbreviation: String
    let fullName: String
    let controlForm: String
    let grade: String
    let averageText: String
    let retakesText: String
}

struct GradebookShareImagePayload: Identifiable {
    let id = UUID()
    let url: URL
    let image: UIImage
}

@MainActor
enum GradebookShareImageExporter {
    static func renderPNG(snapshot: GradebookShareSnapshot) async throws -> GradebookShareImagePayload {
        let imageView = GradebookShareImageView(snapshot: snapshot)
            .frame(width: GradebookShareImageView.canvasWidth)
            .fixedSize(horizontal: false, vertical: true)

        let renderer = ImageRenderer(content: imageView)
        renderer.scale = 1

        guard let image = renderer.uiImage else {
            throw GradebookShareImageExportError.renderingFailed
        }

        let fileName = "myiis-gradebook-semester-\(snapshot.semesterKey.sanitizedForFileName).png"
        let url = try await Task.detached(priority: .userInitiated) { () -> URL in
            guard let data = image.pngData() else {
                throw GradebookShareImageExportError.renderingFailed
            }
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        }.value

        return GradebookShareImagePayload(url: url, image: image)
    }
}

enum GradebookShareImageExportError: LocalizedError {
    case renderingFailed

    var errorDescription: String? {
        NSLocalizedString("gradebook_share_render_failed", comment: "")
    }
}

struct GradebookShareImageView: View {
    static let canvasWidth: CGFloat = 1080

    let snapshot: GradebookShareSnapshot

    private var formattedDate: String {
        snapshot.generatedAt.formatted(
            .dateTime.day().month(.wide).year().hour().minute()
                .locale(Locale.current)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 34) {
            header
            summaryStrip
            subjectsList
            footer
        }
        .padding(48)
        .frame(width: Self.canvasWidth, alignment: .topLeading)
        .background(Color.white)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 26) {
            Image("GradebookShareAppIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 118, height: 118)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: .black.opacity(0.20), radius: 18, x: 0, y: 10)

            VStack(alignment: .leading, spacing: 12) {
                Text("MyIIS")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(NSLocalizedString("gradebook_share_title", comment: ""))
                    .font(.system(size: 74, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.08, green: 0.11, blue: 0.13))
                Text(snapshot.semesterTitle)
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.18, green: 0.25, blue: 0.26))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                Text(NSLocalizedString("gradebook_share_number", comment: ""))
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(snapshot.number)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(red: 0.08, green: 0.11, blue: 0.13))
            }
            .padding(.top, 8)
        }
    }

    private var summaryStrip: some View {
        HStack(spacing: 18) {
            GradebookShareSummaryCard(
                title: NSLocalizedString("gradebook_share_semester_average", comment: ""),
                value: snapshot.semesterAverageText,
                iconName: "chart.bar.fill",
                tint: Color(red: 0.0, green: 0.46, blue: 0.40)
            )
            GradebookShareSummaryCard(
                title: NSLocalizedString("gradebook_share_overall_average", comment: ""),
                value: snapshot.overallAverageText,
                iconName: "graduationcap.fill",
                tint: Color(red: 0.73, green: 0.42, blue: 0.09)
            )
            GradebookShareSummaryCard(
                title: NSLocalizedString("gradebook_share_subjects", comment: ""),
                value: "\(snapshot.subjects.count)",
                iconName: "books.vertical.fill",
                tint: Color(red: 0.25, green: 0.30, blue: 0.63)
            )
        }
    }

    private var subjectsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(snapshot.subjects) { subject in
                GradebookShareSubjectRow(subject: subject)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text(NSLocalizedString("gradebook_share_generated", comment: ""))
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Text(formattedDate)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.18, green: 0.25, blue: 0.26))
            Spacer()
        }
        .padding(.top, 2)
    }
}

private struct GradebookShareSummaryCard: View {
    let title: String
    let value: String
    let iconName: String
    let tint: Color

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: iconName)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 56, height: 56)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(red: 0.08, green: 0.11, blue: 0.13))
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.22), lineWidth: 1)
        }
    }
}

private struct GradebookShareSubjectRow: View {
    let subject: GradebookShareSubject

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(subject.abbreviation)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.08, green: 0.11, blue: 0.13))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text(subject.fullName)
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.30, green: 0.36, blue: 0.38))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 420, alignment: .leading)

            GradebookShareMetric(title: NSLocalizedString("gradebook_share_control", comment: ""), value: subject.controlForm)
            GradebookShareMetric(title: NSLocalizedString("gradebook_share_grade", comment: ""), value: subject.grade, isProminent: true)
            GradebookShareMetric(title: NSLocalizedString("gradebook_share_average", comment: ""), value: subject.averageText)
            GradebookShareMetric(title: NSLocalizedString("gradebook_share_retakes", comment: ""), value: subject.retakesText)
        }
        .padding(22)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color(red: 0.0, green: 0.46, blue: 0.40))
                .frame(width: 5)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        }
    }
}

private struct GradebookShareMetric: View {
    let title: String
    let value: String
    var isProminent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(value)
                .font(.system(size: isProminent ? 27 : 23, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isProminent ? Color(red: 0.0, green: 0.40, blue: 0.35) : Color(red: 0.12, green: 0.16, blue: 0.18))
                .lineLimit(2)
                .minimumScaleFactor(0.65)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 118, alignment: .topLeading)
    }
}

private extension String {
    var sanitizedForFileName: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let value = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return value.isEmpty ? "semester" : value
    }
}

#if DEBUG
private extension GradebookShareSnapshot {
    static var preview: GradebookShareSnapshot {
        GradebookShareSnapshot(
            number: "42850012",
            semesterKey: "3",
            semesterAverageText: "10.00",
            overallAverageText: "9.59",
            generatedAt: Date(timeIntervalSince1970: 1_766_880_000),
            subjects: [
                GradebookShareSubject(
                    id: "1",
                    abbreviation: "АПЭЦ",
                    fullName: "Автоматизированное проектирование электрических цепей",
                    controlForm: "Зачет",
                    grade: "зач",
                    averageText: "—",
                    retakesText: "0"
                ),
                GradebookShareSubject(
                    id: "2",
                    abbreviation: "ООП",
                    fullName: "Объектно-ориентированное программирование",
                    controlForm: "Курс. работа",
                    grade: "10",
                    averageText: "7.49",
                    retakesText: "0 (2.5%)"
                ),
                GradebookShareSubject(
                    id: "3",
                    abbreviation: "МПиАЯП",
                    fullName: "Методы программирования и анализа языков программирования",
                    controlForm: "Экзамен",
                    grade: "9",
                    averageText: "8.21",
                    retakesText: "1 (4.0%)"
                )
            ]
        )
    }
}

#Preview {
    GradebookShareImageView(snapshot: .preview)
        .scaleEffect(0.32, anchor: .top)
        .frame(width: GradebookShareImageView.canvasWidth * 0.32, height: 620, alignment: .top)
        .padding(18)
        .background(Color(uiColor: .systemGroupedBackground))
}
#endif
