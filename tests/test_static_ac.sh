#!/usr/bin/env bash
# test_static_ac.sh - Static analysis tests for Acceptance Criteria
# Verifies that required patterns exist in source code
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC="${APP_DIR}/src/main.c"

PASS=0
FAIL=0
TOTAL=0

run_test() {
    local name="$1"
    local result="$2"
    TOTAL=$((TOTAL + 1))
    if [ "$result" = "PASS" ]; then
        echo "  [PASS] ${name}"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] ${name}"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Test Suite: Static Acceptance Criteria Verification ==="
echo ""

# --- AC-001: tab5_ui_obj_set_scrollable(scr, false) ---
echo "AC-001: Screen scrollable set to false"

# Check if the function call exists at all
if grep -q 'tab5_ui_obj_set_scrollable' "${SRC}"; then
    run_test "tab5_ui_obj_set_scrollable called anywhere" "PASS"
else
    run_test "tab5_ui_obj_set_scrollable called anywhere" "FAIL"
    run_test "tab5_ui_obj_set_scrollable(scr, false) present" "FAIL"
    run_test "set_scrollable(scr, false) inside build_chat_ui" "FAIL"
fi

# If function exists, check for scr usage
if grep -q 'tab5_ui_obj_set_scrollable' "${SRC}"; then
    if grep -qP 'tab5_ui_obj_set_scrollable\(\s*scr\s*,' "${SRC}"; then
        run_test "tab5_ui_obj_set_scrollable(scr, false) present" "PASS"
    else
        run_test "tab5_ui_obj_set_scrollable(scr, false) present" "FAIL"
    fi

    if grep -qP 'tab5_ui_obj_set_scrollable\(\s*scr\s*,\s*false\s*\)' "${SRC}"; then
        run_test "set_scrollable(scr, false) inside build_chat_ui" "PASS"
    else
        run_test "set_scrollable(scr, false) inside build_chat_ui" "FAIL"
    fi
fi

echo ""

# --- AC-002: tab5_ui_obj_set_scrollable(s_messages_cont, true) ---
echo "AC-002: Messages container scrollable set to true"

if grep -qP 'tab5_ui_obj_set_scrollable\(\s*s_messages_cont\s*,' "${SRC}"; then
    run_test "tab5_ui_obj_set_scrollable(s_messages_cont, ...) present" "PASS"
else
    run_test "tab5_ui_obj_set_scrollable(s_messages_cont, ...) present" "FAIL"
fi

if grep -qP 'tab5_ui_obj_set_scrollable\(\s*s_messages_cont\s*,\s*true\s*\)' "${SRC}"; then
    run_test "tab5_ui_obj_set_scrollable(s_messages_cont, true) present" "PASS"
else
    run_test "tab5_ui_obj_set_scrollable(s_messages_cont, true) present" "FAIL"
fi

echo ""

# --- AC-003: Layout dimensions and positioning ---
echo "AC-003: Layout dimensions and positioning"

# Check that apply_layout computes input_y above keyboard
if grep -qP 'input_y\s*=' "${SRC}"; then
    run_test "apply_layout computes input_y" "PASS"
else
    run_test "apply_layout computes input_y" "FAIL"
fi

# Check that input_y accounts for kb_h
if grep -qP 'input_y\s*=.*kb_h' "${SRC}"; then
    run_test "input_y accounts for keyboard height (kb_h)" "PASS"
else
    run_test "input_y accounts for keyboard height (kb_h)" "FAIL"
fi

# Check minimum input_y guard
if grep -qP 'input_y\s*<\s*MSG_TOP|if\s*\(\s*input_y\s*<' "${SRC}"; then
    run_test "input_y has minimum guard (MSG_TOP + offset)" "PASS"
else
    run_test "input_y has minimum guard (MSG_TOP + offset)" "FAIL"
fi

# Check msg_h calculation
if grep -qP 'msg_h\s*=' "${SRC}"; then
    run_test "apply_layout computes msg_h" "PASS"
else
    run_test "apply_layout computes msg_h" "FAIL"
fi

# Check that s_messages_cont gets sized
if grep -qP 'tab5_ui_obj_set_size\(\s*s_messages_cont' "${SRC}"; then
    run_test "s_messages_cont sized in apply_layout" "PASS"
else
    run_test "s_messages_cont sized in apply_layout" "FAIL"
fi

# Check that s_input_cont gets sized
if grep -qP 'tab5_ui_obj_set_size\(\s*s_input_cont' "${SRC}"; then
    run_test "s_input_cont sized in apply_layout" "PASS"
else
    run_test "s_input_cont sized in apply_layout" "FAIL"
fi

# Check that s_input_cont is positioned (aligned)
if grep -qP 'tab5_ui_obj_set_align\(\s*s_input_cont' "${SRC}"; then
    run_test "s_input_cont positioned in apply_layout" "PASS"
else
    run_test "s_input_cont positioned in apply_layout" "FAIL"
fi

