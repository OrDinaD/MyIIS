import XCTest
@testable import MyIIS

@MainActor
final class AttendanceViewModelTests: XCTestCase {
    
    // MARK: - Equivalence Partitioning & Boundary Value Analysis for inferredYear
    
    @MainActor func testInferredYear_MonthBeforeReference_ReturnsSameYear() {
        // Reference: June 2026 (Month 6)
        // Equivalence Class: month <= referenceMonth
        // Boundary values: 5, 6
        let referenceDate = createDate(year: 2026, month: 6)
        
        let year5 = AttendanceViewModel.inferredYear(forMonth: 5, referenceDate: referenceDate)
        XCTAssertEqual(year5, 2026, "Month 5 should be inferred as current year 2026")
        
        let year6 = AttendanceViewModel.inferredYear(forMonth: 6, referenceDate: referenceDate)
        XCTAssertEqual(year6, 2026, "Month 6 (boundary) should be inferred as current year 2026")
    }
    
    @MainActor func testInferredYear_MonthAfterReference_ReturnsPreviousYear() {
        // Reference: June 2026 (Month 6)
        // Equivalence Class: month > referenceMonth
        // Boundary value: 7
        let referenceDate = createDate(year: 2026, month: 6)
        
        let year7 = AttendanceViewModel.inferredYear(forMonth: 7, referenceDate: referenceDate)
        XCTAssertEqual(year7, 2025, "Month 7 (boundary) should be inferred as previous year 2025 since it's ahead of current month")
    }
    
    // MARK: - Equivalence Partitioning for MonthParser
    
    @MainActor func testMonthParser_TextWithYear_ReturnsMonthAndYear() {
        // Valid class: Text month with year
        let components1 = MonthParser.components(from: "Май 2023")
        XCTAssertEqual(components1?.month, 5)
        XCTAssertEqual(components1?.year, 2023)
        
        let components2 = MonthParser.components(from: "Сентябрь 2026 г.")
        XCTAssertEqual(components2?.month, 9)
        XCTAssertEqual(components2?.year, 2026)
    }
    
    @MainActor func testMonthParser_TextWithoutYear_ReturnsOnlyMonth() {
        // Valid class: Text month without year
        let components = MonthParser.components(from: "Октябрь")
        XCTAssertEqual(components?.month, 10)
        XCTAssertNil(components?.year, "Year should be nil when no digits are present")
    }
    
    @MainActor func testMonthParser_NumericFormats_ReturnsMonthAndYear() {
        // Valid classes: various numeric formats
        let formats = ["05.2023", "5.2023", "05/2023", "2023-05"]
        for format in formats {
            let components = MonthParser.components(from: format)
            XCTAssertEqual(components?.month, 5, "Failed to parse month for format \(format)")
            XCTAssertEqual(components?.year, 2023, "Failed to parse year for format \(format)")
        }
    }
    
    @MainActor func testMonthParser_InvalidFormat_ReturnsNil() {
        // Invalid class
        let components = MonthParser.components(from: "НепонятныйТекст")
        XCTAssertNil(components)
    }
    
    // MARK: - Integration logic for latestCount
    
    @MainActor func testLatestCount_ChronologicalOrder_ReturnsNewest() {
        let referenceDate = createDate(year: 2026, month: 6)
        
        let counts = [
            MonthlyOmissionCount(month: "Май", omissionCount: 10), // Inferred 2026
            MonthlyOmissionCount(month: "Сентябрь", omissionCount: 5) // Inferred 2025
        ]
        
        let resolved = AttendanceViewModel.resolvedCountsWithDates(counts, referenceDate: referenceDate)
        let sortedDates = resolved.sorted { $0.date < $1.date }
        
        // "Сентябрь" 2025 should be older than "Май" 2026
        XCTAssertEqual(sortedDates.last?.item.month, "Май")
    }
    
    // MARK: - Helpers
    
    private func createDate(year: Int, month: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 15
        return Calendar(identifier: .gregorian).date(from: components)!
    }
}
