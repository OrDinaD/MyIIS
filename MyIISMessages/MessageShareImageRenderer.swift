import Foundation
import SwiftUI
import UIKit

enum MessageShareImageRenderer {
    private static let canvasSize = CGSize(width: 1080, height: 1350)

    static func renderPNG(for item: MessageShareItem, snapshot: MessageGradebookSnapshot) throws -> URL {
        let image = image(for: item, snapshot: snapshot)
        guard let data = image.pngData() else {
            throw MessageShareImageError.renderingFailed
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(item.fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func image(for item: MessageShareItem, snapshot: MessageGradebookSnapshot) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: canvasSize)
            drawBackground(in: rect, context: context)
            drawHeader(item: item, snapshot: snapshot)
            drawMainContent(item: item, snapshot: snapshot)
            drawFooter(snapshot: snapshot)
        }
    }

    private static func drawBackground(in rect: CGRect, context: UIGraphicsImageRendererContext) {
        UIColor(red: 0.05, green: 0.07, blue: 0.08, alpha: 1).setFill()
        context.fill(rect)

        let topGlow = UIColor(red: 0.00, green: 0.52, blue: 0.46, alpha: 0.42).cgColor
        let blueGlow = UIColor(red: 0.22, green: 0.28, blue: 0.70, alpha: 0.34).cgColor
        let clear = UIColor.clear.cgColor
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        if let gradient = CGGradient(colorsSpace: colorSpace, colors: [topGlow, clear] as CFArray, locations: [0, 1]) {
            context.cgContext.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: 120, y: 120),
                startRadius: 0,
                endCenter: CGPoint(x: 120, y: 120),
                endRadius: 780,
                options: []
            )
        }

        if let gradient = CGGradient(colorsSpace: colorSpace, colors: [blueGlow, clear] as CFArray, locations: [0, 1]) {
            context.cgContext.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: 980, y: 260),
                startRadius: 0,
                endCenter: CGPoint(x: 980, y: 260),
                endRadius: 720,
                options: []
            )
        }
    }

    private static func drawHeader(item: MessageShareItem, snapshot: MessageGradebookSnapshot) {
        let accent = UIColor(item.accent)
        let iconRect = CGRect(x: 72, y: 72, width: 118, height: 118)
        roundedRect(iconRect, radius: 30, fill: accent)

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 58, weight: .bold)
        let symbol = UIImage(systemName: item.symbolName, withConfiguration: symbolConfig)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        symbol?.draw(in: iconRect.insetBy(dx: 27, dy: 27))

        draw("MyIIS", in: CGRect(x: 218, y: 78, width: 500, height: 34), font: .systemFont(ofSize: 31, weight: .semibold), color: .secondaryLabel)
        draw(item.title, in: CGRect(x: 218, y: 118, width: 620, height: 62), font: .systemFont(ofSize: 55, weight: .heavy), color: .white)
        draw(item.subtitle, in: CGRect(x: 218, y: 188, width: 760, height: 72), font: .systemFont(ofSize: 27, weight: .medium), color: .secondaryLabel)

        draw("PNG", in: CGRect(x: 880, y: 82, width: 104, height: 44), font: .systemFont(ofSize: 29, weight: .heavy), color: accent)
        roundedStroke(CGRect(x: 858, y: 70, width: 142, height: 62), radius: 28, stroke: accent.withAlphaComponent(0.65))

        draw("Зачетка \(snapshot.number)", in: CGRect(x: 72, y: 278, width: 420, height: 34), font: .systemFont(ofSize: 23, weight: .medium), color: .secondaryLabel)
    }

    private static func drawMainContent(item: MessageShareItem, snapshot: MessageGradebookSnapshot) {
        switch item.kind {
        case .overall:
            drawOverall(snapshot)
        case .semester(let semesterID):
            if let semester = snapshot.semester(id: semesterID) {
                drawSemester(semester)
            }
        case .subject(let semesterID, let subjectID):
            if let semester = snapshot.semester(id: semesterID), let subject = semester.subject(id: subjectID) {
                drawSubject(subject, semester: semester)
            }
        }
    }

    private static func drawOverall(_ snapshot: MessageGradebookSnapshot) {
        metricCard(title: "Общий средний", value: snapshot.overallAverageText, rect: CGRect(x: 72, y: 354, width: 448, height: 170))
        metricCard(title: "Семестров", value: "\(snapshot.semesters.count)", rect: CGRect(x: 560, y: 354, width: 448, height: 170))

        drawSectionTitle("Семестры", verticalPosition: 590)
        var verticalPosition: CGFloat = 662
        for semester in snapshot.semesters.reversed().prefix(8) {
            row(title: semester.title, subtitle: "Предметов: \(semester.subjects.count)", value: semester.averageText, verticalPosition: verticalPosition)
            verticalPosition += 88
        }
    }

    private static func drawSemester(_ semester: MessageGradebookSnapshot.Semester) {
        metricCard(title: "Средний семестра", value: semester.averageText, rect: CGRect(x: 72, y: 354, width: 448, height: 170))
        metricCard(title: "Предметов", value: "\(semester.subjects.count)", rect: CGRect(x: 560, y: 354, width: 448, height: 170))

        drawSectionTitle("Предметы", verticalPosition: 590)
        var verticalPosition: CGFloat = 662
        for subject in semester.subjects.prefix(8) {
            row(title: subject.abbreviation, subtitle: subject.fullName, value: subject.grade, verticalPosition: verticalPosition)
            verticalPosition += 88
        }
        if semester.subjects.count > 8 {
            draw(
                "Еще \(semester.subjects.count - 8) предметов",
                in: CGRect(x: 96, y: verticalPosition + 12, width: 860, height: 34),
                font: .systemFont(ofSize: 24, weight: .medium),
                color: .secondaryLabel
            )
        }
    }

    private static func drawSubject(_ subject: MessageGradebookSnapshot.Subject, semester: MessageGradebookSnapshot.Semester) {
        metricCard(title: "Оценка", value: subject.grade, rect: CGRect(x: 72, y: 354, width: 448, height: 170))
        metricCard(title: "Средний семестра", value: semester.averageText, rect: CGRect(x: 560, y: 354, width: 448, height: 170))

        drawSectionTitle(subject.abbreviation, verticalPosition: 590)
        draw(subject.fullName, in: CGRect(x: 72, y: 654, width: 936, height: 98), font: .systemFont(ofSize: 38, weight: .bold), color: .white)

        detail(title: "Форма контроля", value: subject.controlForm, verticalPosition: 800)
        detail(title: "Средний за 4 года", value: subject.averageText, verticalPosition: 888)
        detail(title: "Пересдачи", value: subject.retakesText, verticalPosition: 976)
        detail(title: "Дата", value: subject.dateText, verticalPosition: 1064)
        detail(title: "Преподаватель", value: subject.teacherText, verticalPosition: 1152)
    }

    private static func drawFooter(snapshot: MessageGradebookSnapshot) {
        let text = "Сформировано в MyIIS · данные от \(snapshot.updatedAt.formatted(date: .numeric, time: .shortened))"
        draw(text, in: CGRect(x: 72, y: 1260, width: 936, height: 34), font: .systemFont(ofSize: 22, weight: .medium), color: .tertiaryLabel)
    }

    private static func metricCard(title: String, value: String, rect: CGRect) {
        roundedRect(rect, radius: 28, fill: UIColor.white.withAlphaComponent(0.10))
        roundedStroke(rect, radius: 28, stroke: UIColor.white.withAlphaComponent(0.13))
        draw(title, in: rect.insetBy(dx: 28, dy: 26), font: .systemFont(ofSize: 24, weight: .medium), color: .secondaryLabel)
        draw(
            value,
            in: CGRect(x: rect.minX + 28, y: rect.minY + 76, width: rect.width - 56, height: 62),
            font: .monospacedDigitSystemFont(ofSize: 54, weight: .heavy),
            color: .white
        )
    }

    private static func drawSectionTitle(_ title: String, verticalPosition: CGFloat) {
        draw(
            title,
            in: CGRect(x: 72, y: verticalPosition, width: 936, height: 48),
            font: .systemFont(ofSize: 38, weight: .heavy),
            color: .white
        )
    }

    private static func row(title: String, subtitle: String, value: String, verticalPosition: CGFloat) {
        let rect = CGRect(x: 72, y: verticalPosition, width: 936, height: 72)
        roundedRect(rect, radius: 22, fill: UIColor.white.withAlphaComponent(0.08))
        draw(
            title,
            in: CGRect(x: 96, y: verticalPosition + 13, width: 540, height: 30),
            font: .systemFont(ofSize: 27, weight: .bold),
            color: .white
        )
        draw(
            subtitle,
            in: CGRect(x: 96, y: verticalPosition + 43, width: 620, height: 24),
            font: .systemFont(ofSize: 19, weight: .medium),
            color: .secondaryLabel
        )
        draw(
            value,
            in: CGRect(x: 770, y: verticalPosition + 18, width: 190, height: 38),
            font: .monospacedDigitSystemFont(ofSize: 31, weight: .bold),
            color: .white,
            alignment: .right
        )
    }

    private static func detail(title: String, value: String, verticalPosition: CGFloat) {
        draw(
            title,
            in: CGRect(x: 72, y: verticalPosition, width: 340, height: 32),
            font: .systemFont(ofSize: 24, weight: .medium),
            color: .secondaryLabel
        )
        draw(
            value,
            in: CGRect(x: 420, y: verticalPosition - 4, width: 588, height: 48),
            font: .systemFont(ofSize: 29, weight: .bold),
            color: .white,
            alignment: .right
        )
    }

    private static func roundedRect(_ rect: CGRect, radius: CGFloat, fill: UIColor) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        fill.setFill()
        path.fill()
    }

    private static func roundedStroke(_ rect: CGRect, radius: CGFloat, stroke: UIColor) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        stroke.setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }

    private static func draw(_ text: String, in rect: CGRect, font: UIFont, color: UIColor, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.alignment = alignment
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        text.draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attributes, context: nil)
    }
}

enum MessageShareImageError: LocalizedError {
    case renderingFailed

    var errorDescription: String? {
        "Не удалось подготовить PNG для iMessage."
    }
}
