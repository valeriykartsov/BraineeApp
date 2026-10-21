# Тестирование BraineeApp

## Автотесты

Юнит-тесты — Swift Testing (`import Testing`) в `BraineeAppTests/`: 329 тестов в 50 наборах (2026-10-21). UI-тесты (`BraineeAppUITests/`) — шаблон Xcode, не используются.

```bash
scripts/test.sh                                   # все юнит-тесты (~20 с после сборки)
scripts/test.sh TaskServiceTests DayPlanServiceTests   # только указанные наборы (имя struct)
scripts/test.sh --build                           # только компиляция
```

Скрипт берёт загруженный симулятор iPhone (иначе iPhone 16 / iOS 18.3.1, можно задать `BRAINEE_SIM_ID`), отключает параллельные клоны и сбор диагностики, прерывает прогон через 10 минут. Полный лог — `$TMPDIR/braineeapp-test.log`, в консоль — только ошибки, `✘` и итог.

### Что покрыто

| Область | Наборы |
|---|---|
| Задачи и домен | `TaskServiceTests`, `TaskItemLogicTests`, `TaskCompletionOrderTests`, `TaskDeadlineTimeTests`, `TaskStatusTests`, `TaskStatsTests`, `TaskSortHelperTests`, `TaskInputValidationTests`, `TaskFormSnapshotTests`, `SoftDeleteAndGroupTests`, `GroupAndTagServiceTests`, `GroupCollapseLogicTests` |
| Привычки и профиль | `HabitTests`, `HabitDaySelectionTests`, `HabitAndProfileServiceTests`, `UserGenderTests` |
| Хранилище и бэкап | `ModelContainerFactoryTests`, `AppDataPersistenceRoundTripTests`, `MyTasksDocumentTests`, `ProfileDocumentTests`, `BackupDocumentTests`, `BackupImportTests`, `AutoBackupTests`, `SyncFieldsTests`, `LegacyStorageCleanupTests` |
| Календарь | `CalendarEventRulesTests`, `CalendarExportServiceTests`, `CalendarWeekHelperTests`, `CalendarMeetingRulesTests` |
| LLM | `SecretStoreTests`, `LLMSettingsTests`, `OpenRouterProviderTests`, `TaskDraftServiceTests`, `InboxDraftServiceTests`, `ReflectionServiceTests`, `DayPlanServiceTests`, `LLMAnswerTextTests` |
| Интерфейс и настройки | `TabBarSettingsTests`, `NotificationSettingsTests`, `NotificationDeepLinkTests`, `AppBadgeCounterTests`, `AccentPaletteTests`, `AccentInstallDefaultsTests`, `OrientationLockSettingsTests`, `TaskListDisplaySettingsTests`, `EisenhowerMatrixLayoutTests`, `EisenhowerQuadrantTests`, `WidgetSnapshotBuilderTests`, `TaskDragPayloadTests`, `TaskFieldKeyboardResetTests`, `TaskReminderOffsetTests` |

Сеть в тестах LLM подменяется `URLProtocol`-заглушкой или `StubLLMProvider`; настоящий ключ не используется. Общие помощники — `TestHelpers.swift`, `PersistenceTestSupport.swift`, `LLMTestSupport.swift`.

### Правила для новых тестов

- Имена — по-русски: `чтоПроверяем_ожидаемыйРезультат`, перед тестом — комментарий.
- `ModelContainer` хранить в свойстве тестовой структуры (`init() throws`), а не в локальной переменной: иначе Swift может освободить его раньше времени и тестовый процесс упадёт.
- Сервисам передавать свой `onChange` (например, счётчик): настоящий `didChange()` асинхронно пересчитывает уведомления.
- «Сейчас» — фиксированная дата или параметр (`now:`, `isOverdue(at:)`, `isDue(on:)`), а не `Date()`.

## Отладочные аргументы запуска (только Debug)

| Аргумент | Что делает |
|---|---|
| `-LLMStub` | Чат LLM работает с готовыми ответами вместо OpenRouter — ключ и сеть не нужны. Слово «ошибка» в тексте → «нет сети», «мусор» → ответ не JSON, `today` → черновик со сроком на сегодня |
| `-SeedDemoData` | Заполняет **пустое** хранилище демо-задачами, папками, тегами и привычками и включает все вкладки (для скриншотов). Если данные уже есть — ничего не делает |
| `-SeedDemoMeetings` | Создаёт в Календаре устройства календарь «Демо-встречи» с событиями на сегодня (весь день, через полночь, обычные) — для блока «Встречи» (D-37). Нужен полный доступ: `xcrun simctl privacy <UDID> grant calendar valeravalera.BraineeApp`. Если календарь уже есть — ничего не делает |

```bash
xcrun simctl install <UDID> <путь к BraineeApp.app>
xcrun simctl launch <UDID> valeravalera.BraineeApp -SeedDemoData -LLMStub
```

## Ручная проверка в симуляторе

- Состояние проверять по данным, а не по скриншотам: хранилище — `sqlite3 -readonly "<контейнер>/Library/Application Support/BraineeApp/BraineeApp.store"`, настройки — `plutil -p "<контейнер>/Library/Preferences/valeravalera.BraineeApp.plist"`; контейнер — `xcrun simctl get_app_container <UDID> valeravalera.BraineeApp data` (меняется после переустановки).
- Системный запрос уведомлений при первом запуске перекрывает экран. Чтобы его не было, при **первом** запуске после установки передать `-notificationDidRequestPermission YES` (ключ UserDefaults через аргумент; работает и в Release). Если запрос уже показан и его нечем нажать, он остаётся и после переустановки — помогает только перезагрузка симулятора (`xcrun simctl shutdown` / `boot`).
- Переключатели (`Toggle`) на iOS 27 в симуляторе не переключаются ни тапом, ни свайпом через инструмент симулятора. Настройку из UserDefaults можно задать аргументом запуска: `-calendarMeetingsEnabled YES` (значение действует только на этот запуск и в plist не пишется).
- Ввод текста в симуляторе идёт через вставку: разрешить вставку в системном запросе; кириллица при вставке искажается, ключ в `SecureField` так не вводится.
- Перед первым нажатием дождаться конца заставки (~4 с). Скриншот отстаёт примерно на одно действие.
- Если приложение не отвечает — сначала загрузка процессора (`ps`), а не новые скриншоты.

## Ручные сценарии

Пошаговые сценарии для человека — [`manual-test-scenarios.md`](manual-test-scenarios.md). На iPhone с настоящим ключом проверяются только сценарии LLM (раздел 13).
