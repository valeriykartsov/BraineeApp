# BraineeApp

Личное iOS-приложение (SwiftUI) для задач, привычек и фокуса. Владелец — начинающий разработчик с опытом управления проектами: объясняй решения понятно, но точно; отвечай по-русски.

## Документы

- `docs/architecture-audit.md` — фактическое состояние кода, риски (R1…R12)
- `docs/target-architecture.md` — целевая архитектура
- `docs/implementation-roadmap.md` — задачи с ID (BASE-1, DOM-1, SD-1 …)
- `docs/decisions.md` — решения D-xx и их статусы
- `docs/acceptance-checklist.md` — что проверено
- `TEST_SCENARIOS.md` — ручные сценарии

## Как устроено сейчас

- SwiftData — **постоянное хранилище** `Application Support/BraineeApp/BraineeApp.store` (`ModelContainerFactory`, схема `SchemaV1`, `#Unique` на `uuid`). Это единственный источник правды. `Documents/BraineeApp/mytasks.json`/`profile.json` и Keychain-копии больше не пишутся (SD-4): они устарели и нужны только для переноса при первом запуске; не удалять без подтверждения (SD-6).
- Старт: `AppRootView` → `AppDataPersistence.bootstrap`. Без маркера `Application Support/BraineeApp/swiftdata-migration.json` — перенос JSON (`JSONToSwiftDataMigrator`: бэкап → upsert → проверка → маркер); с маркером JSON не читается. Хранилище при старте **никогда** не очищается. Откат на старую сборку не поддерживается (D-19).
- Любое изменение данных — только через сервисы `Domain/` (`TaskService`, `GroupService`, `TagService`, `HabitService`, `ProfileService`); они вызывают `modelContext.didChange()` (`AppSideEffects`: `save()` + виджет + уведомления). Во View не менять модели и не вызывать `didChange()` напрямую.
- Бэкап: при уходе в фон `AutoBackup` пишет `BackupDocument` (формат ручного экспорта, D-16) в `Application Support/Backups/auto/` — не чаще раза в 24 часа, последние 7 файлов (D-04). Восстановление — «Профиль → Хранение данных» (`BackupRestore`, D-20): замена всех данных, перед ней текущее состояние сохраняется в `Backups/pre-restore/`. Замена и сверка хранилища с документом — `StoreContents` (общий код с переносом JSON).
- Новые поля JSON — только через `decodeIfPresent` + значение по умолчанию и `MyTasksDocument.normalizeRecords()`.
- Флаг мягкого удаления в модели — `isSoftDeleted` (не `isDeleted`: конфликт с SwiftData); в JSON он называется `isDeleted`.
- Зависимостей нет (только Apple SDK). Мин. iOS 18.2, Swift 5.

## Принципы

1. Offline-first: локальные функции не зависят от сервера, LLM и сети.
2. Внешний идентификатор сущности — `uuid`, не `PersistentIdentifier`.
3. Бизнес-правила — в одном месте (целевое: `Domain/*Service`), не во View и не в нескольких слоях.
4. Без Docker/PostgreSQL/Redis/очередей/микросервисов и сторонних пакетов без явного решения в `docs/decisions.md`.
5. Одна задача roadmap за раз; не смешивать независимые подсистемы в одном изменении.
6. Только iOS (macOS/visionOS не поддерживаем). «Цели» и «фокус» — заметки Obsidian, не сущности приложения.

## Данные — строгие ограничения

- Не удалять и не перезаписывать пользовательские данные, Keychain-записи и старый путь хранения без явного подтверждения владельца.
- Никакой очистки хранилища при старте (риск R1): `clearAllData` удалён в SD-3 и не должен возвращаться.
- Любая миграция: бэкап → копирование → проверка → маркер → переключение. Повторный запуск не должен создавать дублей.
- Секреты (API-ключи, токены) — только в Keychain; не в коде, логах, `Info.plist`, UserDefaults.

## Сборка и тесты (проверено 2026-10-20)

```bash
xcodebuild test -project BraineeApp.xcodeproj -scheme BraineeApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' -only-testing:BraineeAppTests
```

Без `OS=` имя «iPhone 16» неоднозначно (есть рантайм 18.1 ниже минимальной версии). Долгие сборки запускать в фоне.
Если клон симулятора «застрял в создании», запускать на загруженном устройстве без клонирования: `-destination 'platform=iOS Simulator,id=<UDID>' -parallel-testing-enabled NO` (результаты тогда в формате `✔ Test … passed` / `✘`).
Тесты — Swift Testing (`import Testing`), в `BraineeAppTests/`, имена на русском `чтоПроверяем_ожидаемыйРезультат`, перед тестом комментарий; хелпер `TestHelpers.makeContainer()`.
`ModelContainer` в тестах хранить в свойстве тестовой структуры (`init() throws`), а не в локальной переменной: Swift может освободить её после последнего использования, и обращение к моделям роняет весь тестовый процесс.
В тестах сервисов передавать `onChange` (например, счётчик), чтобы не писать настоящие JSON/Keychain.

## Git

- Основная ветка `main`; работа в отдельной ветке на задачу, слияние через PR.
- Коммиты и push — только по просьбе владельца; никогда force push в `main`.
- Сообщения: `feat(...)`, `fix(...)`, `docs(...)`, `test(...)`, `refactor(...)`.
- Не менять Bundle ID, signing, entitlements, App Group без запроса.

## После каждой задачи

Перечислить: изменения (файлы), проверки (что запускалось и результат), риски, оставшуюся ручную работу. Отмечать пункты в `docs/acceptance-checklist.md` только после проверки.

`.cursorrules` частично устарел (категории career/sport/mental, вкладки) — при расхождении верить коду и этому файлу.
