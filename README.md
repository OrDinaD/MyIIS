<p align="center">
  <img src="Default-iOS-Default-1024x1024@1x.png" width="112" alt="MyIIS app icon">
</p>

# MyIIS

<p>
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white">
  <img alt="SwiftUI" src="https://img.shields.io/badge/SwiftUI-native-111827?style=flat-square&logo=apple&logoColor=white">
  <img alt="iOS 26" src="https://img.shields.io/badge/iOS-26-2563EB?style=flat-square&logo=apple&logoColor=white">
  <img alt="Xcode 26" src="https://img.shields.io/badge/Xcode-26-147EFB?style=flat-square&logo=xcode&logoColor=white">
  <img alt="License" src="https://img.shields.io/badge/license-PolyForm%20Noncommercial%201.0.0-374151?style=flat-square">
</p>

MyIIS - iOS-приложение для студентов БГУИР. Оно собирает личный кабинет, учебные данные, сервисы университета и СЭО в одном SwiftUI-интерфейсе без необходимости переключаться между разными веб-страницами.

## Инфографика

<p align="center">
  <img src="public/showcase/1.jpg" width="32%" alt="Инфографика 1">
  <img src="public/showcase/2.jpg" width="32%" alt="Инфографика 2">
  <img src="public/showcase/3.jpg" width="32%" alt="Инфографика 3">
</p>

## Возможности

**Личный кабинет**

- Авторизация через IIS БГУИР с хранением учетных данных в Keychain.
- Профиль студента: ФИО, фото, группа, факультет, специальность и учебный статус.
- Быстрый обзор ключевых учебных показателей без ручного обхода разделов личного кабинета.

**Учебный контур**

- Расписание занятий, экзаменов и учебных событий.
- Посещаемость с детализацией по предметам и пропускам.
- Рейтинг, текущие баллы и электронная зачетка.
- Отдельные состояния загрузки, ошибок и пустых данных для нестабильных API-ответов.

**СЭО и университетские сервисы**

- Интеграция с LMS/СЭО: курсы, тесты и вспомогательные учебные экраны.
- Заявления, справки, общежитие, библиотека, активности и объявления.
- Локализованный интерфейс для русского, английского, белорусского и украинского языков.

**iOS-интеграции**

- SwiftUI-интерфейс с адаптацией под современные iPhone.
- WidgetKit-виджет для быстрых учебных статусов.
- App Intents для системных сценариев iOS.
- XCTest и XCUITest для проверки моделей, сервисов и основных пользовательских путей.

## Стек

<div align="center">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6-F05138?style=for-the-badge&logo=swift&logoColor=white">
  <img alt="SwiftUI" src="https://img.shields.io/badge/SwiftUI-111827?style=for-the-badge&logo=apple&logoColor=white">
  <img alt="MVVM" src="https://img.shields.io/badge/MVVM-0F172A?style=for-the-badge">
  <img alt="Concurrency" src="https://img.shields.io/badge/Swift_Concurrency-2563EB?style=for-the-badge&logo=swift&logoColor=white">
  <img alt="URLSession" src="https://img.shields.io/badge/URLSession-0EA5E9?style=for-the-badge">
  <br>
  <img alt="WidgetKit" src="https://img.shields.io/badge/WidgetKit-1D4ED8?style=for-the-badge&logo=apple&logoColor=white">
  <img alt="App Intents" src="https://img.shields.io/badge/App_Intents-334155?style=for-the-badge">
  <img alt="XCTest" src="https://img.shields.io/badge/XCTest-10B981?style=for-the-badge">
  <img alt="fastlane" src="https://img.shields.io/badge/fastlane-8B5CF6?style=for-the-badge&logo=fastlane&logoColor=white">
  <img alt="GitHub Actions" src="https://img.shields.io/badge/GitHub_Actions-111827?style=for-the-badge&logo=githubactions&logoColor=white">
</div>

## Структура проекта

```text
MyIIS/                  Основное iOS-приложение
MyIIS/Models/           Модели API и доменные сущности
MyIIS/Services/         Сетевые клиенты, авторизация, настройки и интеграции
MyIIS/ViewModels/       Состояние экранов и бизнес-логика
MyIIS/Views/            SwiftUI-экраны и переиспользуемые представления
Shared/                 Общий код приложения, виджета и App Intents
MyIISWidget/            WidgetKit-расширение
MyIISIntents/           App Intents extension
MyIISTests/             Unit/API decoding tests
MyIISUITests/           UI-тесты и snapshot-сценарии
API/                    Документация и заметки по IIS API
Configs/                Конфигурации таргетов и Info.plist
fastlane/               Автоматизация App Store screenshots
static/                 GitHub Pages: about, privacy policy, terms
public/showcase/        Скриншоты для README и публичной витрины
```

```mermaid
flowchart LR
    App["MyIIS App"] --> Views["SwiftUI Views"]
    Views --> ViewModels["ViewModels"]
    ViewModels --> Services["Services"]
    Services --> IIS["IIS APIs"]
    Services --> LMS["LMS / СЭО"]
    App --> Shared["Shared"]
    Shared --> Widget["WidgetKit"]
    Shared --> Intents["App Intents"]
    Tests["XCTest / XCUITest"] --> Models["Models"]
    Tests --> Services
```

## API

Приложение работает с IIS БГУИР и ориентируется на фактические endpoint-контракты:

- [API/REAL_API_ENDPOINTS.md](API/REAL_API_ENDPOINTS.md) - актуальные рабочие endpoint'ы.
- [API/API_REFERENCE.swift](API/API_REFERENCE.swift) - Swift-справочник по API-контрактам.
- [SwaggerHub BsuirAdditionalApi](https://app.swaggerhub.com/apis-docs/N1ghtF1re/BsuirAdditionalApi/2.0.0) - внешняя справка, которая может отставать от реального API.

## Лицензия

Проект распространяется по [PolyForm Noncommercial License 1.0.0](LICENSE).

Код можно изучать, запускать, изменять и использовать для некоммерческих целей. Коммерческое использование, коммерческие производные проекты и включение кода в коммерческие продукты требуют отдельного письменного разрешения правообладателя.
