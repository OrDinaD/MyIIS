---
description: "Обязательная политика работы с MyIIS через Xcode MCP."
---

# Xcode MCP

Для любых задач с Xcode, Swift, SwiftUI, UIKit и Apple SDK используй skill `xcode`.

Первым вызовом в задаче должен быть `mcp__xcode.XcodeListWindows`. После этого используй полученный `tabIdentifier` проекта MyIIS.

Чтение, поиск, создание и изменение файлов Xcode-проекта выполняй через `mcp__xcode`, когда подходящий инструмент доступен. Shell допустим только для Git, SwiftLint и файлов, недоступных в Project Navigator.

Перед новым или незнакомым Apple API используй `mcp__xcode.DocumentationSearch`.

После существенных изменений:

1. обнови diagnostics;
2. запусти полезные unit-тесты;
3. запусти `swiftlint lint --strict`;
4. выполни `mcp__xcode.BuildProject`;
5. проверь Issue Navigator.

Не создавай и не запускай UI-тесты без прямого запроса пользователя.

Не редактируй `.pbxproj` напрямую. Изменения signing, capabilities, targets, build phases и project settings объясняй пошагово через интерфейс Xcode.

Git-коммит создавай только после успешной сборки. Не включай секреты, логи, временные файлы и агентные артефакты.
