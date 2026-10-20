# Аудит архитектуры BraineeApp

Дата аудита: 2026-10-20. Коммит: `f7c67b2` (ветка `main`, рабочее дерево чистое).
Метод: чтение исходного кода и настроек проекта, прогон юнит-тестов. Исходный код не менялся.

> Обозначения: **[факт]** — проверено в коде (указан файл/символ); **[вывод]** — моя интерпретация фактов; **[?]** — не проверено, см. «Открытые вопросы».

---

## 1. Главный вывод

Бриф предполагает, что «SwiftData станет основным хранилищем, а JSON нужно мигрировать». Фактически **SwiftData уже используется, но только как оперативная копия в памяти**:

- **[факт]** `BraineeApp/BraineeAppApp.swift` → `sharedModelContainer` создаёт `ModelConfiguration(schema:, isStoredInMemoryOnly: true)`.
- **[факт]** Источник правды — JSON-файлы `Documents/BraineeApp/mytasks.json` и `profile.json` + полная копия этих файлов в Keychain (`AppDataStore`, `KeychainStorage`).
- **[факт]** При каждом запуске `AppDataPersistence.bootstrap(into:)` очищает SwiftData (`clearAllData`) и заново импортирует JSON.
- **[факт]** После каждого изменения экран вызывает `modelContext.persistToJSON()`, которое переписывает **весь** JSON, Keychain-копию, снимок виджета и **все** локальные уведомления.

Следствие **[вывод]**: задача «миграции» — это не создание моделей с нуля, а (1) включение постоянного хранилища у уже существующих `@Model`, (2) однократный перенос данных из JSON, (3) отказ от `clearAllData` при старте, (4) смена роли JSON и Keychain. Это меньше работы по UI, но **опаснее** по данным: строка `clearAllData` в `bootstrap` при постоянном хранилище удалит все данные пользователя.

---

## 2. Фактическая карта проекта

| Путь | Назначение |
|------|-----------|
| `BraineeApp/BraineeAppApp.swift` | `@main`, in-memory `ModelContainer`, `AppDelegate` через `@UIApplicationDelegateAdaptor` |
| `BraineeApp/Views/AppRootView.swift` | Splash, вызов `AppDataPersistence.bootstrap`, запрос прав на уведомления, экран ошибки загрузки |
| `BraineeApp/Views/AnimatedMainTabView.swift` | Кастомный таб-бар; вкладки из `Models/MainTab.swift`: Задачи, Календарь, Матрица, Привычки, Профиль (Календарь/Матрица/Привычки отключаемы через `TabBarSettings`) |
| `BraineeApp/Models/` | `@Model`: `TaskItem`, `TaskGroup`, `TaskTag`, `Habit`, `UserProfile`; enum'ы `TaskStatus`, `TaskPriority`, `TaskCategory`, `TaskReminderOffset`, `AppTheme`, `AccentPalette`, `UserGender`; DTO `TaskFormData`, `TaskFormSnapshot` |
| `BraineeApp/Persistence/` | `AppDataStore` (файлы + Keychain), `AppDataPersistence` (SwiftData ↔ JSON), `AppDataDocuments` (`MyTasksDocument`, `ProfileDocument`, `*Record`), `KeychainStorage` |
| `BraineeApp/Views/Tasks/` | Список/канбан задач, форма `AddEditTaskView`, `TaskSectionView` (корневой экран задач с мутациями) |
| `BraineeApp/Views/Calendar/CalendarWeekView.swift` | Внутренний недельный календарь по `deadline` задач. **Не EventKit.** |
| `BraineeApp/Views/Matrix/` | Матрица Эйзенхауэра |
| `BraineeApp/Views/Habits/` | Привычки, contribution-календарь |
| `BraineeApp/Views/Profile/` | Профиль, теги, удалённые, дашборд, настройки уведомлений/внешнего вида/таб-бара, FAQ |
| `BraineeApp/Utilities/` | Хелперы: уведомления (`AppNotifications`), бейдж (`AppBadgeSync`, `AppBadgeCounter`), виджет (`WidgetSnapshotBuilder`), сортировка, статистика (`TaskStats`), дизайн-система и др. |
| `BraineeShared/WidgetSnapshot.swift` | Общий с виджетом формат снимка; файл `widget_snapshot.json` в App Group `group.valeravalera.BraineeApp` |
| `BraineeAppWidget/` | WidgetKit: задачи на сегодня, привычки, дашборд, комбинированный |
| `BraineeAppTests/` | 32 файла (включая `TestHelpers.swift`), 142 теста на Swift Testing (`import Testing`) |
| `BraineeAppUITests/` | Шаблон Xcode (`testExample`, `testLaunch`), содержательных проверок нет |
| `TEST_SCENARIOS.md` | Ручные сценарии приёмки |
| `.cursorrules` | Правила для Cursor (частично устарели, см. §9) |

