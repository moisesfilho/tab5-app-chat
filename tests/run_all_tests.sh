#!/usr/bin/env bash
# run_all_tests.sh - Test orchestrator for Tab5 Chat App
# Runs all test suites and reports results
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================="
echo "  Tab5 Chat App - Test Suite Runner"
echo "========================================="
echo ""

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0

run_suite() {
    local suite_name="$1"
    local script="$2"

    echo ">>> Running: ${suite_name}"
    echo ""

    if [ ! -f "${script}" ]; then
        echo "  [SKIP] Test script not found: ${script}"
        TOTAL_SKIP=$((TOTAL_SKIP + 1))
        return
    fi

    if [ ! -x "${script}" ]; then
        chmod +x "${script}"
    fi

    if bash "${script}"; then
        TOTAL_PASS=$((TOTAL_PASS + 1))
    else
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
    fi
    echo ""
}

# Suite 1: Compile Test
run_suite "Compile Test (gcc with mock SDK)" "${SCRIPT_DIR}/test_compile.sh"

# Suite 2: Static AC Verification
run_suite "Static Acceptance Criteria" "${SCRIPT_DIR}/test_static_ac.sh"

# Suite 3: Apply Layout Geometry
run_suite "Apply Layout Geometry" "${SCRIPT_DIR}/test_apply_layout.sh"

# Suite 4: Rotation Detection & Re-layout
run_suite "Rotation Detection & Re-layout" "${SCRIPT_DIR}/test_rotation_relayout.sh"

# Suite 5: Modal + Keyboard Layout
run_suite "Modal + Keyboard Layout" "${SCRIPT_DIR}/test_modal_kb_layout.sh"

# Suite 6: Full-Width Input
run_suite "Full-Width Input" "${SCRIPT_DIR}/test_full_width_input.sh"

# Suite 7: Display Size Rotation Contract
run_suite "Display Size Rotation Contract" "${SCRIPT_DIR}/test_display_size_rotation.sh"

# Suite 8: Action Button Style Equivalence
run_suite "Action Button Style Equivalence" "${SCRIPT_DIR}/test_action_button_style.sh"

# Suite 9: Modal Landscape + Keyboard
run_suite "Modal Landscape + Keyboard" "${SCRIPT_DIR}/test_modal_landscape_keyboard.sh"

# Suite 10: Host vs LVGL Contract
run_suite "Host Display Size vs LVGL Contract" "${SCRIPT_DIR}/test_host_display_size_vs_lvgl.sh"

# Suite 11: PCT(100) Width Contract
run_suite "PCT(100) Width Contract (messages/input/modal/backdrop)" "${SCRIPT_DIR}/test_pct_width_contract.sh"

# Suite 12: Bubbles Width Contract
run_suite "Bubbles Width Contract (system 100%, user/assistant 80%)" "${SCRIPT_DIR}/test_bubbles_contract.sh"

# Suite 13: Real Layout Call Contract
run_suite "Real Layout Call Contract (PCT + stale host)" "${SCRIPT_DIR}/test_layout_call_contract.sh"

# Suite 14: Modal Relative Contract (layout 100% relativo verificado)
run_suite "Modal Relative Contract (PCT(100) x PCT(100), card CENTER -kb_h/2)" "${SCRIPT_DIR}/test_modal_relative_contract.sh"

# Suite 15: Build Test
run_suite "Build Test (tools/build.sh)" "${SCRIPT_DIR}/test_build.sh"

# Suite 16: Scroll Capture Contract (balões/input sem scroll,
# lista/modal preservados)
run_suite "Scroll Capture Contract (row/spacer/bubble/input sem scroll)" "${SCRIPT_DIR}/test_scroll_capture_contract.sh"

# Suite 17: Scrollbar Contract (input sem scrollbar, system bubble sem overflow)
run_suite "Scrollbar Contract (gap system=0, input_ta PCT(100), scrollables únicos)" "${SCRIPT_DIR}/test_scrollbar_contract.sh"

echo "========================================="
echo "  Test Suites Summary"
echo "========================================="
echo "  Suites passed: ${TOTAL_PASS}"
echo "  Suites failed: ${TOTAL_FAIL}"
echo "  Suites skipped: ${TOTAL_SKIP}"
echo "========================================="

if [ "${TOTAL_FAIL}" -gt 0 ]; then
    echo ""
    echo "[OVERALL] SOME TESTS FAILED"
    exit 1
else
    echo ""
    echo "[OVERALL] ALL TEST SUITES PASSED"
    exit 0
fi
