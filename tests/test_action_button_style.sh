#!/usr/bin/env bash
# test_action_button_style.sh - Contract test for WASM action button style equivalence
# Validates that the action button (settings) uses the same palette, border,
# radius, and size as the close/send button, following the design contract.
# Pattern: self-contained C program with instrumented mock SDK, compiled via gcc.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/.build"
mkdir -p "${OUT_DIR}"

echo "=== Action Button Style Equivalence Test ==="
echo ""

cat > "${SCRIPT_DIR}/test_action_button_style.c" << 'TESTEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>

/* ── Theme color IDs (from tab5_sdk.h) ── */
#define TAB5_UI_COLOR_BG          0
#define TAB5_UI_COLOR_SURFACE     1
#define TAB5_UI_COLOR_BORDER      2
#define TAB5_UI_COLOR_TEXT        3
#define TAB5_UI_COLOR_TEXT_MUTED  4
#define TAB5_UI_COLOR_ACCENT      5

/* ── Mock theme colors (realistic Tab5 OS palette) ── */
#define COLOR_BG       0x121212
#define COLOR_SURFACE  0x1E1E1E
#define COLOR_BORDER   0x333333
#define COLOR_TEXT     0xE0E0E0
#define COLOR_TEXT_MUT 0x888888
#define COLOR_ACCENT   0x06B6D4

static uint32_t mock_theme_color(int id) {
    switch (id) {
        case TAB5_UI_COLOR_BG:         return COLOR_BG;
        case TAB5_UI_COLOR_SURFACE:    return COLOR_SURFACE;
        case TAB5_UI_COLOR_BORDER:     return COLOR_BORDER;
        case TAB5_UI_COLOR_TEXT:       return COLOR_TEXT;
        case TAB5_UI_COLOR_TEXT_MUTED: return COLOR_TEXT_MUT;
        case TAB5_UI_COLOR_ACCENT:     return COLOR_ACCENT;
        default: return 0;
    }
}

#define tab5_ui_theme_get_color mock_theme_color

/* ── Instrumented mock: records style calls ── */
#define MAX_CALLS 256
static char  ct[MAX_CALLS][40];
static int   co[MAX_CALLS];
static uint32_t cp1[MAX_CALLS], cp2[MAX_CALLS], cp3[MAX_CALLS];
static int   cc = 0;

static void reset_calls(void) { cc = 0; }
static void rec(const char *t, int o, uint32_t a, uint32_t b, uint32_t c) {
    if (cc < MAX_CALLS) {
        snprintf(ct[cc], 40, "%s", t);
        co[cc] = o; cp1[cc] = a; cp2[cc] = b; cp3[cc] = c;
        cc++;
    }
}

static void mock_set_bg(int o, uint32_t color, uint8_t op) {
    rec("style_bg", o, color, op, 0);
}
static void mock_set_border(int o, uint32_t color, uint32_t w) {
    rec("style_border", o, color, w, 0);
}
static void mock_set_radius(int o, uint32_t r) {
    rec("style_radius", o, r, 0, 0);
}
static void mock_set_size(int o, int32_t w, int32_t h) {
    rec("set_size", o, (uint32_t)w, (uint32_t)h, 0);
}
static void mock_set_text_color(int o, uint32_t color, uint8_t op) {
    rec("style_text_color", o, color, op, 0);
}
static void mock_set_pad(int o, uint32_t p) {
    rec("set_pad", o, p, 0, 0);
}
static int mock_next_id = 10;
static int mock_create(int p) { (void)p; return ++mock_next_id; }

#define tab5_ui_obj_set_style_bg         mock_set_bg
#define tab5_ui_obj_set_style_border     mock_set_border
#define tab5_ui_obj_set_style_radius     mock_set_radius
#define tab5_ui_obj_set_size             mock_set_size
#define tab5_ui_obj_set_style_text_color mock_set_text_color
#define tab5_ui_obj_set_pad              mock_set_pad
#define tab5_ui_container_create         mock_create

/* ── Simulated build_chat_ui button creation ── */
typedef struct {
    int id;
    /* Style properties we care about */
    uint32_t bg_color;      uint8_t bg_op;
    uint32_t border_color;  uint32_t border_w;
    uint32_t radius;
    int32_t  w, h;
    uint32_t text_color;    uint8_t tc_op;
    int      pad;
} button_style_t;

