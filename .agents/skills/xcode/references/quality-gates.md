# Проверки качества MyIIS

Выбирать проверки по изменённому риску, а не запускать всё без цели.

## Базовый gate

1. `XcodeRefreshCodeIssuesInFile` для затронутых Swift-файлов.
2. `GetTestList` → релевантные `RunSomeTests`.
3. `swiftlint lint --strict`; отделить нарушения затронутых файлов от исторического baseline.
4. `BuildProject` → при ошибке `GetBuildLog`.
5. `XcodeListNavigatorIssues` для error/warning.
6. `git diff --check`, status, diff, staged diff.

## UI и runtime

- SwiftUI layout: `RenderPreview` при наличии Preview, затем light/dark, длинная локализация и Dynamic Type там, где controls это поддерживают.
- Реальный flow: `RunProject` или настроенный `build_run_sim`; затем свежий `snapshot_ui`/screenshot, действия только по element refs и console logs.
- Проверять loading, empty, error, offline, unauthorized, stale data, cancellation, повторный вход и background/foreground при релевантности.

## Concurrency и sanitizers

- Сначала проверить Swift 6 diagnostics, actor isolation, Sendable, cancellation и MainActor на уровне кода/compiler.
- Address Sanitizer — memory corruption/use-after-free; особенно для unsafe/C/ObjC boundaries. Не совмещать без причины с другими sanitizers.
- Thread Sanitizer — data races; запускать отдельным simulator test/run, учитывать замедление и несовместимости.
- Undefined Behavior Sanitizer — C/ObjC/unsafe arithmetic/ABI риски.
- Main Thread Checker и Thread Performance Checker — UI/main-thread misuse и priority inversions.
- Scheme diagnostics не менять скрытно. Если tool не управляет нужной настройкой надёжно, дать пользователю точные шаги Xcode или согласовать отдельный xcodebuild invocation.

Sanitizer pass означает только отсутствие обнаруженной проблемы в выполненном сценарии, не доказательство её отсутствия.

## Memory и performance

- Runtime jank/CPU: Instruments Time Profiler или ETTrace на воспроизводимом сценарии, до/после.
- Leaks/рост памяти: Memory Graph/Leaks/memgraph, повторить сценарий несколько раз и проверить retain paths.
- Launch/hangs/disk writes/energy: field performance tools с точным bundle ID, app version, channel и platform.
- Network/cache: измерять запросы, retries, decoding и UI updates отдельно; не делать вывод по одной общей duration.

## Coverage и unused code

- Coverage использовать как карту непройденных веток, не как цель процента. Получать `get_coverage_report`/`get_file_coverage` только из test result с включённым coverage.
- Compiler warnings: unreachable code, unused variables/results, deprecated API и strict concurrency.
- SwiftLint: style и поддерживаемые analyzer rules; не ожидать полного межмодульного dead-code анализа.
- Periphery: искать unused declarations/imports по корректным schemes/targets. Перед запуском проверить `periphery version` и config; каждый результат подтвердить usage search, dynamic lookup, Objective-C exposure, SwiftUI previews, App Intents, Widget/Watch/Messages entry points и tests.
- Не удалять код автоматически по одному отчёту Periphery.

## Доступные локальные анализаторы

На снимке 2026-08-03 установлены `swiftlint 0.65.0`, `periphery`, `swiftformat`; `xcbeautify` и `xclogparser` не найдены. Каждый раз перепроверять `command -v`/version. Не устанавливать инструменты без прямого запроса пользователя. `swiftformat` не запускать в режиме записи без отдельного разрешения.

## Security и privacy

- Ищите hardcoded credentials/tokens, лишние logs, PII в fixtures/HAR, небезопасное хранение, overly broad entitlements/ATS и отсутствующие privacy usage descriptions.
- Не печатать секреты в tool output или отчёт.
- Dependency/security scanners запускать только если они установлены и применимы; не подменять Apple signing/notarization checks общим SAST.

## Формат evidence

Для каждого gate фиксировать command/tool, scheme/destination, scope, результат, непройденные проверки и ограничения доказательства. Не писать «всё проверено», если запускалась только часть.
