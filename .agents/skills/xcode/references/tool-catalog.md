# Живой каталог Xcode MCP

Каталог проверен 2026-08-03. Имена и схемы могут измениться: перед использованием сверяться с реально доступными tools. Сохранённый итог аудита: 47 `mcp__xcode` и 44 `mcp__xcodebuildmcp`.

## Состояние MyIIS на момент аудита

- `XcodeListWindows` работает: `/Users/vlad/MyIIS/MyIIS.xcodeproj`, `windowtab1`.
- Активны scheme `MyIIS` и simulator `iPhone 17` / iOS 27.0; Xcode CLI сообщает Xcode 27.0 (build 27A5218g), Swift compiler 6.4. Release channel этим не подтверждён. Это снимок, не постоянная настройка.
- `GetTargetBuildSettings` работает; deployment target и Swift language mode нужно читать отдельно от версии установленного compiler.
- `XcodeRead`, `XcodeLS`, `XcodeGlob`, `XcodeGrep`, schemes, destinations, test discovery, Issue Navigator и `DocumentationSearch` отвечают.
- Найдено 170 enabled tests. Targeted `RunSomeTests` успешно выполнил один `LocalScheduleDocumentTests` test. `BuildProject(buildForTesting: true)` завершился успешно.
- `GetBuildLog` после сборки работает и нашёл два version-mismatch warnings для MyIISIntents/MyIISMessages (`1.0.7` против parent app `1.0.8`). Issue Navigator показывает один агрегированный warning и 0 errors.
- `GetTopCrashIssues` работает для `com.OrDinaD.MyIIS` и вернул пустой список; отсутствие записей не доказывает отсутствие crash-риска.
- В начале аудита `session_show_defaults` XcodeBuildMCP был пуст. До build/run/test такой профиль нужно настроить явно.
- После `session_set_defaults(persist: false)` отдельный `build_sim` для MyIIS / iPhone 17 завершился успешно; он подтвердил тот же extension version warning. Session setup не записывался в repository.
- `GetBuildLog` без недавней сборки закономерно возвращает ошибку. `XcodeGetCurrentFile` без активного editor возвращает `isEditable: false`.
- `RunCodeSnippet` и `RenderPreview` существуют, но в текущей активной scheme блокируются отсутствующим компонентом watchOS 27.0. Это dependency blocker среды, а не отсутствие tools; обычный build и targeted unit test при этом работают.
- Field performance tools требуют явный bundle ID, тип диагностики и часто app version/channel. Это запрос уточнения, а не поломка.
- Mutating/configuration/debug/device tools не smoke-test'ить без реальной задачи: их доступность в registry не разрешает менять проект или запускать дорогую session.

## `mcp__xcode`: 47 tools

### Workspace и навигация

- `XcodeListWindows` — найти открытые projects/workspaces и `tabIdentifier`; всегда первый вызов.
- `XcodeListSchemes` — список schemes и активная scheme.
- `XcodeSwitchScheme` — сменить scheme по точному disambiguated name; только когда это нужно задаче.
- `XcodeListRunDestinations` — список eligible/incompatible destinations активной scheme.
- `XcodeSwitchRunDestination` — выбрать destination по возвращённому display title.
- `XcodeGetCurrentFile` — активный файл и selection; отсутствие активного editor допустимо.
- `XcodeLS` — содержимое группы/папки Project Navigator.
- `XcodeGlob` — поиск файлов по wildcard; сначала сужать область.
- `XcodeGrep` — regex-поиск содержимого с line/context filters.
- `XcodeRead` — чтение файла с line numbers, offset и limit.

### Изменение файлов и конфигурации

- `XcodeUpdate` — точечная замена текста; предпочитать полной перезаписи.
- `XcodeWrite` — создать или полностью перезаписать файл; сначала читать существующий.
- `XcodeMakeDir` — создать папку/группу.
- `XcodeMV` — move/rename/copy в структуре проекта.
- `XcodeRM` — удалить reference и опционально файл; сначала проверить зависимости.
- `GetFileCompilerFlags` — прочитать per-file flags; для Swift tool предупреждает, что module-level setting может быть эффективнее.
- `UpdateFileCompilerFlags` — изменить per-file flags; применять только по явной задаче.
- `GetTargetBuildSettings` — прочитать evaluated target settings.
- `UpdateTargetBuildSetting` — изменить поддерживаемый target setting через Xcode; не использовать для скрытой смены signing/scheme policy.
- `AddInfoPlist` — добавить/обновить Info.plist metadata, privacy text, URL/document/background settings; не для entitlements.
- `AddEntitlement` — добавить code-signing entitlement; не для обычного framework API или privacy usage description.

### Apple Documentation, snippet и Preview

- `DocumentationSearch` — семантический поиск Apple Documentation через `call_mcp_tool` (`ServerName: "xcode"`, `ToolName: "DocumentationSearch"`). Аргументы: `query` (строка, обязательно), `frameworks` (массив строк, опционально, например `["SwiftUI"]`). Точные символы дают лучший результат, availability не угадывать.
- `RunCodeSnippet` — выполнить изолированный Swift snippet в контексте файла; `purpose` не должен содержать слово `test`; не заменяет tests/build.
- `RenderPreview` — собрать SwiftUI Preview, вернуть snapshot, destination, localization/variant controls и errors.

### Build, run, logs и debugger

