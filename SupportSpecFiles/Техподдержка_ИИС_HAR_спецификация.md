# Разбор HAR: «Документы» и система технической поддержки ИИС БГУИР

**Исходник:** `Документы Техподдержки.har`  
**SHA‑256:** `f78fdc5d7979d3b9dd2d95e962b7152863d94e3b568fd91754697218da857d70`  
**Базовый API:** `https://iis.bsuir.by/api/v1`

> Важно: исходный HAR содержит cookie `SESSION` и аналитические cookies. Значения в этот отчёт и JSON-контракт не перенесены. Для передачи другой нейросети лучше использовать именно подготовленные файлы, а не оригинальный HAR.

## 1. Главный вывод

Страница `https://iis.bsuir.by/support` — React SPA. При открытии она загружает статические JS/CSS-ресурсы и делает только один фактический API-запрос:

`GET https://iis.bsuir.by/api/v1/bug-report/categories`

Секция **«Документы» не использует API вообще**. Четыре группы и восемь PDF-ссылок жёстко записаны в клиентском JavaScript. Поэтому в iOS их надо либо повторить локальной конфигурацией, либо вынести в собственный конфигурационный файл приложения.

Форма заявки работает гибридно:

- сервер возвращает категории и подкатегории;
- клиент по `categoryKey` добавляет набор полей, обязательность, иконки и предупреждения;
- дополнительные подсказки загружаются отдельными endpoint’ами;
- заявка отправляется как `multipart/form-data`;
- авторизация cookie-based: Axios создан с `withCredentials: true`.

## 2. Что точно захвачено, а что восстановлено из кода

### Точно захвачено HAR

- 13 сетевых запросов;
- ответ `GET /api/v1/bug-report/categories`, статус `200`, `application/json`;
- наличие cookie `SESSION` в запросе;
- отсутствие `Authorization: Bearer ...`;
- base URL и поведение интерфейса, находящиеся в загруженном JS;
- полный список документов и клиентская конфигурация формы.

### Восстановлено из загруженного JavaScript, но не выполнено в HAR

- `POST /autocomplete`;
- `POST /autocomplete/by-personal-info`;
- `GET /departments/filter`;
- `GET /auditories/filter`;
- `POST /bug-report`;
- формы запросов, клиентская обработка ошибок и ожидаемые поля ответов.

### Нельзя доказать по этому HAR

- точный ответ и точный код успеха `POST /bug-report`;
- точные DTO autocomplete endpoint’ов;
- доступность `GET /bug-report/categories` без сессии;
- серверные лимиты и серверная валидация файлов;
- фактические ответы PDF-ссылок, потому что документы не открывались;
- endpoint логина и получение `SESSION`.

## 3. Архитектура и последовательность работы

1. Пользователь открывает `/support`.
2. SPA динамически загружает support chunk и Excalidraw-зависимости.
3. Выполняется `GET /api/v1/bug-report/categories`.
4. Полученные категории объединяются с локальной конфигурацией **по `categoryKey`**.
5. Если пользователь уже авторизован:
   - для `EMPLOYEE` подставляются ФИО, email, телефон, подразделение и помещение;
   - для `STUDENT` подставляются ФИО, email, телефон и группа.
6. При уходе фокуса из ФИО или email вызывается autocomplete по персональным данным, если оба значения заполнены и хотя бы одно изменилось.
7. Пользователь выбирает категорию и, когда подкатегорий больше одной, подкатегорию.
8. При отправке собирается `multipart/form-data`.
9. Секция документов отображается независимо от формы и не требует предварительной загрузки списка.

## 4. Авторизация и сетевой клиент

В JavaScript создан один Axios-клиент:

```text
baseURL = https://iis.bsuir.by/api/v1
withCredentials = true
```

В захваченном запросе к категориям присутствует cookie `SESSION`. Заголовка `Authorization` нет. Аналитические cookies к API-логике отношения не имеют.

Для iOS:

