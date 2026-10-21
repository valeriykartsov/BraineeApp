# BraineeApp

**A personal "second brain" for iPhone: tasks, habits and an optional AI assistant — offline-first, all data stays on the device.**

![Platform](https://img.shields.io/badge/platform-iOS%2018.2%2B-lightgrey)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![UI](https://img.shields.io/badge/UI-SwiftUI%20%2B%20SwiftData-blue)
![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)
![License](https://img.shields.io/badge/license-GPL--3.0-blue)

[Русская версия](README.ru.md)

| Tasks | Calendar | AI assistant | Habits | Profile |
|:---:|:---:|:---:|:---:|:---:|
| <img src="docs/images/tasks.png" width="180" alt="Tasks"> | <img src="docs/images/calendar.png" width="180" alt="Calendar"> | <img src="docs/images/llm.png" width="180" alt="AI weekly reflection"> | <img src="docs/images/habits.png" width="180" alt="Habits"> | <img src="docs/images/profile.png" width="180" alt="Profile"> |

The app UI is in Russian. Screenshots use demo data.

## Features

- **Tasks** — deadlines with optional time, priorities, statuses, descriptions, tags, folders, drag-and-drop, list and kanban views, soft delete with a trash.
- **Calendar** — week strip with the tasks of the selected day; optional one-way export to an app-owned "BraineeApp" calendar in the iPhone Calendar (iCloud); optional read-only list of the day's meetings from your calendars, sorted by time with start and duration.
- **Habits** — up to 7 habits, a three-month contribution grid, check-ins for today and up to 14 days back.
- **AI assistant (optional, OpenRouter)** — turn a phrase into a task draft, split a brain dump into several drafts, get a short day/week reflection, get a suggested plan for today. Drafts are saved only after you confirm them in the regular task form.
- **Dashboard** — progress, overdue and today counters; details with a tag pie chart (percent legend) and an Active / All (including trash) switch.
- **Eisenhower Matrix** — quadrants by priority and urgency.
- **Reminders and badge** — local notifications for tasks and habits, deadline alerts, configurable app icon badge.
- **Widgets** — today's tasks, habits, dashboard (S / M / L).
- **Backup** — one-file JSON export through Files, daily auto-backup (last 7 copies), "replace all" restore with a safety snapshot.
- **Personalization** — light/dark theme, accent colors with matching app icons, configurable tab bar.

## Privacy

- All data lives in a local SwiftData store on the device. No account, no analytics, no iCloud sync of app data.
- Meetings from the iPhone Calendar (if enabled) are read on screen only: never stored, backed up or sent anywhere.
- The AI assistant is off until you add your own [OpenRouter](https://openrouter.ai) API key. The key is stored in the Keychain on this device only.
- Requests are sent only when you ask, one at a time, without chat history:

| Mode | What is sent |
|---|---|
| Task / Inbox | your text, today's date, time zone, names of your folders and tags |
| Reflection | numbers only (completed, created, overdue, habit check-ins) — no titles |
| Day plan | titles, priorities, deadline times and overdue flags of today's and overdue tasks (max 30) — asked once for consent |

Task descriptions, tags of tasks, profile data and backups are never sent.

## Tech stack

| Area | Technology |
|---|---|
| UI | SwiftUI |
| Storage | SwiftData (versioned schema, persistent store in Application Support) |
| Backup | JSON documents via Files |
| Calendar | EventKit (one-way export, read-only meetings) |
| AI | OpenRouter Chat Completions over `URLSession` |
| Secrets | Keychain |
| Widgets | WidgetKit + App Group |
| Notifications | UserNotifications |
| Tests | Swift Testing — 329 unit tests |
| Dependencies | none (Apple SDK only) |

## Architecture

SwiftUI views read data with `@Query`; every change goes through domain services (`Domain/`), which then trigger side effects in one place — save, widgets, notifications and calendar export. Integrations (EventKit, OpenRouter) live in `Integrations/` and never get write access to the store. Details: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). Design decisions with their reasoning: [`docs/decisions.md`](docs/decisions.md).

## Getting started

**Requirements:** macOS with Xcode 16.2 or later, iOS 18.2+ simulator or device.

1. Clone the repository and open `BraineeApp.xcodeproj`.
2. Select the **BraineeApp** scheme and a simulator or your device.
3. For a device, set your own team in *Signing & Capabilities* (the app and widget share an App Group).
4. Build and run (⌘R).
5. Optional: add an OpenRouter key in *Профиль → Настройки → LLM* (Profile → Settings → LLM) to enable the assistant.

To try the app with demo data in a simulator (Debug build): launch with `-SeedDemoData`, and add `-LLMStub` to use the assistant without a key — see [`docs/TESTING.md`](docs/TESTING.md).

## Testing

```bash
scripts/test.sh                  # all unit tests
scripts/test.sh TaskServiceTests # selected suites
scripts/test.sh --build          # build only
```

More in [`docs/TESTING.md`](docs/TESTING.md); manual scenarios in [`docs/manual-test-scenarios.md`](docs/manual-test-scenarios.md).

## Project structure

```
BraineeApp/            app: Views, Domain, Models, Persistence, Integrations, Utilities
BraineeAppTests/       unit tests (Swift Testing)
BraineeAppUITests/     Xcode UI test template (unused)
BraineeAppWidget/      widget extension
BraineeShared/         data snapshot shared with widgets
docs/                  architecture, decisions, testing, screenshots
scripts/test.sh        compact test runner
CLAUDE.md              working rules for the AI coding assistant
```

## Documentation

| Document | Contents |
|---|---|
| [ARCHITECTURE](docs/ARCHITECTURE.md) | layers, storage, backup, calendar export, AI integration (Russian) |
| [Decisions](docs/decisions.md) | architecture decision log D-01…D-36 (Russian) |
| [Testing](docs/TESTING.md) | automated tests, debug launch arguments, simulator checks (Russian) |
| [Manual scenarios](docs/manual-test-scenarios.md) | step-by-step acceptance scenarios (Russian) |
| [Changelog](CHANGELOG.md) | history of notable changes |

## Status

A personal project, built and used by its author. The current feature set is frozen; further development follows a separate backlog. It is not published on the App Store. Issues are welcome; pull requests are not expected.

## License

[GNU General Public License v3.0](LICENSE).

## Author

Valerii Kartcov — [@valeriykartsov](https://github.com/valeriykartsov)
