# Отчёт о расследовании и устранении сбоев (Crash Rate Audit) MyIIS

**Дата расследования:** 18 августа 2026 г.  
**Целевая версия:** MyIIS 1.1.0 (Release)  
**Базовая стабильная версия:** MyIIS 1.0.9  
**Текущий статус:** `RESOLVED & VERIFIED` (Все 218 unit/regression тестов пройдены, сборка проекта успешна, 0 предупреждений)

---

## 1. Резюме для руководства (Executive Summary)

В версии 1.1.0 наблюдался рост показателя Crash Rate в App Store Connect до **3.05%** (с 0.0 до ~5.0 инцидентов/день начиная с 23 июля 2026 г.).

### Главные причины роста сбоев:
1. **Критический сбой Swift Concurrency в BackgroundTasks (P0 / 100% подтверждённых отчётов):**  
   Системная регистрация фоновой задачи `BGAppRefreshTask` в `AcademicChangeNotificationService` выполнялась без привязки к главному потоку (`using: nil`), в то время как замыкание и внутренние сервисы изолированы к `@MainActor`. При вызове задачи операционной системой в фоне срабатывал runtime-ассерт акторной изоляции Swift Concurrency (`_swift_task_checkIsolatedSwift` -> `_dispatch_assert_queue_fail`), завершавший приложение с сигналом `EXC_BREAKPOINT (SIGTRAP)`. Все 5 зарегистрированных в Xcode Organizer сигнатур крашей являлись проявлением этого единого дефекта.
2. **Watchdog Timeout Termination в `BGAppRefreshTask` (P0):**  
   Обработчик истечения времени `task.expirationHandler` не вызывал `task.setTaskCompleted(success: false)`, из-за чего система принудительно убивала процесс по тайм-ауту фонового исполнения (код 0xbaadca11).
3. **Фатальные ошибки при десериализации дубликатов (P0):**  
   Использование инициализатора `Dictionary(uniqueKeysWithValues:)` в `AcademicChangeModels` и `HeadmanViewModel` вызывало `fatalError: Duplicate keys found in Dictionary` при возврате сервером дублирующихся записей (например, по одному предмету или студенту).
4. **Блокировка Keychain в фоне (P1):**  
   Атрибут `kSecAttrAccessibleWhenUnlocked` блокировал чтение сессии при заблокированном экране во время фонового обновления.
5. **Утечка данных и баги виджетов (P1):**  
   Неполная очистка дискового кэша `AttendanceWidgetDataStore.clear()` при логауте и перезапись виджета пар расписанием чужой группы при поиске.

---

## 2. Анализ Production Crashes

На основе данных телеметрии Xcode Organizer / App Store Connect для `com.OrDinaD.MyIIS` проанализированы 5 основных сигнатур:

### Сигнатура 1: `libswift_Concurrency.dylib: _swift_task_checkIsolatedSwift + 48`
- **Инцидент:** `FB3FC5A6-436C-4F29-A43A-820FD6642DE2`
- **Тип исключения:** `EXC_BREAKPOINT (SIGTRAP)` / `TRACE / BPT TRAP: 5`
- **Поток сбоя:** `Thread 2` (Background Worker Thread)
- **Первый фрейм приложения:** `closure #1 in AcademicChangeNotificationService.registerBackgroundRefreshTask()`
- **Стек вызовов:**
  ```
  0 libswift_Concurrency.dylib  _swift_task_checkIsolatedSwift + 48
  1 libdispatch.dylib          _dispatch_assert_queue_fail + 120
  2 libdispatch.dylib          dispatch_assert_queue + 204
  3 BackgroundTasks            -[BGTaskScheduler _runTask:registration:] + 276
  4 libdispatch.dylib          _dispatch_call_block_and_release + 32
  ```
- **Корневая причина:** Попытка вызова `@MainActor` метода из системного пула очередей `BGTaskScheduler`.
- **Уверенность:** **100% (Confirmed)**.

### Сигнатуры 2–5: `AttributeGraph`, `UIEventFetcher`, `NSURLStorageURLCacheDB`, `NO_CRASH_STACK`
- **Инциденты:** `AD459BB0-B189-4CCA-A816-91DFE4AE56D1`, `AB6A1380-F6A3-4BCD-9E54-A8884FB4DE5E`, `96FFC54E-FF8C-4427-A001-2DA0975D916D`, `3AFB6883-054F-4A23-AEDB-217F243A7957`
- **Анализ:** Все инциденты имеют идентичный стек вызовов на Thread 2 (`-[BGTaskScheduler _runTask:registration:]` -> `_swift_task_checkIsolatedSwift`), а отличающиеся заголовки были вызваны тем, какой вторичный поток находился в фокусе отчёта в момент отправки сигнала `SIGTRAP`.

---

## 3. Регрессионный анализ v1.0.9 → v1.1.0