- переиспользовать уже авторизованный `URLSession`;
- хранить сессию в `HTTPCookieStorage` или существующем cookie-хранилище;
- не хардкодить `SESSION`;
- не логировать cookies, пароль, ФИО, email и multipart-тело;
- CORS для нативного клиента не является ограничением браузера, но сервер всё равно может проверять сессию.

Отдельного CSRF-токена или CSRF-заголовка в коде формы не видно. Это не гарантирует, что сервер не выполняет иные проверки.

## 5. Endpoint’ы функции техподдержки

| Метод | URL | Назначение | Захвачен |
|---|---|---|---|
| `GET` | `https://iis.bsuir.by/api/v1/bug-report/categories` | Категории и подкатегории | да |
| `POST` | `https://iis.bsuir.by/api/v1/autocomplete` | Заполнение данных по логину/паролю | нет, восстановлен из JS |
| `POST` | `https://iis.bsuir.by/api/v1/autocomplete/by-personal-info` | Поиск подсказок по ФИО и email | нет, восстановлен из JS |
| `GET` | `https://iis.bsuir.by/api/v1/departments/filter?searchValue=...` | Поиск подразделения | нет, восстановлен из JS |
| `GET` | `https://iis.bsuir.by/api/v1/auditories/filter?searchValue=...` | Поиск помещения | нет, восстановлен из JS |
| `POST` | `https://iis.bsuir.by/api/v1/bug-report` | Отправка заявки и файлов | нет, восстановлен из JS |

### 5.1. `GET /bug-report/categories`

**Запрос:** без query/body.  
**Захваченный ответ:** `200 application/json`, массив из 12 категорий.

DTO:

```swift
struct BugReportCategoryDTO: Decodable, Identifiable {
    let id: Int
    let categoryName: String
    let categoryKey: String
    let bugReportSubcategoriesDto: [BugReportSubcategoryDTO]
}

struct BugReportSubcategoryDTO: Decodable, Identifiable {
    let id: Int
    let subcategoryName: String
    let subcategoryKey: String
}
```

При любой ошибке веб-интерфейс показывает полноэкранную ошибку загрузки и предлагает обновить страницу.

### 5.2. `POST /autocomplete`

JSON body:

```json
{
  "login": "string",
  "password": "string"
}
```

По использованию ответа интерфейс ожидает объект примерно такой формы:

```json
{
  "fio": "string or null",
  "email": "string or null",
  "phone": "string or null",
  "accountType": "EMPLOYEE or STUDENT or another value",
  "department": "string or null",
  "room": "string or null",
  "building": "string or null",
  "group": "string or null"
}
```

Это **инференс из кода**, а не захваченный ответ.

Обработка ошибок:

- `401` → «Неверный пароль.»
- `404` → «Не удалось найти учетную запись.»
- прочие статусы → модальное окно закрывается без надёжного разбора тела ответа.

Логин валидируется regex `^[a-zA-Z0-9.]+$`. Пароль только обязателен. Пароль нельзя сохранять.

### 5.3. `POST /autocomplete/by-personal-info`

JSON body:

```json
{
  "fio": "string",
  "email": "string"
}
```

Триггер: `onBlur` поля ФИО или email, если оба значения непустые и хотя бы одно изменилось после предыдущей проверки.

Ожидаемые ключи ответа:

```json
{
  "phone": "string or null",
  "department": "string or null",
  "room": "string or null",
  "building": "string or null"
}
```

Пустой объект допустим. Web-клиент:

- автоматически подставляет только отсутствующий телефон;
- сохраняет `department`, `room`, `building` как предлагаемые варианты для выпадающих списков;
- не перезаписывает уже введённые значения.

### 5.4. `GET /departments/filter`

Query:

```text
searchValue=<trimmed user input>
```

Ожидаемый массив:

```json
[
  {
    "name": "string",
    "abbrev": "string",
    "code": "non-null value"
  }
]
```

Клиент отбрасывает элементы, где `code == null`, и строит:

```text
label = value = "<name> (<abbrev>)"
```

### 5.5. `GET /auditories/filter`