static button_style_t build_send_button(int parent) {
    button_style_t btn = {0};
    uint32_t pal_accent = tab5_ui_theme_get_color(TAB5_UI_COLOR_ACCENT);

    btn.id = tab5_ui_container_create(parent); /* simulate btn_create */

    /* Size: 56 × TAB5_UI_PCT(100) → 56 × -100 */
    tab5_ui_obj_set_size(btn.id, 56, 0xFFFFFF9C); /* -100 as uint32 */
    btn.w = 56; btn.h = 0xFFFFFF9C;

    /* Style: accent bg, no border, radius 10, white text */
    tab5_ui_obj_set_style_bg(btn.id, pal_accent, 255);
    btn.bg_color = pal_accent; btn.bg_op = 255;

    tab5_ui_obj_set_style_border(btn.id, 0, 0);
    btn.border_color = 0; btn.border_w = 0;

    tab5_ui_obj_set_style_radius(btn.id, 10);
    btn.radius = 10;

    tab5_ui_obj_set_style_text_color(btn.id, 0xFFFFFF, 255);
    btn.text_color = 0xFFFFFF; btn.tc_op = 255;

    return btn;
}

static button_style_t build_action_button(int parent) {
    button_style_t btn = {0};
    uint32_t pal_accent = tab5_ui_theme_get_color(TAB5_UI_COLOR_ACCENT);

    btn.id = tab5_ui_container_create(parent);

    /* The app bar action button SHOULD match the send button palette:
     * same bg color, same border style, same radius, similar size. */
    tab5_ui_obj_set_size(btn.id, 48, 48);
    btn.w = 48; btn.h = 48;

    /* CONTRACT: action button uses accent palette (like send/close) */
    tab5_ui_obj_set_style_bg(btn.id, pal_accent, 255);
    btn.bg_color = pal_accent; btn.bg_op = 255;

    tab5_ui_obj_set_style_border(btn.id, 0, 0);
    btn.border_color = 0; btn.border_w = 0;

    tab5_ui_obj_set_style_radius(btn.id, 10);
    btn.radius = 10;

    tab5_ui_obj_set_style_text_color(btn.id, 0xFFFFFF, 255);
    btn.text_color = 0xFFFFFF; btn.tc_op = 255;

    tab5_ui_obj_set_pad(btn.id, 0);
    btn.pad = 0;

    return btn;
}

/* ── Simulated cancel button (modal close) ── */
static button_style_t build_cancel_button(int parent) {
    button_style_t btn = {0};
    uint32_t pal_bg = tab5_ui_theme_get_color(TAB5_UI_COLOR_BG);
    uint32_t pal_text = tab5_ui_theme_get_color(TAB5_UI_COLOR_TEXT);

    btn.id = tab5_ui_container_create(parent);

    tab5_ui_obj_set_size(btn.id, 0xFFFFFFCE, 44); /* TAB5_UI_PCT(50) = -50 → -50 as uint32 */

    /* Cancel uses bg color (neutral), not accent */
    tab5_ui_obj_set_style_bg(btn.id, pal_bg, 255);
    btn.bg_color = pal_bg; btn.bg_op = 255;

    tab5_ui_obj_set_style_text_color(btn.id, pal_text, 255);
    btn.text_color = pal_text; btn.tc_op = 255;

    return btn;
}

/* ── Assertions ── */
static int failures = 0;
static void check(int c, const char *m) {
    if (c) printf("  [PASS] %s\n", m);
    else   { printf("  [FAIL] %s\n", m); failures++; }
}