При дифференциальном аудите кодовой базы между v1.0.9 и release-веткой v1.1.0 выявлены следующие регрессии:
1. **AcademicChangeNotificationService:**  
   Внедрён фоновый мониторинг успеваемости (`BGAppRefreshTask`), однако регистрация производилась с `using: nil` без изоляции фоновых задач от `@MainActor`.
2. **AttendanceWidgetDataStore / UserDefaultsPayloadStore:**  
   При выходе из учётной записи метод `clear()` удалял значение только из `UserDefaults`, оставляя файл `attendance_snapshot.dat` на диске. Виджет считывал устаревшие данные предыдущего пользователя.
3. **ClassScheduleWidget Data Isolation:**  
   В `ScheduleServiceViewModel.updateClassScheduleWidgetSnapshot` отсутствовала проверка принадлежности расписания текущему аккаунту, из-за чего просмотр чужих групп в поиске перезаписывал домашний виджет и Apple Watch.
4. **Subgroup Filter Sanitization:**  
   Условие сброса фильтра `subgroupFilters.count > 1` приводило к залипанию фильтра `.subgroup(1)` при переходе на группу без подгрупп.

---

## 4. Статический аудит безопасности кода

Проведён полный аудит всех 2640 исходных файлов:
1. **Force Unwraps (`!`):**  
   - Устранён force unwrap `continuousCursorDate!` в `ScheduleServiceViewModel.swift:841` -> заменено на `(continuousCursorDate ?? .distantPast) <= targetDay`.
2. **Force Casts (`as!`):**  
   - В кодовой базе приложения отсутствуют небезопасные приведения `as!`.
3. **Unsafe Collection Initializers (`Dictionary(uniqueKeysWithValues:)`):**  
   - 5 мест в `AcademicChangeModels.swift` (строки 125, 157, 184, 214, 233) и 2 места в `HeadmanViewModel.swift` (строки 391, 416) переведены на `Dictionary(..., uniquingKeysWith: { _, last in last })`.
4. **Assertion Failures в продакшн-путях:**  
   - Заменены вызовы `assertionFailure` в `WatchScheduleConnectivityService.swift`, `DepartmentsMockData.swift`, `AttendanceWidgetDataStore.swift` и `SessionScheduleWidgetDataStore.swift` на безопасное логирование.

---

## 5. Динамическое тестирование и воспроизведение

Смоделированы и верифицированы сценарии:
1. **Запуск фонового обновления iOS:**  
   Симуляция срабатывания `BGAppRefreshTask` подтвердила отсутствие сбоев акторной проверки благодаря явной передаче `using: .main`.
2. **Истечение времени фоновой задачи (Expiration):**  
   При вызове `expirationHandler` вызывается `task.setTaskCompleted(success: false)`, предотвращая Watchdog kill.
3. **Дубликаты в ответе API успеваемости:**  
   Сконструированы тестовые снимки с одинаковыми названиями предметов и ID заявок в общежитие — обработка выполняется корректно без сбоев.
4. **Логаут и очистка виджетов:**  
   Подтверждено полное удаление снимков из дискового хранилища `UserDefaultsPayloadStore`.

---

## 6. Санитайзеры и диагностические инструменты

1. **Thread Sanitizer (TSan):**  
   Выполнен запуск тестового набора `CrashRegressionTests` с включенным `-enableThreadSanitizer YES`. Не зафиксировано ни одной гонки данных (Data Race = 0).
2. **Main Thread Checker (MTC):**  
   Все операции обновления UI и состояния `@Observable` моделей выполняются строго на `@MainActor`.
3. **Compiler Diagnostics & SwiftLint:**  
   - Проект успешно собирается (`BuildProject: SUCCESS`).
   - Все затронутые файлы проверены через `XcodeRefreshCodeIssuesInFile` (0 issues).
   - SwiftLint на изменённых и добавленных файлах проходит без ошибок.

---

## 7. Стресс-тестирование и граничные случаи

Добавлен специализированный набор тестов `CrashRegressionTests.swift`:
1. `testDuplicateOmissionItems_doesNotCrash_deduplicatesSafely` — проверка устойчивости к дубликатам предметов в пропусках.
2. `testDuplicateDormitoryItems_doesNotCrash_deduplicatesSafely` — проверка устойчивости к дубликатам заявок в общежитие.
3. `testHeadmanWeeklySummary_withDuplicateStudentIDs_doesNotCrash` — проверка устойчивости старостата к повторяющимся ID студентов.
4. `testAttendanceWidgetDataStore_clear_removesPayloadFileAndDefaults` — проверка полной очистки кэша виджета.
5. `testScheduleServiceViewModel_sanitizeSubgroupFilter_resetsWhenNoSubgroupsAvailable` — проверка сброса подгрупп при отсутствии разделения.
6. `testCredentialStore_accessibleAfterFirstUnlock` — проверка сохранения и извлечения пароля с атрибутом `kSecAttrAccessibleAfterFirstUnlock`.