Query:

```text
searchValue=<trimmed user input>
```

Ожидаемый массив:

```json
[
  {
    "name": "string",
    "buildingNumber": "string or number"
  }
]
```

Клиент строит:

```text
label = value = "<name>-<buildingNumber>"
```

### 5.6. `POST /bug-report`

Тип: `multipart/form-data`.

Части:

| Part | Когда отправляется | Значение |
|---|---|---|
| `lastName` | всегда | нормализованная фамилия или всё ФИО для формата «Фамилия И.О.» |
| `firstName` | всегда | имя или пустая строка |
| `middleName` | всегда | отчество/остаток ФИО или пустая строка |
| `subject` | всегда | категория, подкатегория либо контекст экрана ИИС |
| `browser` | всегда | `<browserName> <fullBrowserVersion>` |
| `labels` | всегда | контекстные метки для ошибки ИИС, иначе пустая строка |
| `categoryId` | при выбранной категории | integer как текст multipart |
| `subcategoryId` | при выбранной подкатегории | integer как текст multipart |
| `email` | всегда | email |
| `phone` | если поле есть у категории и значение непустое | строка |
| `department` | аналогично | строка вида `<name> (<abbrev>)` |
| `roomBuilding` | аналогично | строка вида `<room>-<building>` |
| `computerName` | аналогично | строка |
| `printerName` | аналогично | строка |
| `inventoryNumber` | аналогично | строка |
| `group` | аналогично | строка |
| `description` | всегда | описание; у `[ActEquip]` оно может быть необязательным |
| `acts` | если есть строки | JSON-строка массива |
| `files[0]`, `files[1]`... | если есть вложения | binary file |
| `url` | если экран открыт из другого раздела | предыдущий route/path |

Тело ответа веб-клиент игнорирует. Любой resolved Axios response считается успехом; любой reject показывает общую ошибку. Точный status code в HAR отсутствует.

### Пример multipart без бинарных данных

```text
lastName=Иванов
firstName=Иван
middleName=Иванович
subject=[PC-Repair] Неисправности
browser=MyIIS iOS 1.0
labels=
categoryId=5
subcategoryId=4
email=user@example.com
phone=...
department=...
roomBuilding=...
computerName=...
inventoryNumber=...
description=...
files[0]=<binary>
```

В iOS **не выставляй просто `multipart/form-data` без boundary**. Boundary и корректные `Content-Disposition` должны формироваться сетевым слоем.

## 6. Секция «Документы»

Список зашит в JavaScript-массив. Компонент проходит по группам и строит ссылки:

```text
href = "https://iis.bsuir.by/" + item.path
target = "_blank"
```

Никакой предварительной проверки доступности, авторизации или локальной сети нет.

| № | Группа | Документ | URL | Доступ |
|---|---|---|---|---|
| 1.1 | Система для организации выполнения заявок от структурных подразделений и пользователей | Стандартный набор ПО | `https://iis.bsuir.by/public_iis_files/softwareList.pdf` | публичная ссылка |
| 2.1 | Настройки компьютерной сети | Руководство для настройки Wi‑Fi | `https://iis.bsuir.by/public_iis_files/wifiGuide.pdf` | публичная ссылка |
| 2.2 | Настройки компьютерной сети | Настройка OpenVPN | `https://iis.bsuir.by/public_iis_files/setupOpenVPN.pdf` | публичная ссылка |
| 3.1 | Политика безопасности в отношении обработки персональных данных БГУИР | Политика обработки файлов cookie | `https://iis.bsuir.by/public_iis_files/cookiePolicy.pdf` | публичная ссылка |
| 3.2 | Политика безопасности в отношении обработки персональных данных БГУИР | Инструкция по смене пароля | `https://iis.bsuir.by/public_iis_files/changePasswordLDAP.pdf` | публичная ссылка |
| 4.1 | Политика безопасности БГУИР | Политика безопасности университета | `https://iis.bsuir.by/iis_files/privacyPolicy.pdf` | только локальная сеть БГУИР |
| 4.2 | Политика безопасности БГУИР | Список ответственных за соблюдение политики безопасности | `https://iis.bsuir.by/iis_files/privacyPolicyList.pdf` | только локальная сеть БГУИР |
| 4.3 | Политика безопасности БГУИР | Инструкция по настройке ПК в структурных подразделениях | `https://iis.bsuir.by/iis_files/pcSettings.pdf` | только локальная сеть БГУИР |

