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

    private static func calculateCanvasSize(for item: MessageShareItem, snapshot: MessageGradebookSnapshot) -> CGSize {
        var height: CGFloat = 1350
        switch item.kind {
        case .overall:
            height = 662 + CGFloat(snapshot.semesters.count) * 88 + 120
        case .semester(let semesterID):
            if let semester = snapshot.semester(id: semesterID) {
                height = 662 + CGFloat(semester.subjects.count) * 88 + 120
            }
        case .subject:
            height = 1350
        }
        return CGSize(width: 1080, height: max(height, 800))
    }

    private static func image(for item: MessageShareItem, snapshot: MessageGradebookSnapshot) -> UIImage {
        let size = calculateCanvasSize(for: item, snapshot: snapshot)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            drawBackground(in: rect, context: context)
            drawHeader(item: item, snapshot: snapshot, context: context)
            let finalY = drawMainContent(item: item, snapshot: snapshot)
            drawFooter(snapshot: snapshot, yPosition: finalY + 40)
        }
    }

    private static func drawBackground(in rect: CGRect, context: UIGraphicsImageRendererContext) {
        UIColor(red: 0.05, green: 0.07, blue: 0.08, alpha: 1).setFill()
        context.fill(rect)
    }

    private static func drawHeader(item: MessageShareItem, snapshot: MessageGradebookSnapshot, context: UIGraphicsImageRendererContext) {
        let iconRect = CGRect(x: 72, y: 72, width: 118, height: 118)
        
        context.cgContext.saveGState()
        let path = UIBezierPath(roundedRect: iconRect, cornerRadius: 24)
        path.addClip()
        if let appIcon = UIImage(named: "GradebookShareAppIcon") {
            appIcon.draw(in: iconRect)
        }
        context.cgContext.restoreGState()

        draw("MyIIS", in: CGRect(x: 218, y: 78, width: 500, height: 34), font: .systemFont(ofSize: 31, weight: .semibold), color: .secondaryLabel)
        draw(item.title, in: CGRect(x: 218, y: 118, width: 760, height: 62), font: .systemFont(ofSize: 55, weight: .heavy), color: .white)
        draw(item.subtitle, in: CGRect(x: 218, y: 188, width: 760, height: 72), font: .systemFont(ofSize: 27, weight: .medium), color: .secondaryLabel)

        draw("Зачетка \(snapshot.number)", in: CGRect(x: 72, y: 278, width: 420, height: 34), font: .systemFont(ofSize: 23, weight: .medium), color: .secondaryLabel)
    }

    private static func drawMainContent(item: MessageShareItem, snapshot: MessageGradebookSnapshot) -> CGFloat {
        switch item.kind {
        case .overall:
            return drawOverall(snapshot)
        case .semester(let semesterID):
            if let semester = snapshot.semester(id: semesterID) {
                return drawSemester(semester)
            }
            return 600
        case .subject(let semesterID, let subjectID):
            if let semester = snapshot.semester(id: semesterID), let subject = semester.subject(id: subjectID) {
                return drawSubject(subject, semester: semester)
            }
            return 600
        }
    }

    private static func drawOverall(_ snapshot: MessageGradebookSnapshot) -> CGFloat {
        metricCard(title: "Общий средний", value: snapshot.overallAverageText, rect: CGRect(x: 72, y: 354, width: 448, height: 170))
        metricCard(title: "Семестров", value: "\(snapshot.semesters.count)", rect: CGRect(x: 560, y: 354, width: 448, height: 170))

        drawSectionTitle("Семестры", verticalPosition: 590)
        var verticalPosition: CGFloat = 662
        for semester in snapshot.semesters.reversed() {
            row(title: semester.title, subtitle: "Предметов: \(semester.subjects.count)", value: semester.averageText, verticalPosition: verticalPosition)
            verticalPosition += 88
        }
        return verticalPosition
    }

    private static func drawSemester(_ semester: MessageGradebookSnapshot.Semester) -> CGFloat {
        metricCard(title: "Средний семестра", value: semester.averageText, rect: CGRect(x: 72, y: 354, width: 448, height: 170))
        metricCard(title: "Предметов", value: "\(semester.subjects.count)", rect: CGRect(x: 560, y: 354, width: 448, height: 170))

        drawSectionTitle("Предметы", verticalPosition: 590)
        var verticalPosition: CGFloat = 662
        for subject in semester.subjects {
            row(title: subject.abbreviation, subtitle: subject.fullName, value: subject.grade, verticalPosition: verticalPosition)
            verticalPosition += 88
        }
        return verticalPosition
    }

    private static func drawSubject(_ subject: MessageGradebookSnapshot.Subject, semester: MessageGradebookSnapshot.Semester) -> CGFloat {
        metricCard(title: "Оценка", value: subject.grade, rect: CGRect(x: 72, y: 354, width: 448, height: 170))
        metricCard(title: "Средний семестра", value: semester.averageText, rect: CGRect(x: 560, y: 354, width: 448, height: 170))

        drawSectionTitle(subject.abbreviation, verticalPosition: 590)
        draw(subject.fullName, in: CGRect(x: 72, y: 654, width: 936, height: 98), font: .systemFont(ofSize: 38, weight: .bold), color: .white)

        detail(title: "Форма контроля", value: subject.controlForm, verticalPosition: 800)
        detail(title: "Средний за 4 года", value: subject.averageText, verticalPosition: 888)
        detail(title: "Пересдачи", value: subject.retakesText, verticalPosition: 976)
        detail(title: "Дата", value: subject.dateText, verticalPosition: 1064)
        detail(title: "Преподаватель", value: subject.teacherText, verticalPosition: 1152)
        return 1240
    }

    private static func drawFooter(snapshot: MessageGradebookSnapshot, yPosition: CGFloat) {
        let text = "Сформировано в MyIIS · данные от \(snapshot.updatedAt.formatted(date: .numeric, time: .shortened))"
        draw(text, in: CGRect(x: 72, y: yPosition, width: 936, height: 34), font: .systemFont(ofSize: 22, weight: .medium), color: .tertiaryLabel)
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