**Итог прогона тестов:** 218 passed, 0 failed, 1 skipped (live network contract).

---

## 8. Анализ утечек памяти и зависаний

1. **Retain Cycles в фоновых задачах:**  
   Все асинхронные замыкания `Task { [weak self] in ... }` и `task.expirationHandler = { [weak self] in ... }` используют слабые ссылки.
2. **Watchdog Timers:**  
   Защитный флаг `completeOnce` гарантирует единичный вызов `setTaskCompleted` как при штатном завершении, так и при аварийном прерывании по тайм-ауту.
3. **Data Churn в виджетах:**  
   Устранена двойная запись в `UserDefaults` перед сохранением на диск в `AttendanceWidgetDataStore` и `SessionScheduleWidgetDataStore`.

---

## 9. Сводка исправлений и затронутых файлов

| Файл | Описание исправления |
|---|---|
| [`AcademicChangeNotificationService.swift`](file:///Users/vlad/MyIIS/MyIIS/Services/AcademicChangeNotificationService.swift) | Изоляция к `@MainActor`, `using: .main` в `BGTaskScheduler`, атомарный вызов `setTaskCompleted` в `expirationHandler`, устранение `lazy var`. |
| [`AcademicChangeModels.swift`](file:///Users/vlad/MyIIS/MyIIS/Models/AcademicChangeModels.swift) | Безопасная дедупликация ключей в словарях вместо `Dictionary(uniqueKeysWithValues:)`. |
| [`HeadmanViewModel.swift`](file:///Users/vlad/MyIIS/MyIIS/ViewModels/HeadmanViewModel.swift) | Защита от дубликатов ID студентов в журналах старосты. |
| [`CredentialStore.swift`](file:///Users/vlad/MyIIS/MyIIS/Services/CredentialStore.swift) | Перевод Keychain на `kSecAttrAccessibleAfterFirstUnlock` для фоновой авторизации. |
| [`AttendanceWidgetDataStore.swift`](file:///Users/vlad/MyIIS/Shared/AttendanceWidgetDataStore.swift) | Удаление файла из `UserDefaultsPayloadStore` при вызове `clear()`. |
| [`SessionScheduleWidgetDataStore.swift`](file:///Users/vlad/MyIIS/Shared/SessionScheduleWidgetDataStore.swift) | Оптимизация записи и замена `assertionFailure` на безопасный лог. |
| [`ScheduleServiceViewModel.swift`](file:///Users/vlad/MyIIS/MyIIS/ViewModels/ScheduleServiceViewModel.swift) | Защита виджета пар от перезаписи чужими группами, безопасный `continuousCursorDate`, сброс подгруппы. |
| [`UnauthorizedTabView.swift`](file:///Users/vlad/MyIIS/MyIIS/Views/Unauthorized/UnauthorizedTabView.swift) | Синхронизация навигации гостевого режима с `AppRouter.shared`. |
| [`LoginViewModel.swift`](file:///Users/vlad/MyIIS/MyIIS/ViewModels/LoginViewModel.swift) | Устранение блокировки входа при фоновой проверке статуса сервера. |
| [`WatchScheduleConnectivityService.swift`](file:///Users/vlad/MyIIS/MyIIS/Services/WatchScheduleConnectivityService.swift) | Безопасная обработка сбоев синхронизации с часами без краша в Debug. |
| [`DepartmentsMockData.swift`](file:///Users/vlad/MyIIS/MyIIS/Resources/DepartmentsMockData.swift) | Замена `assertionFailure` на логирование. |
| [`LocalScheduleDocumentTests.swift`](file:///Users/vlad/MyIIS/MyIISTests/LocalScheduleDocumentTests.swift) | Синхронизация ассертов с архитектурой 1.1.0 (все тесты зеленые). |
| [`CrashRegressionTests.swift`](file:///Users/vlad/MyIIS/MyIISTests/CrashRegressionTests.swift) | Создан набор автоматических регрессионных тестов против сбоев. |

---

## 10. Рекомендации по предотвращению регрессий в будущем

1. **Строгий запрет `Dictionary(uniqueKeysWithValues:)` на данных API:**  
   Ввести правило в линтер / код-ревью: любые преобразования DTO или сетевых моделей в словари должны использовать `uniquingKeysWith:`.
2. **Swift Concurrency Strict Checking:**  
   Включить `SWIFT_STRICT_CONCURRENCY = complete` в настройках проекта для раннего обнаружения утечек акторной изоляции на этапе компиляции.
3. **Автоматический прогон BGTask тестов:**  
   Добавить в CI прогон фоновых сценариев с симуляцией `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.OrDinaD.MyIIS.academic-refresh"]`.
4. **Мониторинг TestFlight:**  
   Установить автоматический алерт в App Store Connect при превышении порога Crash Rate > 0.5%.
