#!/bin/zsh
# Компактный запуск тестов BraineeApp: полный лог — в файл, в консоль — только итог и ошибки.
#
#   scripts/test.sh                         все BraineeAppTests
#   scripts/test.sh TaskServiceTests ...    только указанные наборы (имена struct с тестами)
#   scripts/test.sh --build                 только сборка (проверка компиляции)
#
# Переменные: BRAINEE_SIM_ID — UDID симулятора (по умолчанию загруженный iPhone, иначе iPhone 16 / iOS 18.3.1);
# BRAINEE_TEST_TIMEOUT — лимит в секундах (по умолчанию 600); BRAINEE_TEST_LOG — путь к полному логу.

set -o pipefail
cd "${0:A:h}/.."

LOG="${BRAINEE_TEST_LOG:-${TMPDIR:-/tmp}/braineeapp-test.log}"
DERIVED="${TMPDIR:-/tmp}/BraineeApp-DerivedData"
LIMIT="${BRAINEE_TEST_TIMEOUT:-600}"

if [[ -n "$BRAINEE_SIM_ID" ]]; then
  DEST="platform=iOS Simulator,id=$BRAINEE_SIM_ID"
else
  BOOTED=$(xcrun simctl list devices booted | grep -m1 "iPhone" | grep -oE '[0-9A-F-]{36}')
  if [[ -n "$BOOTED" ]]; then
    DEST="platform=iOS Simulator,id=$BOOTED"
  else
    DEST="platform=iOS Simulator,name=iPhone 16,OS=18.3.1"
  fi
fi

ARGS=(-project BraineeApp.xcodeproj -scheme BraineeApp -destination "$DEST" -derivedDataPath "$DERIVED")
if [[ "$1" == "--build" ]]; then
  ARGS+=(build-for-testing)
else
  # Без сбора диагностики при падении: иначе xcodebuild «висит» ~10 минут после упавшего теста.
  ARGS+=(test -parallel-testing-enabled NO -collect-test-diagnostics never)
  if (( $# == 0 )); then
    ARGS+=(-only-testing:BraineeAppTests)
  else
    for suite in "$@"; do ARGS+=(-only-testing:"BraineeAppTests/$suite"); done
  fi
fi

START=$SECONDS
xcodebuild "${ARGS[@]}" > "$LOG" 2>&1 &
PID=$!
( sleep "$LIMIT"; kill "$PID" 2>/dev/null && echo "⏱ Прервано по лимиту ${LIMIT} с" >> "$LOG" ) &
WATCHDOG=$!
wait "$PID"
CODE=$?
kill "$WATCHDOG" 2>/dev/null

# Только то, что нужно для решения: ошибки сборки, падения, итог.
grep -E "error:|Fatal error|✘|⏱|Test run with|\*\* (BUILD|TEST) (SUCCEEDED|FAILED)" "$LOG" \
  | awk '!seen[$0]++' | head -40
echo "Время: $(( SECONDS - START )) с · код $CODE · полный лог: $LOG"
exit $CODE