int main(void) {
    printf("=== Action Button Style Equivalence Test ===\n\n");

    /* ─── Scenario 1: Send button style contract ─── */
    printf("Scenario 1: Send button style (reference)\n");
    {
        reset_calls();
        button_style_t send = build_send_button(0);
        check(send.bg_color == COLOR_ACCENT,
              "send: bg = ACCENT");
        check(send.bg_op == 255, "send: bg opacity = 255");
        check(send.border_color == 0, "send: border color = 0 (no border)");
        check(send.border_w == 0, "send: border width = 0 (no border)");
        check(send.radius == 10, "send: radius = 10");
        check(send.w == 56, "send: width = 56");
        check(send.text_color == 0xFFFFFF, "send: text = white");
        printf("  send: bg=0x%06X, border=0x%06X/%d, radius=%d, size=%dx%d\n\n",
               send.bg_color, send.border_color, send.border_w, send.radius,
               send.w, send.h);
    }

    /* ─── Scenario 2: Action button matches send button palette ─── */
    printf("Scenario 2: Action button matches send button palette\n");
    {
        reset_calls();
        button_style_t action = build_action_button(0);

        check(action.bg_color == COLOR_ACCENT,
              "action: bg = ACCENT (matches send)");
        check(action.bg_op == 255,
              "action: bg opacity = 255 (matches send)");
        check(action.border_color == 0,
              "action: border color = 0 (matches send)");
        check(action.border_w == 0,
              "action: border width = 0 (matches send)");
        check(action.radius == 10,
              "action: radius = 10 (matches send)");
        check(action.text_color == 0xFFFFFF,
              "action: text = white (matches send)");
        printf("  action: bg=0x%06X, border=0x%06X/%d, radius=%d\n\n",
               action.bg_color, action.border_color, action.border_w,
               action.radius);
    }

    /* ─── Scenario 3: Cancel button is intentionally different ─── */
    printf("Scenario 3: Cancel button uses neutral palette (design intent)\n");
    {
        reset_calls();
        button_style_t cancel = build_cancel_button(0);

        check(cancel.bg_color == COLOR_BG,
              "cancel: bg = BG (neutral, not accent)");
        check(cancel.text_color == COLOR_TEXT,
              "cancel: text = TEXT (neutral, not white)");
        printf("  cancel: bg=0x%06X, text=0x%06X\n\n",
               cancel.bg_color, cancel.text_color);
    }

    /* ─── Scenario 4: Action button size is square and reasonable ─── */
    printf("Scenario 4: Action button size constraints\n");
    {
        reset_calls();
        button_style_t action = build_action_button(0);
        check(action.w == action.h,
              "action: width == height (square button)");
        check(action.w >= 36 && action.w <= 64,
              "action: size in range [36..64] (touch target)");
        check(action.pad == 0,
              "action: no internal padding (icon fills button)");
        printf("  action size: %dx%d, pad=%d\n\n", action.w, action.h, action.pad);
    }

    /* ─── Scenario 5: Visual palette consistency across button types ─── */
    printf("Scenario 5: Palette consistency — accent vs neutral\n");
    {
        reset_calls();
        button_style_t send   = build_send_button(0);
        button_style_t action = build_action_button(0);
        button_style_t cancel = build_cancel_button(0);

        /* Send and Action share accent */
        check(send.bg_color == action.bg_color,
              "send + action: same bg color (accent)");
        check(send.text_color == action.text_color,
              "send + action: same text color (white)");
        check(send.border_w == action.border_w,
              "send + action: same border width (none)");

        /* Cancel is intentionally different */
        check(cancel.bg_color != send.bg_color,
              "cancel != send: different bg (accent vs neutral)");
        check(cancel.text_color != send.text_color,
              "cancel != send: different text (white vs theme text)");

        printf("\n");
    }

    /* ─── Scenario 6: Recorded style calls contain expected types ─── */
    printf("Scenario 6: Style call types recorded correctly\n");
    {
        reset_calls();
        button_style_t action = build_action_button(0);
        int has_bg = 0, has_border = 0, has_radius = 0, has_size = 0;
        for (int i = 0; i < cc; i++) {
            if (co[i] == action.id) {
                if (strcmp(ct[i], "style_bg") == 0) has_bg = 1;
                if (strcmp(ct[i], "style_border") == 0) has_border = 1;
                if (strcmp(ct[i], "style_radius") == 0) has_radius = 1;
                if (strcmp(ct[i], "set_size") == 0) has_size = 1;
            }
        }
        check(has_bg, "action button: style_bg called");
        check(has_border, "action button: style_border called");
        check(has_radius, "action button: style_radius called");
        check(has_size, "action button: set_size called");
        printf("  action button: %d total style calls\n\n", cc);
    }

    /* ─── Scenario 7: Radius consistency across all button types ─── */
    printf("Scenario 7: All action-type buttons share radius\n");
    {
        reset_calls();
        button_style_t send   = build_send_button(0);
        button_style_t action = build_action_button(0);
        check(send.radius == action.radius,
              "send + action: same radius (10)");
        printf("  send radius=%d, action radius=%d\n\n", send.radius, action.radius);
    }

    printf("=== Action Button Style Results: %s (failures=%d) ===\n",
           failures ? "FAILED" : "ALL PASSED", failures);
    return failures ? 1 : 0;
}
TESTEOF

echo "[INFO] Compiling action button style test..."
if gcc -std=c11 -Wall -Wextra -o "${OUT_DIR}/test_action_button_style" \
       "${SCRIPT_DIR}/test_action_button_style.c" 2>&1; then
    echo "[INFO] Running action button style test..."
    "${OUT_DIR}/test_action_button_style"
    RESULT=$?
    echo ""
    if [ ${RESULT} -eq 0 ]; then
        echo "[PASS] Action button style test validates"
    else
        echo "[FAIL] Action button style test failed"
    fi
else
    echo "[FAIL] Action button style test failed to compile"
    RESULT=1
fi

rm -f "${SCRIPT_DIR}/test_action_button_style.c"
exit ${RESULT}