Объём: ~13,6 тыс. строк Swift. Крупнейшие файлы: `Views/Tasks/AddEditTaskView.swift` (758), `Views/Habits/HabitsView.swift` (469), `Views/Tasks/TaskOrganizedListView.swift` (460), `Persistence/AppDataDocuments.swift` (424).

### Навигация и точки входа

1. `BraineeAppApp` → `WindowGroup { AppRootView() }.modelContainer(sharedModelContainer)`.
2. `AppRootView.task`: `bootstrap` → `AppIconSwitcher.syncWithCurrentAccent()` → `OrientationLockSettings.apply` → `AppNotifications.requestPermissionOnFirstLaunchIfNeeded()` → `AppNotifications.refresh(from:)`.
3. `AnimatedMainTabView` (с модификатором `.persistOnBackground()`).
4. Deep link из пуша: `AppDelegate.userNotificationCenter(_:didReceive:)` → `NotificationDeepLinkRouter.shared.openTask(uuid:)` → `TaskSectionView.openTaskFromDeepLinkIfNeeded()`.
5. URL-схема `braineeapp://` (`BraineeApp-Info.plist`), используется виджетом (`WidgetSnapshotStore.openURL = braineeapp://open`).

---

## 3. Модели и текущее хранение

| Сущность (`@Model`) | Ключевые поля | Идентификатор | Связи | JSON-запись | Где в JSON |
|---|---|---|---|---|---|
| `TaskItem` | `title`, `isCompleted`, `statusRaw` (`new`/`inProgress`/`done`), `deadline`, `hasDeadlineTime`, `reminderOffsetsRaw: [String]` (до 3), `priorityRaw` (0–3), `categoryRaw` (всегда `tasks`), `taskDetails`, `sortOrder`, `createdAt`, `isSoftDeleted`, `deletedAt` | `uuid: UUID` | `group: TaskGroup?`, `tags: [TaskTag]` | `TaskRecord` (`id`, `groupID`, `tagIDs`, флаг удаления называется `isDeleted`) | `mytasks.json` → `tasks` |
| `TaskGroup` | `name`, `categoryRaw`, `sortOrder`, `createdAt` | `uuid` | `tasks` (inverse, `.nullify`) | `GroupRecord` | `mytasks.json` → `groups` |
| `TaskTag` | `name`, `createdAt` | `uuid` | `tasks` (inverse к `TaskItem.tags`) | `TagRecord` | `mytasks.json` → `tags` |
| `Habit` | `title`, `sortOrder`, `createdAt`, `completedDaysRaw` (JSON-строка массива `yyyy-MM-dd`) | `uuid` | — | `HabitRecord` (`completedDays: [String]`) | `mytasks.json` → `habits` |
| `UserProfile` | `displayName`, `avatarData: Data?`, `age`, `genderRaw`, `createdAt` | **нет uuid** | — | `ProfileDocument` (`avatarBase64`, + `appThemeRaw`, `accentPaletteRaw`) | `profile.json` |

Чего в моделях **нет** **[факт]**: `updatedAt`/версии записи, `completedAt` у задач, tombstone-записей для окончательно удалённых объектов, проектов, целей (goals), сессий фокуса, входящих (inbox). Бриф упоминает «цели и фокус» — в коде таких сущностей не найдено.

Версии формата: `MyTasksDocument.currentVersion = 8`, `ProfileDocument.currentVersion = 3`. Миграции старых версий делаются при decode (`TaskRecord.init(from:)`, v7→v8 напоминания) и в `MyTasksDocument.normalizeRecords()` (v3 слияние категорий, v5 статус, v6 время дедлайна, v8 напоминания).

### Данные вне SwiftData/JSON (UserDefaults, `@AppStorage`)

`appTheme`, `accentPalette`, `braineeHasLaunched`, `notificationSettings` (JSON в Data), `notificationDidRequestPermission`, `appIconBadgeMode`, `orientationLockPortrait`, `tabBarShowCalendar` / `tabBarShowMatrix` / `tabBarShowHabits`, `taskListDisplaySettings`. Тема и акцент дополнительно дублируются в `profile.json` (`AppDataPersistence.exportProfile`).