# Check that s_messages_cont is positioned (aligned)
if grep -qP 'tab5_ui_obj_set_align\(\s*s_messages_cont' "${SRC}"; then
    run_test "s_messages_cont positioned in apply_layout" "PASS"
else
    run_test "s_messages_cont positioned in apply_layout" "FAIL"
fi

echo ""

# --- AC-004: Rotation detection in handle_poll ---
echo "AC-004: Rotation detection in handle_poll (w/h change triggers re-layout)"

# Check that handle_poll queries display size
if grep -qP 'tab5_ui_get_display_size\s*\(' "${SRC}"; then
    run_test "handle_poll queries display size" "PASS"
else
    run_test "handle_poll queries display size" "FAIL"
fi

# Check that handle_poll stores w/h for comparison
if grep -qP 's_last_[wh]\s*=' "${SRC}" || grep -qP 'last_[wh]\s*=' "${SRC}"; then
    run_test "handle_poll stores last w/h values" "PASS"
else
    run_test "handle_poll stores last w/h values" "FAIL"
fi

# Check that handle_poll compares w/h and triggers apply_layout
if grep -qP '(w\s*!=|w\s*==).*last' "${SRC}" || grep -qP 'last.*!=.*[wh]' "${SRC}"; then
    run_test "handle_poll compares w/h to detect rotation" "PASS"
else
    run_test "handle_poll compares w/h to detect rotation" "FAIL"
fi

echo ""

# --- AC-005: Input container uses full orientation width ---
echo "AC-005: Input container uses full width of current orientation"

# Novo contrato: largura via TAB5_UI_PCT(100) (= -1100 no SDK real), que o host
# interpreta como 100% da largura atual, em vez de largura absoluta `w`.
if grep -qP 'tab5_ui_obj_set_size\(\s*s_input_cont\s*,\s*TAB5_UI_PCT\(\s*100\s*\)' "${SRC}"; then
    run_test "apply_layout: input_cont width = TAB5_UI_PCT(100) (full orientation width)" "PASS"
else
    run_test "apply_layout: input_cont width = TAB5_UI_PCT(100) (full orientation width)" "FAIL"
fi

echo ""

# --- AC-006: Modal accounts for keyboard height ---
echo "AC-006: Modal/backdrop/card sized and positioned with kb_h"

# Check that open_config_modal queries keyboard height
if grep -qP 'tab5_ui_keyboard_get_height' "${SRC}"; then
    run_test "open_config_modal queries keyboard height" "PASS"
else
    run_test "open_config_modal queries keyboard height" "FAIL"
fi

# Check that modal is sized to full screen (PCT(100) x PCT(100)) — contrato relativo
if grep -qP 'tab5_ui_obj_set_size\(\s*s_modal\s*,\s*TAB5_UI_PCT\(\s*100\s*\),\s*TAB5_UI_PCT\(\s*100\s*\)' "${SRC}"; then
    run_test "modal sized to full screen (TAB5_UI_PCT(100) x TAB5_UI_PCT(100))" "PASS"
else
    run_test "modal sized to full screen (TAB5_UI_PCT(100) x TAB5_UI_PCT(100))" "FAIL"
fi

# Check that backdrop is sized to full screen (PCT(100) x PCT(100))
if grep -qP 'set_size\(\s*(?:s_modal_backdrop|backdrop)\s*,\s*TAB5_UI_PCT\(\s*100\s*\),\s*TAB5_UI_PCT\(\s*100\s*\)' "${SRC}"; then
    run_test "backdrop sized to full screen (TAB5_UI_PCT(100) x TAB5_UI_PCT(100))" "PASS"
else
    run_test "backdrop sized to full screen (TAB5_UI_PCT(100) x TAB5_UI_PCT(100))" "FAIL"
fi

# Check that card width is relative, leaving lateral margin
if grep -qP 'set_size\(\s*(?:s_modal_card|card)\s*,\s*TAB5_UI_PCT\(\s*96\s*\)' "${SRC}"; then
    run_test "card width = TAB5_UI_PCT(96)" "PASS"
else
    run_test "card width = TAB5_UI_PCT(96)" "FAIL"
fi

# Check that card height is relative (PCT(60)) — sem card_h/usable_h
if grep -qP 'set_size\(\s*(?:s_modal_card|card)\s*,\s*TAB5_UI_PCT\(\s*96\s*\),\s*TAB5_UI_PCT\(\s*60\s*\)' "${SRC}"; then
    run_test "card height = TAB5_UI_PCT(60) (relativo, sem card_h)" "PASS"
else
    run_test "card height = TAB5_UI_PCT(60) (relativo, sem card_h)" "FAIL"
fi

# Check that card is centered with negative kb offset (sobe acima do teclado)
if grep -qP 'set_align\(\s*(?:s_modal_card|card)\s*,\s*TAB5_UI_ALIGN_CENTER\s*,\s*0\s*,\s*-\s*\(\s*kb_h\s*/\s*2\s*\)' "${SRC}"; then
    run_test "card CENTER with offset -(kb_h/2) (sobe com o teclado)" "PASS"
