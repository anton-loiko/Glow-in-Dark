#!/bin/bash
# Проверка типизации + юнит-тесты gdUnit4 (headless). Использование: tools/run_tests.sh
set -e
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-$(command -v godot)}"
"$GODOT_BIN" --headless --import > /dev/null 2>&1
"$GODOT_BIN" --headless --script res://tools/check_scripts.gd
GODOT_BIN="$GODOT_BIN" addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a res://tests
