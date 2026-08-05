# MyIIS: обязательная политика работы

Проект — iOS-приложение на Swift/SwiftUI. Для любой работы с проектом обязательно используй живой `mcp__xcode` (Xcode Tools). Если `mcp__xcode` недоступен, `XcodeListWindows` не видит `/Users/vlad/MyIIS/MyIIS.xcodeproj` или нужная операция стабильно завершается ошибкой, сообщи точную проблему и приостанови изменения проекта. Не обходи отказ Xcode MCP через shell, Python или прямую запись файлов.

## Обязательное начало каждой задачи

1. Вызови `mcp__xcode.XcodeListWindows`.
2. Найди `/Users/vlad/MyIIS/MyIIS.xcodeproj` и сохрани его `tabIdentifier`.
3. Проверь активные scheme и destination через `XcodeListSchemes` и `XcodeListRunDestinations`, когда они влияют на результат.
4. Не полагайся на записанные номера Xcode, Swift, SDK, iOS или моделей устройств: текущую среду определяй живыми инструментами.
5. Перед первым simulator build/run/test через `mcp__xcodebuildmcp` вызови `session_show_defaults`. Если профиль пуст или неверен, сначала настрой его явным образом.

## Единственный путь к файлам проекта

- Читай, ищи, создавай, перемещай, переименовывай и изменяй файлы, видимые в Project Navigator, только через `mcp__xcode`: `XcodeRead`, `XcodeLS`, `XcodeGlob`, `XcodeGrep`, `XcodeUpdate`, `XcodeWrite`, `XcodeMakeDir`, `XcodeMV`, `XcodeRM`.
- Пути Xcode MCP — пути в структуре Project Navigator, а не абсолютные filesystem paths.
- Для текущего открытого файла или selection используй `XcodeGetCurrentFile`.
- Не используй shell, filesystem API, Python, `sed`, `perl` или `apply_patch` для кода, ресурсов, тестов, entitlements, Info.plist, String Catalogs и файлов Xcode-проекта.
- Допустимые локальные исключения: Git, SwiftLint/Periphery и другие явно выбранные анализаторы, а также конфигурация вне Project Navigator (`AGENTS.md`, `.agents/`, `.gitignore`). Исключение не разрешает менять production-файлы в обход Xcode MCP.

## Поиск и семантический анализ кода

- Для смыслового и контекстного поиска по кодовой базе в первую очередь используй `context-link`.
- В Swift-коде обязательно используй `swift-sourcekit` (`swift-mcp-server`) для получения точных определений, ссылок (references), типов, реализаций протоколов и диагностики компилятора через SourceKit-LSP.
- Перед изменением Swift-символов проверяй их области применения и зависимости через `context-link` и `swift-sourcekit`.

## Apple API, UI и архитектура

- Перед новым или незнакомым API SwiftUI, UIKit, WidgetKit, App Intents, Observation, Swift Concurrency, AVFoundation и других Apple frameworks используй `DocumentationSearch`.
- Для beta SDK обязательно подтверждай API, availability и ограничения найденной Apple Documentation; номер OS сам по себе ничего не доказывает.
- Для View/MVVM проверяй Apple HIG, Dynamic Type, VoiceOver, Reduce Motion, контраст, локализацию, состояния загрузки/ошибки/пустых данных и адаптацию iPhone/iPad.
- Переиспользуй существующие View, ViewModel, модели, сервисы, роутинг, локализацию и API-клиенты. Не создавай второй источник истины и не помещай бизнес-логику в `body`.
- Проверяй MainActor, Sendable, cancellation, lifecycle, retain cycles и безопасное хранение данных.
- HAR, fixture, mock и старый JSON подтверждают только известную форму данных. Они не являются доказательством актуального backend-контракта; различай live API, сохранённый пример и предположение.

## Настройки проекта

- Никогда не редактируй `project.pbxproj` вручную.
- Читай настройки через `GetTargetBuildSettings` и per-file flags через `GetFileCompilerFlags`.
- `AddInfoPlist` используй для Info.plist metadata и privacy usage descriptions; `AddEntitlement` — только для действительно требуемых code-signing entitlements.
- Signing, capabilities, targets, build phases, schemes и критичные build settings не меняй без явного запроса пользователя. Если изменение не было прямо поручено, дай точные шаги в Xcode.

## Проверка результата

После изменений выбери проверки пропорционально риску:

1. `XcodeRefreshCodeIssuesInFile` для затронутых Swift-файлов.
2. `GetTestList`, затем релевантные `RunSomeTests`; `RunAllTests` — для широких изменений или прямого запроса.
3. `swiftlint lint --strict`; несвязанный исторический долг не исправляй в чужой задаче, но ошибки затронутых файлов устрани через Xcode MCP.
4. Для SwiftUI используй `RenderPreview`, если есть рабочий Preview; для реального UI — `RunProject` или настроенный `build_run_sim`, затем screenshot/UI snapshot и console logs.
5. Выполни `BuildProject`. При ошибке прочитай `GetBuildLog`.
6. Проверь `XcodeListNavigatorIssues` как минимум для `error` и `warning`.

Sanitizers, Thread Performance Checker, Main Thread Checker, code coverage, Instruments/ETTrace, memgraph и Periphery запускай только когда они относятся к риску задачи. Не включай и не меняй scheme diagnostics скрытно; сначала зафиксируй текущую конфигурацию и сообщи, какая проверка нужна.

## Git

Коммит разрешён только после успешного `BuildProject`. Перед ним проверь `git status`, полный diff, staged diff, секреты, персональные данные, логи, `.xcresult`, Derived Data и временные агентные файлы. Добавляй и коммить только файлы текущей задачи; существующие пользовательские изменения не включай. Сообщение коммита — короткое и понятное на русском языке.

## Проектный skill и специализированные субагенты

- Skill: `.agents/skills/xcode/SKILL.md` (`xcode`). Для полного живого каталога инструментов используй его references.
- `apple-platform-reviewer`: Apple Documentation, HIG, stable/beta availability и accessibility; только read-only аудит.
- `ios-quality-auditor`: lint, compiler diagnostics, tests, sanitizers, performance, coverage, dead code и privacy; ничего не включает скрытно.
- `product-integrity-auditor`: целесообразность, UX/HIG, state flow, локализация и соответствие реальным API/HAR/fixtures; только read-only аудит.
- Дополнительные роли: `task-architect`, `code-reviewer` и `unit-test-writer`; их границы заданы в собственных `agent.md`.

Все субагенты сначала вызывают `XcodeListWindows`. Три аудитора работают read-only; `unit-test-writer` может менять только unit tests через Xcode MCP. Основной агент принимает production-решения, выполняет изменения через Xcode MCP и отвечает за финальную сборку и Git.