---

## 4. Все места чтения и записи

### 4.1 Файлы и Keychain (только `Persistence/`)

| Операция | Символ | Что происходит |
|---|---|---|
| Подготовка | `AppDataStore.prepareStorage()` | Создаёт `Documents/BraineeApp/`; если `mytasks.json` нет, а в Keychain есть копия — пишет её в файл (`reconcileTasksBackupIfNeeded`) |
| Чтение задач | `AppDataStore.loadTasks()` | Читает файл и Keychain, выбирает более свежий по `contentTimestamp` (`lastSavedAt`) |
| Запись задач | `AppDataStore.saveTasks(_:syncKeychain:)` | `normalizeRecords()` → атомарная запись файла → `KeychainStorage.save` (ошибка Keychain только печатается) |
| Чтение профиля | `AppDataStore.loadProfile()` | Файл, иначе Keychain, иначе `.empty`. Ошибка decode файла **пробрасывается** |
| Запись профиля | `AppDataStore.saveProfile(_:)` | Файл + Keychain; ошибка Keychain **пробрасывается** (в отличие от задач) |
| Keychain | `KeychainStorage.save/load` | `kSecClassGenericPassword`, service `valeravalera.BraineeApp.storage`, accounts `mytasks.json` / `profile.json`, `AfterFirstUnlockThisDeviceOnly` |
| Виджет | `WidgetSnapshotStore.save/load` (`BraineeShared/WidgetSnapshot.swift`) | `widget_snapshot.json` в контейнере App Group |

### 4.2 Вызовы `persistToJSON()` (все записи данных идут через него)

| Файл | Операции |
|---|---|
| `Views/Tasks/TaskSectionView.swift` | `addTask`, `updateTask`, `toggleTask`, `setStatus`, `deleteTask` (soft), `deleteGroup` (hard delete группы), `createGroup` |
| `Views/Tasks/TaskOrganizedListView.swift` | `confirmRenameGroup`, `assignTask(_:to:)` (drag-and-drop в группу) |
| `Views/Calendar/CalendarWeekView.swift` | `toggleTask`, `updateTask`, `softDelete` — **копии** логики из `TaskSectionView` |
| `Views/Matrix/EisenhowerQuadrantDetailView.swift` | `toggleTask`, `updateTask` + удаление — **копии** |
| `Views/Habits/HabitsView.swift` | `toggleHabit`, `addHabit`, `deleteHabit` (hard), переименование/порядок |
| `Views/Profile/DeletedTasksFolderView.swift` | восстановление, `permanentlyDelete`, `permanentlyDeleteSelected`, `permanentlyDeleteAll` (hard) |
| `Views/Profile/TagLibraryView.swift` | создание, переименование, удаление тега (hard) |
| `Views/Profile/ProfileView.swift` | `ensureProfile`, `saveProfile` |
| `Views/Profile/AppearanceSettingsView.swift` | тема, `applyAccent` |
| `Persistence/AppDataPersistence.swift` → `JSONPersistenceModifier` | при переходе в `.background` |

### 4.3 Побочные эффекты `persistToJSON()` (`AppDataPersistence.swift`)

1. `AppDataPersistence.export` — `context.save()` + полная перезапись обоих JSON и Keychain.
2. `WidgetSnapshotBuilder.publish` — снимок для виджета.
3. `AppNotifications.refresh` — `removeAllPendingNotificationRequests()` и пересоздание всех уведомлений + `AppBadgeSync.sync`.

---

## 5. Интеграции