У группы 4 в интерфейсе есть красная информационная иконка и tooltip:

> Доступно только из локальной сети БГУИР

Ограничение не реализовано на клиенте. Клиент лишь показывает предупреждение; фактический доступ ограничивается сервером или сетью.

В HAR ни одна PDF-ссылка не открывалась. Поэтому фактический status code, `Content-Type`, размер файлов и поведение вне сети БГУИР не зафиксированы.

## 7. Категории, подкатегории и поля формы

`*` означает обязательное поле. Поля `fio` и `email` обязательны для всех категорий и в таблице не повторяются.

| ID | Категория | Key | Локальные поля | Подкатегории из API |
|---:|---|---|---|---|
| 2 | ИИС «БГУИР: Университет» | `[ИИС]` | `description`* | нет |
| 1 | Cистема «Студенты» | `[СТУДЕНТЫ]` | `description`* | нет |
| 5 | Компьютерная техника и ПО | `[PC-Software]` | `phone`*, `department`*, `roomBuilding`*, `computerName`*, `inventoryNumber`*, `description`* | Неисправности `[PC-Repair]` (id 4); Установка и обновление ПО `[PC-InstallSoft]` (id 7); Активация ПО `[PC-KEY]` (id 8); Первичная настройка компьютера `[PC-NewUser]` (id 5); Антивирус Kaspersky `[PC-Antivirus]` (id 9); Другое `[OS-Other]` (id 6) |
| 3 | Учетная запись | `[Network-Account]` | `phone`*, `department`*, `description`* | нет |
| 8 | Принтеры и МФУ | `[Print]` | `phone`*, `department`*, `roomBuilding`*, `computerName`*, `printerName`*, `inventoryNumber`*, `description`* | Обслуживание и ремонт `[Print-Repair]` (id 17); Подключение, настройка `[Print-Connect]` (id 18); Другое `[Print-Other]` (id 19) |
| 7 | Компьютерная сеть | `[Network]` | `phone`*, `department`*, `roomBuilding`*, `computerName`*, `description`* | Проблемы с сетью и интернетом `[Network-Offline]` (id 13); Кабельное подключение `[Network-Connection]` (id 15); Другое `[Network-Other]` (id 16) |
| 9 | Акт о непригодности оборудования | `[ActEquip]` | `acts`*, `description` | нет |
| 10 | Система электронного обучения | `[LMS]` | `phone`*, `description`* | нет |
| 4 | СЭД «SMBusiness» | `[SMB]` | `phone`*, `department`*, `roomBuilding`*, `computerName`*, `description`* | Установка `[SMB-Install]` (id 2); Создание учетной записи `[SMB-Account]` (id 1); Другое `[SMB-Other]` (id 3) |
| 6 | Карта работника/студента | `[ID-Card]` | `description`*, `phone`* | нет |
| 12 | Учебный отдел | `[UMU]` | `phone`*, `description`* | нет |
| 11 | Нет в списке возникшей проблемы | `[Other]` | `phone`*, `description`* | нет |

### Информационные сообщения

**`[PC-Software]`:**

1. В отношении кафедр ЦИИР оказывает только услуги по ремонту техники; по остальным вопросам следует обращаться к инженерам кафедры.
2. Для приобретения запасных частей требуется докладная записка на имя курирующего проректора.

**`[Print]`:**

1. Для приобретения запасных частей требуется докладная записка на имя курирующего проректора.
2. По замене картриджей следует обращаться в отдел снабжения.

### Важная архитектурная деталь

Сервер **не возвращает `fields`**. Web-клиент после загрузки выполняет merge:

