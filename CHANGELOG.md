# Changelog

Notable changes to BraineeApp. Dates are commit dates. Decision references (D-xx) point to [`docs/decisions.md`](docs/decisions.md).
The October 2026 work was a modernization done in phases; the detailed task plan and audit it followed are available in git history (`e1ccfff`).

## 2026-10-22 — Lock Screen widgets

- "Calendar" (circular): weekday, date and today's tasks as "left/total" (only tasks due today; overdue ones are not counted).
- "Today" (rectangular): habits and today's tasks with progress bars ("3 из 5", "ещё 2 из 5").
- Both open the Calendar tab on today (falls back to Tasks if the Calendar tab is hidden). Same App Group snapshot as the Home Screen widgets, plus one derived counter (tasks due today that are done); no new entitlements.
- After midnight, until the app rebuilds the snapshot, the widgets show the new date, "—" for tasks and 0 done habits instead of yesterday's numbers.

## 2026-10-22 — Smoother task list scrolling

- Task list is lazy: only visible folders and rows are built. With ~300 tasks the main thread was busy up to ~0.8 s per second while scrolling (dropped frames); after the change it is ~8× less (simulator, Time Profiler).
- Lighter task rows: meta chips no longer sit in a horizontal scroll view of their own (chips that don't fit are cut at the right edge), one clock per screen instead of a timer in every row, the swipe-to-delete background is built only while swiping, and the swipe gesture no longer has high priority over scrolling.
- Debug-only `-DemoTaskCount N` (with `-SeedDemoData`) adds N tasks for performance checks.

## 2026-10-22 — LLM chat: mode menu and Copy

- Chat mode is picked from a drop-down menu instead of a horizontally scrolling row: the button shows the current mode's icon and name in the accent color, the list marks it with a checkmark.
- "Copy" under the Reflection and Day plan answers (and in the long-press menu) puts the answer as plain text on the clipboard; nothing is sent anywhere.

## 2026-10-22 — Habit reordering fix

- Drag and drop of habits works again: the long-press gesture on the handle was cancelled by the system drag and cleared the drag state, so rows did not move. The drop now also reorders by the dragged habit's id and saves the order once; dropping between rows ends the drag cleanly.

## 2026-10-21 — Meetings from the iPhone Calendar

- Calendar tab: optional read-only "Meetings" block under the day's tasks — events from all calendars except "BraineeApp", all-day first, then by start time, with start time and duration on the left; a meeting that started the day before shows "until HH:MM" (D-37).
- Setting "Profile → Settings → Calendar → Meetings from Calendar", off by default; meetings are never stored, backed up or sent anywhere.
- Debug-only `-SeedDemoMeetings` launch argument for demo events.

## 2026-10-21 — UI polish

- Tag library, dashboard and widget counters use one rule: tasks in the trash are never counted.
- Dashboard details: Active / All switch at the top (All includes tasks in the trash, marked "В корзине"), a summary block, and a tag pie chart with a legend in percent (tag marks share, sums to 100%).
- "No folder" block renamed to **Inbox** («Входящие») in the task list, the delete-folder confirmation, FAQ and the LLM draft note.
- Folder cards in the task list keep their rounded bottom corners (drag and drop between folders unchanged).
- Profile shows the app logo and "BraineeApp" in the top-left corner instead of the "Profile" title; no glass capsule on iOS 26+.
- Profile search finds sections by words longer than the keyword ("уведомления"), ignores ё/е and punctuation, and matches any word of the query.

## 2026-10-21 — Repository cleanup

- Feature scope frozen (D-35): Obsidian/Markdown viewer, server, sync, Telegram bot and ops phases removed from plans.
- New public-facing README (English + Russian), GNU GPL v3 license, screenshots, this changelog.
- Docs restructured: `docs/ARCHITECTURE.md`, `docs/decisions.md` (D-01…D-36), `docs/TESTING.md`, `docs/manual-test-scenarios.md`.
- Debug-only `-SeedDemoData` launch argument for demo data.

## 2026-10-21 — LLM assistant (OpenRouter)

- **LLM tab** replaces the Matrix tab; the Eisenhower Matrix moved to Profile → More (D-27).
- **Settings:** OpenRouter key in Keychain (this device only, D-28), model ID, connection check, remaining key limit (D-24).
- **Task from text:** a phrase becomes a validated task draft opened in the regular task form; nothing is saved until the user taps Save (D-25, D-26).
- **Inbox:** a long text becomes up to 10 drafts, each confirmed separately (D-30).
- **Reflection:** day/week numbers computed by the app; only numbers are sent to the model (D-31).
- **Day plan:** suggested order for today's and overdue tasks; read-only, consent before task titles are sent (D-32…D-34).
- Reasoning models: requests ask for low reasoning effort; free models get a larger answer limit; a clear error when the limit runs out.
- Debug-only `-LLMStub` for checking the chat in the simulator without a key or network.
- Profile regrouped into "More" and "Settings"; GitHub links at the bottom.

## 2026-10-21 — Calendar export

- One-way export of tasks with a date to an app-owned "BraineeApp" calendar (iCloud, otherwise local) via EventKit (D-05, D-06).
- Full reconciliation after every data change and on app return; unchanged events are not rewritten; lost links are recovered by a `braineeapp://task/<uuid>` marker, which also opens the task (D-22, D-23).
- `scripts/test.sh`: compact test runner; date-dependent tests made deterministic.

## 2026-10-20 — Persistent SwiftData storage

- Versioned schema (`SchemaV1`) with `#Unique` UUIDs; persistent store in Application Support (D-17).
- One-time verified migration from the legacy JSON + Keychain storage, then removal of the legacy path (D-18, D-19, D-21).
- JSON backup: manual export, daily auto-backup (last 7 files) and "replace all" restore with a pre-restore snapshot (D-04, D-16, D-20).
- The store is never wiped at launch; an open error shows an error screen instead of crashing.

## 2026-10-20 — Safety net and domain layer

- Characterization tests for persistence; corrupt files are no longer overwritten with empty data.
- Domain services (`TaskService`, `GroupService`, `TagService`, `HabitService`, `ProfileService`) as the single place for data changes.
- `updatedAt` / `completedAt` fields and a stable profile UUID (D-03).

## 1.1.0 — 2026-08-18

- Habits day picker (up to 14 days back), app icon badge, README.

## 1.0.0 — 2026-08-08

- Widgets, local reminders, habits contribution calendar, task form polish.

## 0.8 — 2026-08-08

- Kanban, habits, calendar, Eisenhower Matrix, FAQ; folder drag-and-drop fixes; flowing tab and segment UI.

## 0.5–0.7 — 2026-08-07

- Design system, accent palette and alternate icons, branding; groups/tags UX; manual test scenarios and first unit tests.

## 0.26–0.4 — 2026-08-06

- Theme, tags, groups and drag-and-drop; app icon and local JSON storage; soft delete and data migration.