| Область | Состояние | Где |
|---|---|---|
| Keychain | Используется как **резервная копия базы данных** (полные JSON, включая аватар в base64), а не для секретов | `KeychainStorage`, `AppDataStore` |
| Уведомления | Локальные: ежедневные (задачи, привычки), «скоро дедлайн» (до 3 пресетов), «просрочено» (11:00) | `Utilities/AppNotifications.swift`, `NotificationSettings.swift` |
| Бейдж иконки | Считается из задач | `AppBadgeSync`, `AppBadgeCounter`, `AppIconBadgeMode` |
| Виджеты | Снимок через App Group | `WidgetSnapshotBuilder`, `BraineeShared/WidgetSnapshot.swift`, `BraineeAppWidget/` |
| Календарь | **EventKit не используется** (нет `import EventKit`, нет usage-описаний в Info.plist) | — |
| Сеть | **Нет** `URLSession`/HTTP-кода | — |
| Файлы пользователя | **Нет** `fileImporter`/`fileExporter`/document picker/bookmarks. Есть entitlement `com.apple.security.files.user-selected.read-only` (влияет только на macOS-сборку) | `BraineeApp/BraineeApp.entitlements` |
| Импорт/экспорт JSON для пользователя | **Нет** (JSON лежит в Documents, но доступ в Files не включён — `UIFileSharingEnabled`/`LSSupportsOpeningDocumentsInPlace` отсутствуют) | `BraineeApp-Info.plist` |
| LLM, сервер, Telegram, Obsidian | Отсутствуют | — |

---

## 6. Сборка, платформы, зависимости

- Xcode-проект `BraineeApp.xcodeproj` (`objectVersion = 77`, file-system synchronized groups — новые файлы в папках подхватываются автоматически).
- Таргеты: `BraineeApp`, `BraineeAppWidget`, `BraineeAppTests`, `BraineeAppUITests`. Схемы: `BraineeApp`, `BraineeAppWidget`.
- `IPHONEOS_DEPLOYMENT_TARGET = 18.2`, `SWIFT_VERSION = 5.0`.
- **[факт]** Основное приложение объявляет `SUPPORTED_PLATFORMS = iphoneos iphonesimulator macosx xros xrsimulator`, `TARGETED_DEVICE_FAMILY = 1,2,7`; виджет — только iOS. **[?]** Собирается ли macOS/visionOS-вариант, не проверялось (`AppDelegate.swift` импортирует `UIKit` без условной компиляции).
- Bundle ID: `valeravalera.BraineeApp`, виджет `valeravalera.BraineeApp.Widget`. App Group `group.valeravalera.BraineeApp`.
- Сторонних зависимостей нет (нет SPM/CocoaPods). Фреймворки: SwiftUI, SwiftData, WidgetKit, UserNotifications, PhotosUI, Security, UIKit.
- Локальная среда: Xcode 27.0; симуляторы iOS 17.0, 17.5, 18.1, 18.3, 27.0.

### Команды (проверены в этой сессии)

```bash
xcodebuild test -project BraineeApp.xcodeproj -scheme BraineeApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' -only-testing:BraineeAppTests
```

Результат прогона: 142/142 passed (см. §7). Команда из `README.md` (`-destination 'platform=iOS Simulator,name=iPhone 16'`) на этой машине неоднозначна: «iPhone 16» есть в рантаймах 18.1 (ниже минимальной 18.2) и 18.3, поэтому нужно указывать `OS=`.

---

## 7. Тесты

- 142 теста Swift Testing в `BraineeAppTests/`, хелпер `TestHelpers.makeContainer()` (in-memory SwiftData).
- Покрыто: нормализация и обратная совместимость JSON (`MyTasksDocumentTests`, `ProfileDocumentTests`), логика задач/статусов/дедлайнов/напоминаний, привычки, сортировка, статистика, бейдж, снимок виджета, deep link, настройки.
- **Не покрыто** **[факт]**: `AppDataStore` (файл/Keychain, выбор свежей копии, восстановление), `AppDataPersistence.bootstrap/export` (round-trip JSON ↔ SwiftData), мутации во View (`addTask`/`updateTask` и т. п. — приватные методы View).
- UI-тесты — шаблон без проверок.

Результат прогона в этой сессии (2026-10-20, iPhone 16 / iOS 18.3.1): **142 passed, 0 failed, `** TEST SUCCEEDED **`**. UI-тесты не запускались (`-only-testing:BraineeAppTests`). Предупреждения сборки: только размеры macOS-иконок в `AppIcon.appiconset` (1024×1024 вместо 16…512).

---

## 8. Риски для миграции и дальнейшего развития