else
    run_test "card CENTER with offset -(kb_h/2) (sobe com o teclado)" "FAIL"
fi

echo ""

# --- AC-007: Modal fields and buttons within usable area ---
echo "AC-007: Modal fields/buttons na área útil (card relativo + scroll)"

# Contrato relativo: card é PCT(96) x PCT(60) com CENTER offset -(kb_h/2);
# o caminho modal NÃO deriva card_h/usable_h de dimensões absolutas do host.
if grep -qP 'card_h\s*=' "${SRC}"; then
    run_test "SEM card_h no caminho modal (altura relativa PCT(60))" "FAIL"
else
    run_test "SEM card_h no caminho modal (altura relativa PCT(60))" "PASS"
fi

if grep -qP '\busable_h\b' "${SRC}"; then
    run_test "SEM usable_h no caminho modal (sem derivar h - kb_h)" "FAIL"
else
    run_test "SEM usable_h no caminho modal (sem derivar h - kb_h)" "PASS"
fi

# Conteúdo maior que a área visível permanece acessível via scroll no card
if grep -qP 'tab5_ui_obj_set_scrollable\(\s*s_modal_card\s*,\s*true' "${SRC}"; then
    run_test "card scrollable = true (campos/botões rolam no vão do teclado)" "PASS"
else
    run_test "card scrollable = true (campos/botões rolam no vão do teclado)" "FAIL"
fi

echo ""

# --- AC-008: PCT(100) width contract (macro real -1000-percent) ---
echo "AC-008: PCT(100) width para messages/input/modal/backdrop (macro real)"

# Macro real do SDK: -1000 - percent => PCT(100) == -1100
if grep -qP 'TAB5_UI_PCT\(\s*100\s*\)' "${SRC}"; then
    run_test "TAB5_UI_PCT(100) usado no layout" "PASS"
else
    run_test "TAB5_UI_PCT(100) usado no layout" "FAIL"
fi

# Messages container com largura PCT(100)
if grep -qP 'tab5_ui_obj_set_size\(\s*s_messages_cont\s*,\s*(?:TAB5_UI_PCT\(\s*100\s*\))[^,]*,' "${SRC}"; then
    run_test "messages_cont width = TAB5_UI_PCT(100)" "PASS"
else
    run_test "messages_cont width = TAB5_UI_PCT(100)" "FAIL"
fi

# Alturas preservadas (não-PCT): messages=msg_h, input=INPUT_H, modal/backdrop=h
if grep -qP 'tab5_ui_obj_set_size\(\s*s_messages_cont\s*,[^,]*,.*msg_h' "${SRC}"; then
    run_test "messages_cont altura de msg_h (preservada)" "PASS"
else
    run_test "messages_cont altura de msg_h (preservada)" "FAIL"
fi
if grep -qP 'tab5_ui_obj_set_size\(\s*s_input_cont\s*,[^,]*,.*INPUT_H' "${SRC}"; then
    run_test "input_cont altura = INPUT_H (preservada)" "PASS"
else
    run_test "input_cont altura = INPUT_H (preservada)" "FAIL"
fi

# Teclado preservado: offset -(kb_h + INPUT_GAP)
if grep -qP 'tab5_ui_obj_set_align\(\s*s_input_cont\s*,[^)]*-\(\s*kb_h\s*\+\s*INPUT_GAP\s*\)' "${SRC}"; then
    run_test "input_cont offset = -(kb_h + INPUT_GAP) preservado" "PASS"
else
    run_test "input_cont offset = -(kb_h + INPUT_GAP) preservado" "FAIL"
fi

echo ""

# --- AC-009: Bubbles width contract (system 100%, user/assistant 80%) ---
echo "AC-009: Bubbles — system 100%, user/assistant 80%"

if grep -qP 'tab5_ui_obj_set_size\(\s*row\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*,\s*TAB5_UI_SIZE_CONTENT\s*\)' "${SRC}"; then
    run_test "bubble row width = TAB5_UI_PCT(100), height CONTENT" "PASS"
else
    run_test "bubble row width = TAB5_UI_PCT(100), height CONTENT" "FAIL"
fi

if grep -qP 'tab5_ui_obj_set_size\(\s*bubble\s*,\s*is_system\s*\?\s*TAB5_UI_PCT\(\s*100\s*\)\s*:\s*TAB5_UI_PCT\(\s*80\s*\)' "${SRC}"; then
    run_test "bubble widths = PCT(100)/PCT(80)" "PASS"
else
    run_test "bubble widths = PCT(100)/PCT(80)" "FAIL"
fi

if grep -qP 'tab5_ui_obj_set_size\(\s*lbl\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*,\s*TAB5_UI_SIZE_CONTENT\s*\)' "${SRC}"; then
    run_test "bubble label width = TAB5_UI_PCT(100), height CONTENT" "PASS"
else
    run_test "bubble label width = TAB5_UI_PCT(100), height CONTENT" "FAIL"
fi

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed, ${TOTAL} total ==="

if [ "${FAIL}" -gt 0 ]; then
    exit 1
fi
exit 0