- `BuildProject` — собрать активную scheme/destination и вернуть errors/full log path; обязательный gate перед commit.
- `GetBuildLog` — фильтр последнего/current build по severity, regex и glob; требует существующий build.
- `RunProject` — build+launch, опционально attach debugger; возвращает launch session reference.
- `StopProject` — остановить активный launch.
- `GetConsoleOutput` — stdout/stderr/OSLog текущей или указанной launch session с filters/context.
- `InvokeDebuggerCommand` — LLDB command в активной Xcode debug session; без session честно сообщает её отсутствие.

### Tests

- `GetTestList` — enabled/disabled tests и стабильные identifiers активного test plan.
- `RunSomeTests` — запустить конкретные identifiers; основной выбор для затронутой логики.
- `RunAllTests` — запустить все enabled tests; использовать пропорционально риску.

### Diagnostics, crashes и field performance

- `XcodeRefreshCodeIssuesInFile` — обновить compiler diagnostics конкретного Swift-файла.
- `XcodeListNavigatorIssues` — ошибки/warnings/remarks Issue Navigator с filters.
- `GetTopCrashIssues` — top crash signatures из App Store/TestFlight field data; обычно нужны bundle ID/platform/channel.
- `GetCrashIssueLogs` — детали выбранной crash issue/signature; сначала получить issue из top list.
- `GetTopFieldPerformanceIssues` — launches/hangs/disk writes/energy; может потребовать app version/channel.
- `GetFieldPerformanceIssueLogs` — детали конкретной field performance issue.

### Localization

- `LocalizationPlanner` — анализ проекта и план локализации; может делать изменения, поэтому не вызывать как read-only аудит.
- `StringCatalogRead` — counts/keys по locale и translation state.
- `StringCatalogContext` — source values, comments, code usages, similar translations, devices и plural cases для ключа.
- `StringCatalogEdit` — изменить translations/variations в String Catalog; использовать после context и designated translation workflow.

### Device interaction

- `DeviceInteractionStartSession` — подготовить physical/simulator runtime; запускать рано только если нужна runtime-проверка.
- `DeviceInteractionInstallAndRun` — build/install/run актуального приложения внутри device session.
- `DeviceInteractionSynthesize` — tap/swipe/type/buttons/orientation плюс screenshot, AX hierarchy и logs; координаты брать из свежей hierarchy.
- `DeviceInteractionEndSession` — обязательно закрыть дорогую device session.

## `mcp__xcodebuildmcp`: 44 tools

Это дополнительный simulator/runtime pipeline, не замена обязательному `mcp__xcode` для Project Navigator.

### Session, discovery и build settings

- `session_show_defaults` — обязательная первая проверка project/workspace, scheme и simulator.
- `session_set_defaults` — явно настроить session defaults.
- `session_clear_defaults` — очистить defaults.
- `session_use_defaults_profile` — выбрать сохранённый профиль.
- `discover_projs` — найти projects/workspaces только если defaults отсутствуют или неверны.
- `list_schemes` — schemes указанного/default project.
- `list_sims` — simulator devices/runtimes.
- `show_build_settings` — evaluated build settings.
- `clean` — clean build artifacts; не использовать как ритуал или первый способ лечить ошибку.

### Simulator build, run, tests и artifacts

- `build_sim` — собрать для настроенного simulator.
- `build_run_sim` — build/install/launch; сам boot/open simulator при необходимости.
- `test_sim` — tests на simulator, включая prepared `.xctestrun`/`.xctestproducts` и runner env.
- `get_app_bundle_id` — определить bundle ID.
- `get_sim_app_path` — путь собранного `.app`.
- `install_app_sim` — установить существующий `.app`.
- `launch_app_sim` — запустить установленное приложение.
- `stop_app_sim` — остановить приложение.
- `get_coverage_report` — сводка coverage из результатов tests.
- `get_file_coverage` — coverage конкретного файла.

### Simulator UI automation и media

- `boot_sim` — boot выбранного simulator; не нужен перед `build_run_sim`.
- `open_sim` — открыть Simulator UI; не нужен перед `build_run_sim`.
- `snapshot_ui` — semantic runtime snapshot с element refs; источник истины для UI actions.
- `wait_for_ui` — ждать exists/gone/enabled/focused/text/settled predicate.
- `tap` — tap по свежему actionable element ref.
- `batch` — несколько same-screen actions без лишних round trips.
- `swipe` — swipe внутри scrollable element ref.
- `drag` — drag между semantic elements/positions по схеме инструмента.
- `gesture` — готовые compound gestures.
- `long_press` — long press по element ref.
- `touch` — явные touch down/up events.
- `type_text` — ввести/заменить текст в text-field element ref.
- `button` — hardware/system button action.
- `key_press` — одна keyboard key.
- `key_sequence` — последовательность keyboard keys.
- `screenshot` — screenshot simulator.
- `record_sim_video` — записать video runtime; обязательно завершить recording по схеме tool.

### LLDB debugger

- `debug_attach_sim` — attach LLDB к simulator app.
- `debug_breakpoint_add` — добавить breakpoint.
- `debug_breakpoint_remove` — удалить breakpoint.
- `debug_continue` — продолжить выполнение.
- `debug_detach` — безопасно отсоединить debugger.
- `debug_lldb_command` — произвольная разрешённая LLDB command.
- `debug_stack` — stack trace.
- `debug_variables` — variables текущего frame/context.

Всегда использовать точные input schema живого tool. Для UI refresh snapshot после navigation, scroll, sheet или layout change; не угадывать coordinates/element refs. Не запускать device/debug/recording sessions без cleanup.
