---
name: xcode
description: "Работать с MyIIS, Xcode, Swift, SwiftUI, UIKit и Apple SDK через живой Xcode MCP. Использовать для чтения и изменения файлов проекта, Apple Documentation/HIG, diagnostics, build/run/test, Preview, simulator UI, localization, crash/performance и проверки качества iOS-кода."
---

# Xcode workflow для MyIIS

Использовать `mcp__xcode` как единственный интерфейс к файлам Xcode-проекта. Если MCP не видит проект или нужная операция стабильно не работает, остановить изменения и сообщить точную ошибку; не обходить её прямой записью production-файлов.

## Начать задачу

1. Вызвать `XcodeListWindows`.
2. Найти `/Users/vlad/MyIIS/MyIIS.xcodeproj` и сохранить `tabIdentifier`.
3. При зависимости результата от окружения вызвать `XcodeListSchemes`, `XcodeListRunDestinations` и `GetTargetBuildSettings`.
4. Перед первым simulator build/run/test через XcodeBuildMCP вызвать `session_show_defaults`.
5. Определять Xcode, Swift language mode, SDK/runtime и deployment target динамически. Не считать номер SDK доказательством stable/beta-статуса OS.

Прочитать [references/tool-catalog.md](references/tool-catalog.md), когда нужно выбрать инструмент, проверить его точное имя или понять ограничения живого MCP. Схемы параметров живого инструмента всегда важнее сохранённого каталога.

## Работать с проектом

- Навигация: сначала `XcodeGlob`/`XcodeGrep`, затем точечный `XcodeRead`; для открытого файла использовать `XcodeGetCurrentFile`.
- Правки: предпочитать `XcodeUpdate`; перед `XcodeWrite` прочитать существующий файл; перед `XcodeRM` найти зависимости; перемещения выполнять `XcodeMV`.
- Не менять project files, resources, tests, catalogs, plist и entitlements через filesystem, shell или `apply_patch`.
- Разрешить filesystem только для конфигурации вне Project Navigator (`AGENTS.md`, `.agents/`, `.gitignore`), Git и внешних анализаторов. Не расширять это исключение на production-код.

## Проверить Apple API и UX

- Перед новым или незнакомым Apple API вызвать `DocumentationSearch` с точным символом/framework и отдельным запросом по сценарию.
- Для HIG/accessibility при необходимости искать без framework-фильтра.
- Указывать availability только при явном подтверждении Apple Documentation или compiler diagnostics.
- Проверять Dynamic Type, VoiceOver, Reduce Motion, контраст, локализацию, loading/empty/error/offline/stale/unauthorized состояния, iPhone/iPad и затронутые extensions.
- Не считать HAR, fixture, mock, Preview или unit-test payload подтверждением актуального backend-контракта.

## Изменять конфигурацию безопасно

- Не редактировать `project.pbxproj` вручную.
- Использовать `GetTargetBuildSettings`/`GetFileCompilerFlags` для чтения.
- Использовать `AddInfoPlist` для metadata и privacy usage descriptions, `AddEntitlement` — только для необходимого code-signing entitlement.
- Signing, capabilities, targets, schemes, build phases и критичные build settings менять только по явному запросу пользователя. Иначе дать точные шаги в Xcode.

## Валидировать

Выбрать подходящий набор из [references/quality-gates.md](references/quality-gates.md):

1. `XcodeRefreshCodeIssuesInFile` для затронутых Swift-файлов.
2. `GetTestList` и релевантные `RunSomeTests`; `RunAllTests` для широкого изменения.
3. `swiftlint lint --strict`; исправлять только нарушения затронутых файлов через Xcode MCP.
4. `RenderPreview` для SwiftUI с рабочим Preview; реальный UI проверять через `RunProject` либо настроенный `build_run_sim`, свежий UI snapshot/screenshot и logs.
5. `BuildProject`; при ошибке `GetBuildLog`.
6. `XcodeListNavigatorIssues` для `error` и `warning`.

Sanitizers, Thread/Main Thread checks, coverage, Instruments/ETTrace, memgraph и Periphery запускать по риску задачи. Не менять scheme diagnostics скрытно и не объявлять анализатор доступным без проверки.

## Завершить

После успешного `BuildProject` проверить Git status, diff и staged diff. Коммитить только файлы текущей задачи, без секретов, персональных данных, логов, Derived Data, `.xcresult` и чужих изменений. Использовать короткое сообщение на русском языке.