```text
serverCategory + localConfig.find(config.categoryKey == serverCategory.categoryKey)
```

Следовательно:

- использовать `categoryKey` как стабильный идентификатор бизнес-логики;
- не использовать `categoryName` для маппинга;
- неизвестная новая категория сервера должна обрабатываться безопасно;
- оригинальный web-клиент потенциально хрупок: неизвестная категория может оказаться без массива `fields`.

## 8. Валидация

### Общие данные

**ФИО**

- обязательно;
- regex: `^[a-zA-Zа-яА-ЯЁёЎўІі.'\- ]+$`;
- пробелы схлопываются;
- строка trim;
- первая буква и буквы после начала строки, пробела или точки переводятся в uppercase.

Разделение перед отправкой:

- если строка похожа на `Фамилия И.О.`, всё значение помещается в `lastName`, а `firstName`/`middleName` остаются пустыми;
- иначе первый токен → `lastName`, второй → `firstName`, остальные объединяются в `middleName`.

Это странная, но фактическая логика web-клиента.

**Email**

- обязательно;
- стандартная проверка email;
- адрес, заканчивающийся на `@tut.by`, отклоняется;
- проверка suffix в JavaScript case-sensitive.

### Поля категории

- `phone`: проверяется обязательность и запрет строки только из пробелов; формата номера нет.
- `department`: обязательность, серверный поиск.
- `roomBuilding`: обязательность, серверный поиск.
- `computerName`: обязательность и не только пробелы.
- `printerName`: обязательность и не только пробелы.
- `inventoryNumber`: `^[а-яА-ЯёЁ0-9]+$`.
- `group`: `^((\d{6})|(\dA\d{4}))$`.
- `description`: trim и обязательность по конфигурации.
- подкатегория показывается и обязательна только если `subcategories.count > 1`.

### Вложения

Общий лимит:

```text
52 428 800 bytes = 50 MiB
```

Проверки:

- файл не пустой;
- имя не содержит `..`;
- расширение обязательно;
- суммарный размер не превышает 50 MiB;
- блокируются расширения:

```text
.ade, .adp, .apk, .appx, .appxbundle, .bat, .cab, .chm, .cmd, .com, .cpl, .dll, .dmg, .exe, .hta, .ins, .isp, .iso, .jar, .js, .jse, .lib, .lnk, .mde, .msc, .msi, .msix, .msixbundle, .msp, .mst, .nsh, .pif, .psl, .scr, .sct, .shb, .sys, .vb, .vbe, .vbs, .vxd, .wsc, .wsf, .wsh
```

`accept`-подсказка браузеру:

```text
.txt, .htm, .html, .zip, .doc, .docx, image/*, video/*, audio/*, .xml, .xls, .xlsx, .pptx, .rtf, .csv, .pub, .odt, .pdf
```

Критичный нюанс: сравнение запрещённых расширений в этом build case-sensitive. Например, клиентская проверка `.EXE` не эквивалентна `.exe`. Нативное приложение должно нормализовать расширение в lowercase, но сервер всё равно обязан валидировать файл самостоятельно.

### Акты о непригодности

Для `[ActEquip]` обязательна минимум одна полностью заполненная строка:

```text
department
equipmentType
inventoryNumber
year
fullName
phoneNumber
```

- `year`: ровно четыре цифры;
- `phoneNumber`: `+375`/`375` + 9 цифр либо 4–12 цифр;
- перед отправкой `key` строки меняется с нумерации `0...` на `1...`;
- `acts` передаётся одной JSON-строкой в multipart.

Пример:

```json
[
  {
    "key": 1,
    "department": "...",
    "equipmentType": "...",
    "inventoryNumber": "...",
    "year": "2021",
    "fullName": "...",
    "phoneNumber": "+375291234567"
  }
]
```

## 9. Логика subject, labels и контекста экрана

По умолчанию:

```text
[Other] Нет в списке возникшей проблемы
```

При выборе категории:

```text
<categoryKey> <categoryName>
```

