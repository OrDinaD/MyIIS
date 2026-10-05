# Журнал старосты: контракт двух HAR от 2026-10-02

Источники: «Выставление пропусков.har» (28 entries) и «Староста темы и поропуски посмортел .har» (38 entries). Секреты, cookies, имена студентов и реальные идентификаторы сюда не перенесены. HAR подтверждает записанные ответы сайта, а не текущий сервер или права другого аккаунта.

## Запросы, действительно выполненные в HAR

| Метод | Путь /api/v1 | Вход | Ответ |
| --- | --- | --- | --- |
| GET | /headman/subjects | — | 200: объект предмет → массив {id, hasSubGroups, lessonTypeAbbrev, teacherInfo: {fullName, email?}} |
| GET | /headman/students | — | 200: массив {studentId, fullName, educationStatus, educationInfo} |
| GET | /headman/data | termHoursId | 200: {attendance, lessons, subgroupsCount} |
| POST | /headman/create | {studentOmissionsHoursDtoList: [{student, hours}], idLesson} | 201: объект studentId → {missedHours, respectfulOmission} |
| PUT | /headman/lessons/topic | {lessonId, topic} | 200: {lessonId, topic} |
| GET | /notifications/notViewed/count | — | 200 |
| GET | /notifications | pageNumber=0&pageSize=15 | 200 |
| PATCH | /notifications | тело уведомлений | 200 |
| GET | /ws | upgrade websocket | 101 |

Также загружались /personal-account/headman, JS/CSS chunks, manifest, favicon, logo, шрифты и metrika. Это ресурсы страницы, не API журнала.

attendance: {studentId, subGroup?, lessonRecords: объект lessonId → null либо {missedHours, respectfulOmission}, termHoursEducationInfo: {status, offsetMark?}}.
lessons: {id, date: YYYY-MM-DD, subgroup, topic?, numberOfHours}.
ID предмета здесь — termHoursId, а не ID отдельного занятия. Запись пропусков возвращает словарь, а не массив студентов. null означает отсутствие записи, а не доказательство присутствия.

## Найдено в JavaScript внутри HAR, но не выполнено

- GET /headman/responsible
- PUT /headman/responsible: массив studentId выбранных отмечающих; это видно из JS (Set и includes(studentId)), успешный ответ в HAR отсутствует.
- PUT /headman/assign-subgroups: {students: [{studentId, fio, subGroup}], termHoursIdList}; предусмотрен частичный ответ 207 со списком проблем.
- Код страницы показывает управление ответственными только при isGroupHead.
- Меню и маршрут доступны при isGroupHead || canStudentNote.

Ответ входа в этих HAR отсутствует. Приложение уже получает isGroupHead и canStudentNote из loginResponse; User.isHeadmanOrNoteAllowed объединяет их. Существующее включение beta sections остаётся обязательным. Сервер дополнительно проверяет сессию; 401/403 запрещают запись. Успешная локальная проверка флагов не заменяет серверную авторизацию.

## Реализация и границы

Журнал использует /headman, старые /grade-book методы не используются новой вкладкой. Чтение и запись используют существующий APIService и его SESSION-сессию. Данные не сохраняются в общий offline cache. Подгруппа проверяется по attendance.subGroup и lesson.subgroup. Уже выставленные пропуски не редактируются. Сохранение часов и темы требует отдельного подтверждения с конкретными данными.

POST/PUT не повторяются автоматически после транспортной ошибки. Если результат не подтверждён, требуется обновить журнал перед повторной отправкой. Подтверждённый ответ применяется локально без повторной отправки. Сводка считает только известные часы выбранной дисциплины и типа занятия; процент посещаемости не выдумывается.

Назначение ответственных и подгрупп не реализовано на неподтверждённых ответах из JS. Самостоятельное «подтверждение уважительности» не обнаружено: respectfulOmission приходит с сервера и не включён в create body. Фотографии бумажного журнала использованы как референс таблицы и отдельного листа тем; OCR и автоматическая отправка распознанных записей не выполняются.

Реальные записи в аккаунте в ходе разработки не отправлялись.

## Проверки реализации

BuildProject с buildForTesting завершился успешно, предупреждений в GetBuildLog нет. Строгий SwiftLint для семи затронутых Swift-файлов: 0 нарушений. Добавлены три теста формы HAR; RunSomeTests для них и проверки флагов User завершился таймаутом tools/call через 300 секунд, прохождение не подтверждено. RenderPreview заблокирован Missing watchos platform (watchOS 27.0). Визуальная и live-account проверка остаются незавершёнными.