| # | Риск | Где | Почему важно |
|---|---|---|---|
| R1 | `clearAllData` в `bootstrap` при постоянном хранилище удалит все данные | `AppDataPersistence.bootstrap` | Критично: при включении persistent store этот путь обязан быть удалён/заменён в том же изменении |
| R2 | Битый `mytasks.json` молча превращается в `nil` (`try?` в `decodeTasksDocument`); если Keychain тоже пуст/битый — грузится `.empty`, и первый же `persistToJSON` перезапишет файл пустым | `AppDataStore.loadTasksFromFile`, `loadTasks` | Тихая потеря данных уже сейчас; миграция должна не повторить этот шаблон |
| R3 | `normalizeRecords()` молча отбрасывает привычки сверх 7, пустые названия, дубликаты UUID, «висячие» ссылки | `MyTasksDocument.normalizeRecords` | Миграция должна сравнивать данные **после** нормализации и логировать отброшенное |
| R4 | Нет `updatedAt` и tombstone-ов; окончательное удаление (задачи, группы, теги, привычки) бесследно | модели, `DeletedTasksFolderView`, `TagLibraryView`, `HabitsView` | Без этого невозможна корректная синхронизация удалений |
| R5 | `UserProfile` без `uuid`; тема/акцент живут и в UserDefaults, и в `profile.json` | `UserProfile`, `exportProfile` | Два источника правды для настроек |
| R6 | Keychain хранит полные JSON-документы, в т. ч. аватар (base64); ошибка Keychain ломает `saveProfile` | `AppDataStore.saveProfile` | Противоречит целевой роли Keychain (только секреты); размер элемента Keychain не предназначен для больших данных **[?] лимит не измерялся** |
| R7 | Бизнес-логика мутаций задач продублирована в 3 View | `TaskSectionView`, `CalendarWeekView`, `EisenhowerQuadrantDetailView` | Любые новые побочные эффекты (календарь, очередь синхронизации) придётся добавлять в 3 местах |
| R8 | Каждое изменение = полная перезапись JSON + Keychain + пересоздание всех уведомлений, на главном потоке | `persistToJSON` | Растёт с объёмом данных; при SwiftData-хранилище файл-экспорт на каждое изменение уже не нужен |
| R9 | Дни привычек — строки `yyyy-MM-dd` в **текущем часовом поясе устройства** | `Habit.dayKeyFormatter` | Для сервера/отчётов нужно явное правило часового пояса |
| R10 | `deadline` без времени хранится как `Date` (полночь локального дня) + `hasDeadlineTime` | `TaskItem` | Для календаря и сервера «дата без времени» должна передаваться как дата, а не момент времени |
| R11 | Нет пользовательского экспорта/бэкапа до начала миграции | Info.plist, отсутствие fileExporter | Перед любой миграцией нужен способ вынуть данные с устройства |
| R12 | `.cursorrules` и README частично устарели | см. §9 | Агенты могут следовать неверным правилам |

---

## 9. Расхождения документации с кодом

- `.cursorrules` → «вкладки Карьера, Спорт, Ментальное, Профиль» и `TaskCategory: career / sport / mental`. В коде: `TaskCategory` имеет единственный `case tasks`; вкладки — Задачи/Календарь/Матрица/Привычки/Профиль (`MainTab`).
- `.cursorrules` → `TaskPriority: low / medium / high`. В коде также `highest = 3`.
- `README.md` → команда тестов с `name=iPhone 16` без `OS=` (неоднозначна, см. §6).
- `README.md` → «Runtime-модели: SwiftData (in-memory на сессию)» — **верно**, согласуется с кодом.

---

## 10. Подтверждённые факты (сводка)

1. SwiftData уже есть, in-memory; 5 моделей; стабильные `uuid` у всех, кроме `UserProfile`.
2. Источник правды — JSON v8 / profile v3 + Keychain-зеркало.
3. Все записи проходят через `ModelContext.persistToJSON()`.
4. EventKit, сеть, файловый импорт/экспорт, LLM — отсутствуют.
5. Уведомления и виджеты пересчитываются из полного набора активных задач.
6. Зависимостей нет, минимальная iOS 18.2, Swift 5.
7. 142 юнит-теста, persistence-слой тестами не покрыт.

## 11. Открытые вопросы

1. Сущности «цели» и «фокус» из брифа — планируются или имелись в виду задачи/привычки? В коде их нет.
2. Нужна ли macOS/visionOS-сборка? Сейчас они объявлены в настройках таргета, но, вероятно, не поддерживаются.
3. Сколько данных на реальном устройстве (число задач, размер аватара)? Влияет на оценку R6/R8.
4. Есть ли на устройстве задачи/привычки, которые важно сохранить, — т. е. нужен ли бэкап перед миграцией (предполагаю: да).
5. Как iPhone будет достигать сервера на MacBook: одна Wi-Fi сеть, Tailscale или иное?
6. Какие данные должен видеть Telegram-бот: только задачи или также привычки?