При выборе подкатегории:

```text
<subcategoryKey> <subcategoryName>
```

Для заявки по ошибке ИИС:

- если support открыт напрямую, subject = `[ИИС] «БГУИР: Университет»`;
- если support открыт кнопкой жалобы с другого экрана, subject и labels определяются по route map;
- предыдущий путь дополнительно отправляется как multipart part `url`.

Route map приведён в приложении к отчёту и в JSON-контракте.

## 10. Скриншот ошибки

При нажатии кнопки жалобы на другом экране web-клиент:

1. находит DOM-узел `#capture-root`;
2. снимает всю область по `scrollWidth`/`scrollHeight` с `useCORS: true`;
3. переходит на `/support`, передавая изображение и `prevPath` через router state;
4. автоматически выбирает категорию `[ИИС]`;
5. показывает локальный редактор Excalidraw 0.14.2;
6. при отправке экспортирует результат в JPEG;
7. добавляет его как следующий `files[n]` с именем `screenshot.jpg`.

Никакой загрузки сцены Excalidraw в облако в этом flow не зафиксировано. В support-коде экспорт выполняется локально.

Для iOS разумный эквивалент:

- передать screenshot/UIImage в support flow;
- дать пользователю нарисовать разметку через PencilKit;
- экспортировать JPEG;
- добавить к multipart как очередной `files[n]`.

## 11. Рекомендованная структура iOS

```text
Support/
├── Models/
│   ├── BugReportCategoryDTO.swift
│   ├── BugReportSubcategoryDTO.swift
│   ├── SupportFormState.swift
│   ├── SupportField.swift
│   ├── SupportDocument.swift
│   └── EquipmentAct.swift
├── Networking/
│   ├── SupportService.swift
│   ├── MultipartFormDataBuilder.swift
│   └── SupportAPIError.swift
├── Domain/
│   ├── SupportCategoryConfiguration.swift
│   ├── SupportValidation.swift
│   ├── FIOParser.swift
│   └── SupportSubjectBuilder.swift
├── Presentation/
│   ├── SupportView.swift
│   ├── SupportViewModel.swift
│   ├── DocumentsSection.swift
│   ├── CategoryFormSection.swift
│   └── ScreenshotMarkupView.swift
└── Tests/
    ├── SupportCategoryConfigurationTests.swift
    ├── FIOParserTests.swift
    ├── MultipartBuilderTests.swift
    └── SupportDecodingTests.swift
```

### Поведение ViewModel

- `load()` → categories;
- enrich categories локальной конфигурацией по `categoryKey`;
- prefill from current user;
- debounce серверного поиска подразделений/помещений;
- autocomplete по ФИО/email — после завершения редактирования, только при изменении;
- отдельное состояние загрузки/ошибки для categories, suggestions, submit;
- неизвестные JSON-поля игнорировать;
- optional response fields декодировать мягко;
- не сохранять пароль;
- не логировать PII.

## 12. Готовое задание для другой нейросети

