import Foundation

struct TestFailure: Error {
    let message: String
}

func assert(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String) throws {
    if !condition() {
        throw TestFailure(message: message())
    }
}

@main
enum GradebookDeserializationTest {
    static func main() {
        do {
            let fileURL = URL(fileURLWithPath: "Tests/Fixtures/gradebook_response.json")
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let gradebook = try decoder.decode(Gradebook.self, from: data)
            let normalized = gradebook.normalized()

            try assert(normalized.semesters.count == 2, "Ожидалось два семестра")
            try assert(normalized.semesters.map { $0.number } == [6, 5], "Семестры должны быть отсортированы по убыванию номера")

            let latestSemester = normalized.semesters[0]
            let disciplineNames = latestSemester.disciplines.map { $0.name }
            try assert(disciplineNames == ["Искусственный интеллект", "Математический анализ"], "Дисциплины должны сортироваться по убыванию оценки")

            let previousSemester = normalized.semesters[1]
            guard let algorithms = previousSemester.disciplines.first(where: { $0.code == "ALG101" }) else {
                throw TestFailure(message: "Не найдена дисциплина Алгоритмы")
            }

            try assert(algorithms.bestGradeValue == 9, "Лучшая оценка по Алгоритмам должна быть 9")
            try assert(algorithms.sortedAttempts.map { $0.attempt } == [1, 2], "Попытки должны сортироваться по номеру")

            guard let average = normalized.averageGrade else {
                throw TestFailure(message: "Не удалось вычислить средний балл")
            }

            let expectedAverage = 9.1666666667
            try assert(abs(average - expectedAverage) < 0.0001, "Средний балл вычислен неверно: \(average)")

            print("Gradebook deserialization test passed")
        } catch {
            fputs("Gradebook deserialization test failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
