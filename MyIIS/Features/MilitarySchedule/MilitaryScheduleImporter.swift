import SwiftUI
import UniformTypeIdentifiers
import JavaScriptCore

@MainActor
struct MilitaryScheduleImportButton: View {
    @ObservedObject var viewModel: ScheduleServiceViewModel
    @State private var isImporterPresented = false
    @State private var isParsing = false
    
    var body: some View {
        Button(action: {
            isImporterPresented = true
        }) {
            HStack {
                if isParsing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Image(systemName: "square.and.arrow.down")
                }
                Text(
                    isParsing
                        ? NSLocalizedString("common_loading", comment: "")
                        : NSLocalizedString("services_schedule_import_file", comment: "")
                )
            }
            .font(.subheadline)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .foregroundColor(.primary)
            .cornerRadius(13)
        }
        .disabled(isParsing)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.json, .spreadsheet]
        ) { result in
            switch result {
            case .success(let url):
                parseAndApplySchedule(from: url)
            case .failure(let error):
                viewModel.errorMessage = "Ошибка выбора файла: \(error.localizedDescription)"
            }
        }
    }
    
    private func parseAndApplySchedule(from url: URL) {
        let gainedAccess = url.startAccessingSecurityScopedResource()
        isParsing = true

        Task {
            defer {
                if gainedAccess {
                    url.stopAccessingSecurityScopedResource()
                }
                isParsing = false
            }

            do {
                let data = try Data(contentsOf: url)

                if url.pathExtension.lowercased() == "json" {
                    let document = try LocalScheduleStore.decode(data).updatingTimestamp()
                    try LocalScheduleStore.save(document)

                    let snapshot = document.widgetSnapshot()
                    ClassScheduleWidgetDataStore.save(snapshot)
                    WatchScheduleConnectivityService.shared.activate()
                    WatchScheduleConnectivityService.shared.send(snapshot)

                    viewModel.dataSource = .localJSON
                    viewModel.noticeMessage = NSLocalizedString("local_schedule_import_success", comment: "")
                    return
                }

                let b64 = data.base64EncodedString()
                let parsedJSON = try await parseXLS(b64: b64)
                let jsonData = try buildPublicScheduleResponseJSON(from: parsedJSON)
                let response = try JSONDecoder().decode(PublicScheduleResponse.self, from: jsonData)

                // Save to cache for offline support
                try cacheSchedule(jsonData, group: "534104")

                viewModel.applyGroupSchedule(response, week: nil, groupNumber: "534104")
                viewModel.noticeMessage = "Расписание ВУЦ успешно загружено"
            } catch {
                viewModel.errorMessage = "\(NSLocalizedString("common_error", comment: "")): \(error.localizedDescription)"
            }
        }
    }
    
    private func parseXLS(b64: String) async throws -> [[String]] {
        guard let jsPath = Bundle.main.path(forResource: "xlsx_full_min", ofType: "js"),
              let jsCode = try? String(contentsOfFile: jsPath, encoding: .utf8) else {
            throw NSError(domain: "MilitaryImporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "JS библиотека SheetJS не найдена в бандле (xlsx_full_min.js)"])
        }
        
        guard let context = JSContext() else {
            throw NSError(domain: "MilitaryImporter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать JSContext"])
        }
        
        context.evaluateScript(jsCode)
        
        let parseJS = """
        function parseXLS(b64) {
            var wb = XLSX.read(b64, {type: 'base64'});
            var sheet = wb.Sheets[wb.SheetNames[0]];
            var json = XLSX.utils.sheet_to_json(sheet, {header: 1, defval: ""});
            for (var i = 0; i < json.length; i++) {
                for (var j = 0; j < json[i].length; j++) {
                    json[i][j] = json[i][j] + "";
                }
            }
            return json;
        }
        """
        context.evaluateScript(parseJS)
        
        guard let parseFunc = context.objectForKeyedSubscript("parseXLS"), !parseFunc.isUndefined else {
            throw NSError(domain: "MilitaryImporter", code: 3, userInfo: [NSLocalizedDescriptionKey: "Функция парсинга не инициализировалась"])
        }
        
        guard let result = parseFunc.call(withArguments: [b64]) else {
            throw NSError(domain: "MilitaryImporter", code: 4, userInfo: [NSLocalizedDescriptionKey: "JS вернул null"])
        }
        
        if result.isUndefined {
            throw NSError(domain: "MilitaryImporter", code: 5, userInfo: [NSLocalizedDescriptionKey: "Ошибка парсинга файла SheetJS"])
        }
        
        guard let array = result.toArray() as? [[String]] else {
            throw NSError(domain: "MilitaryImporter", code: 6, userInfo: [NSLocalizedDescriptionKey: "Неверный формат данных от JS"])
        }
        
        return array
    }
    
    private func buildPublicScheduleResponseJSON(from array: [[String]]) throws -> Data {
        var targetRow = -1
        for (i, row) in array.enumerated() {
            if row.count > 1 && row[1].contains("534104") {
                targetRow = i
                break
            }
        }
        
        guard targetRow != -1 else {
            throw NSError(domain: "MilitaryImporter", code: 7, userInfo: [NSLocalizedDescriptionKey: "Группа 534104 не найдена в расписании"])
        }
        
        let pairTimes = [
            ("08:30", "09:55"),
            ("10:05", "11:30"),
            ("12:00", "13:25"),
            ("13:35", "15:00"),
            ("15:30", "16:55")
        ]
        
        let weekdays = ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота"]
        var schedulesMap: [String: [Any]] = [:]
        
        let startDayCol = 3
        
        for (dayIndex, weekday) in weekdays.enumerated() {
            var dayLessons: [Any] = []
            let colOffset = startDayCol + dayIndex * 3
            
            for pairIndex in 0..<5 {
                let r = targetRow + pairIndex
                if r < array.count {
                    let row = array[r]
                    if colOffset + 2 < row.count {
                        let subject = row[colOffset].trimmingCharacters(in: .whitespacesAndNewlines)
                        let teacher = row[colOffset + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                        let location = row[colOffset + 2].trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if !subject.isEmpty {
                            let (startT, endT) = pairTimes[pairIndex]
                            let dateStr = "0\(dayIndex+6).07.2026"
                            let lessonId = UUID().uuidString
                            
                            let lesson: [String: Any] = [
                                "id": lessonId,
                                "auditories": [location],
                                "endLessonTime": endT,
                                "lessonTypeAbbrev": "ПЗ",
                                "numSubgroup": 0,
                                "startLessonTime": startT,
                                "studentGroups": [
                                    ["name": "534104", "facultyId": 0, "facultyName": "Военный факультет", "specialityName": "ВК", "course": 4]
                                ],
                                "subject": subject,
                                "subjectFullName": subject,
                                "weekNumber": [0],
                                "employees": [
                                    ["id": 0, "fio": teacher, "firstName": "", "lastName": "", "middleName": "", "photoLink": ""]
                                ],
                                "dateLesson": dateStr,
                                "startLessonDate": dateStr,
                                "endLessonDate": dateStr,
                                "announcement": false,
                                "split": false
                            ]
                            dayLessons.append(lesson)
                        }
                    }
                }
            }
            schedulesMap[weekday] = dayLessons
        }
        
        let jsonDict: [String: Any] = [
            "studentGroupDto": [
                "name": "534104", "facultyId": 0, "facultyAbbrev": "ВФ", "facultyName": "Военный факультет", "specialityName": "Военная кафедра", "specialityAbbrev": "ВК", "course": 4
            ],
            "schedules": schedulesMap,
            "startDate": "06.07.2026",
            "endDate": "12.07.2026"
        ]
        
        return try JSONSerialization.data(withJSONObject: jsonDict)
    }
    
    private struct FakeCachedEnvelope: Codable {
        let data: Data
        let cachedAt: Date
    }
    
    private func cacheSchedule(_ jsonData: Data, group: String) throws {
        let envelope = FakeCachedEnvelope(data: jsonData, cachedAt: Date())
        let payload = try JSONEncoder().encode(envelope)
        let key = "api_cache_" + Data("GET|https://iis.bsuir.by/api/v1/schedule?studentGroup=\(group)".utf8).base64EncodedString()
        _ = UserDefaultsPayloadStore.save(payload, forKey: key, in: .standard)
    }
}