```text
Ты реализуешь в существующем iOS-приложении на Swift/SwiftUI экран «Техническая поддержка» для ИИС БГУИР. Используй приложенную спецификацию и JSON-контракт как единственный источник истины. Не выдумывай поля или ответы сервера.

Требования:
1. Создай отдельный SupportService/SupportRepository поверх уже существующего авторизованного URLSession. Базовый URL: https://iis.bsuir.by/api/v1. Сессия cookie-based; не добавляй Bearer-токен, если его нет в текущем сетевом слое.
2. Реализуй методы:
   - GET /bug-report/categories
   - POST /autocomplete
   - POST /autocomplete/by-personal-info
   - GET /departments/filter?searchValue=
   - GET /auditories/filter?searchValue=
   - POST /bug-report как multipart/form-data
3. Категории приходят с сервера, но набор полей формы и информационные предупреждения маппятся локально по categoryKey. Не маппь по отображаемому названию.
4. Вкладка/секция «Документы» не имеет API: выведи четыре локально заданные группы и восемь PDF-ссылок в точности из спецификации. Для группы 4 покажи пометку «Доступно только из локальной сети БГУИР». Открывай PDF через SFSafariViewController или системный просмотрщик.
5. Повтори правила валидации, ограничения вложений, логику подкатегорий и сборку multipart. Multipart boundary должен формироваться корректно URLSession-слоем.
6. Не сохраняй пароль из /autocomplete. Не логируй Cookie, пароль, персональные данные и multipart-тело.
7. Для ответов, которые в HAR не были захвачены, декодируй терпимо: optional-поля, неизвестные ключи игнорировать. Ошибки 401/404 у /autocomplete обработай отдельно; остальные ошибки показывай как общую сетевую ошибку.
8. Добавь модели, сетевой слой, ViewModel с async/await, SwiftUI-экран, unit-тесты на:
   - маппинг categoryKey → поля;
   - формирование subject;
   - FIO normalization/splitting;
   - multipart parts;
   - лимит 50 MiB и запрещённые расширения;
   - декодирование captured categories response.
9. В конце перечисли все созданные/изменённые файлы и отдельно укажи места, где контракт остаётся предположением и нужен тест на реальном сервере.

```

Передавай нейросети вместе:

1. этот Markdown;
2. `support_contract.json`;
3. при необходимости обезличенный HAR, но не оригинальный файл с cookies.

## 13. Все запросы, фактически присутствующие в HAR

| # | Метод | Status | URL | MIME | Decoded bytes |
|---:|---|---:|---|---|---:|
| 0 | `GET` | `200` | `https://iis.bsuir.by/support` | `text/html` | 1648 |
| 1 | `GET` | `200` | `https://iis.bsuir.by/manifest.json` | `application/json` | 506 |
| 2 | `GET` | `200` | `https://iis.bsuir.by/static/js/main.ceb2ed79.js` | `application/javascript` | 2881415 |
| 3 | `GET` | `200` | `https://iis.bsuir.by/static/css/main.3bac0d4b.css` | `text/css` | 419986 |
| 4 | `GET` | `200` | `https://iis.bsuir.by/static/media/lora-v20-cyrillic-regular.4e608b6f1dfbbcf568bb.woff2` | `font/woff2` | 26940 |
| 5 | `GET` | `200` | `https://iis.bsuir.by/static/js/5008.10202704.chunk.js` | `application/javascript` | 12339 |
| 6 | `GET` | `200` | `https://iis.bsuir.by/static/js/4516.d7d35200.chunk.js` | `application/javascript` | 928815 |
| 7 | `GET` | `200` | `https://iis.bsuir.by/static/css/1252.6235b568.chunk.css` | `text/css` | 14000 |
| 8 | `GET` | `200` | `https://iis.bsuir.by/static/js/1252.cf9c347e.chunk.js` | `application/javascript` | 58070 |
| 9 | `GET` | `200` | `https://unpkg.com/@excalidraw/excalidraw@0.14.2/dist/excalidraw-assets/vendor-53d1c69ef585b6dd219b.js` | `text/javascript` | 0 |
| 10 | `GET` | `200` | `https://iis.bsuir.by/api/v1/bug-report/categories` | `application/json` | 2919 |
| 11 | `GET` | `200` | `https://iis.bsuir.by/static/media/lora-v20-cyrillic-700.17757007a4506a5d2d53.woff2` | `font/woff2` | 27296 |
| 12 | `GET` | `200` | `https://iis.bsuir.by/static/media/lora-v20-cyrillic-500.54e1b80175cad6c20ad7.woff2` | `font/woff2` | 28280 |

`unpkg.com/...vendor...js` имеет пустое тело в HAR (`size = 0`, `bodySize = -1`), вероятно из-за кэша или особенностей экспорта. Это не endpoint бизнес-логики.

## 14. Загруженные, но не используемые support flow endpoint’ы

- `GET https://iis.bsuir.by/api/v1/departments/tree` — находится в том же модуле работы с подразделениями, но support-форма вызывает только `/departments/filter`.
- `GET https://iis.bsuir.by/api/v1/swagger` — ссылка для администратора, не часть функции поддержки.
- `https://json.excalidraw.com/api/v2/` — константа внутри библиотеки Excalidraw; запрос в HAR отсутствует, support-экспорт локальный.

## 15. Route map для контекстных заявок `[ИИС]`

| Path | Subject | Labels |
|---|---|---|
| `/about` | [ИИС] Страница "о нас" | `` |
| `/api` | [ИИС] Документация | `Documentation` |
| `/departments/` | [ИИС] Список работников подразделения | `Departments Tree, Employees` |
| `/departments` | [ИИС] Дерево подразделений | `Departments Tree` |
| `/employees/` | [ИИС] Персональная страница работника | `Employee Personal Page` |
| `/list-of-disciplines` | [ИИС] Список дисциплин | `Disciplines` |
| `/login` | [ИИС] Форма входа в систему | `Auth` |
| `/new-password` | [ИИС] Создание нового пароля | `Password Change` |
| `/phones` | [ИИС] Телефонный справочник | `Phones` |
| `/rating-of-students` | [ИИС] Рейтинг | `Students Rating` |
| `/schedule` | [ИИС] Расписание | `Schedule` |
| `/calendar` | [ИИС] Календарь учебных недель | `Calendar` |
| `/` | [ИИС] Главная страница | `` |
| `/personal-account/profile` | [ИИС] Личный кабинет. Профиль | `Personal Account, Profile` |
| `/personal-account/markbook` | [ИИС] Личный кабинет. Зачетка | `Personal Account, Markbook` |
| `/personal-account/study` | [ИИС] Личный кабинет. Учеба | `Personal Account, Study` |
| `/personal-account/library` | [ИИС] Личный кабинет. Библиотека | `Personal Account, Library` |
| `/personal-account/settings` | [ИИС] Личный кабинет. Настройки | `Personal Account, Settings` |
| `/personal-account/rating` | [ИИС] Личный кабинет. Рейтинг | `Personal Account, Rating` |
| `/personal-account/headman` | [ИИС] Личный кабинет. Староста | `Personal Account, Headman` |
| `/personal-account/group` | [ИИС] Личный кабинет. Группа | `Personal Account, Group` |
| `/personal-account/dormitory` | [ИИС] Личный кабинет. Общежитие | `Personal Account, Dormitory` |
| `/personal-account/announcements` | [ИИС] Личный кабинет. Объявления | `Personal Account, Announcements` |
| `/personal-account/penalty` | [ИИС] Личный кабинет. Взыскания | `Personal Account, Penalty` |
| `/personal-account/social-and-research-work` | [ИИС] Личный кабинет. Активность | `Personal Account, Social and Research Work` |
| `/personal-account/profiling` | [ИИС] Личный кабинет. Профилизация | `Personal Account, Profiling` |
| `/personal-account/lessons` | пустая строка | `Personal Account, Lessons` |
| `/personal-account/graduate` | пустая строка | `Personal Account, Graduate` |
| `/personal-account/omissions` | [ИИС] Личный кабинет. Пропуски | `Personal Account, Omissions` |
| `/personal-account/gradebook` | [ИИС] Личный кабинет. Журнал успеваемости | `Personal Account, Gradebook` |
| `/personal-account/users` | [ИИС] Личный кабинет. Пользователи | `Personal Account, Users` |
| `/personal-account/diploma-students` | [ИИС] Личный кабинет. Дипломники | `Personal Account, Diploma Students` |
| `/personal-account/positions` | [ИИС] Личный кабинет. Должности | `Personal Account, Positions` |
| `/personal-account/educational-work` | [ИИС] Личный кабинет. Учебная работа | `Personal Account, Educational Work` |

Для динамических путей вида `/departments/<id-or-name>` и `/employees/<id-or-name>` web-клиент берёт название базового route и добавляет последний компонент. Для personal-account такой fallback намеренно не применяется.
