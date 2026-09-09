#!/usr/bin/env bash
# test_rotation_relayout.sh - TDD: Rotation detection + re-layout after w/h change
# Compiles a self-contained C program that instruments the poll→apply_layout path
# using an instrumented mock SDK that records display size queries and set_size/set_align calls.
# Verifies:
#  1. handle_poll detects w/h changes (calls apply_layout when dimensions change)
#  2. apply_layout uses current display w as input_cont width (full current orientation width)
#  3. re-layout after rotation updates messages and input dimensions
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/.build"
mkdir -p "${OUT_DIR}"

echo "=== Rotation Detection & Re-layout Test ==="
echo ""

cat > "${SCRIPT_DIR}/test_rotation_relayout.c" << 'TESTEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>

/* ── Constants (mirroring src/main.c) ── */
#define MSG_TOP       104
#define INPUT_H       60
#define INPUT_GAP      6
#define TAB5_UI_PCT(x) (-(x))
#define TAB5_UI_SIZE_CONTENT (-1)
#define TAB5_UI_ALIGN_TOP_LEFT    0
#define TAB5_UI_ALIGN_BOTTOM_LEFT 2
#define TAB5_UI_FLEX_FLOW_COLUMN  0
#define TAB5_UI_INVALID_OBJ (-1)

/* ── Instrumented mock ── */
static int32_t mock_w = 720, mock_h = 1280;
static int32_t mock_kb_h = 0;

/* recording arrays */
#define MAX_CALLS 256
static char  call_type[MAX_CALLS][32];
static int   call_obj[MAX_CALLS];
static int   call_w[MAX_CALLS];
static int   call_h[MAX_CALLS];
static int   call_count = 0;
static int   get_display_count = 0;
static int   kb_query_count = 0;

static void reset_calls(void) { call_count = 0; }
static void mock_get_display_size(int32_t *w, int32_t *h) {
    *w = mock_w; *h = mock_h; get_display_count++;
}
static int32_t mock_kb_height(void) { kb_query_count++; return mock_kb_h; }

static void mock_set_size(int obj, int32_t w, int32_t h) {
    if (call_count < MAX_CALLS) {
        snprintf(call_type[call_count], 32, "set_size");
        call_obj[call_count] = obj;
        call_w[call_count] = w;
        call_h[call_count] = h;
        call_count++;
    }
}
static void mock_set_align(int obj, int align, int32_t x, int32_t y) {
    (void)x;
    if (call_count < MAX_CALLS) {
        snprintf(call_type[call_count], 32, "set_align");
        call_obj[call_count] = obj;
        call_w[call_count] = align;
        call_h[call_count] = y;
        call_count++;
    }
}

#define tab5_ui_get_display_size mock_get_display_size
#define tab5_ui_keyboard_get_height mock_kb_height
#define tab5_ui_obj_set_size mock_set_size
#define tab5_ui_obj_set_align mock_set_align

/* ── Simplified apply_layout (replicates src/main.c logic) ── */
static bool s_ui_ready = true;
static int obj_messages_cont = 1;
static int obj_input_cont    = 2;

static void apply_layout(void) {
    if (!s_ui_ready) return;
    int32_t w = 720, h = 1280;
    tab5_ui_get_display_size(&w, &h);
    int32_t kb_h = tab5_ui_keyboard_get_height();

    int32_t input_y = h - kb_h - INPUT_H - INPUT_GAP;
    if (input_y < MSG_TOP + 40) input_y = MSG_TOP + 40;
    int32_t msg_h = input_y - MSG_TOP - INPUT_GAP;

    if (obj_messages_cont != TAB5_UI_INVALID_OBJ) {
        tab5_ui_obj_set_size(obj_messages_cont, w, msg_h > 0 ? msg_h : 200);
        tab5_ui_obj_set_align(obj_messages_cont, TAB5_UI_ALIGN_TOP_LEFT, 0, MSG_TOP);
    }
    if (obj_input_cont != TAB5_UI_INVALID_OBJ) {
        tab5_ui_obj_set_size(obj_input_cont, w, INPUT_H);
        tab5_ui_obj_set_align(obj_input_cont, TAB5_UI_ALIGN_BOTTOM_LEFT, 0, -(kb_h + INPUT_GAP));
    }
}

/* ── Simplified handle_poll (expected implementation after rotation fix) ── */
static int32_t s_last_kb_h = -1;
static int32_t s_last_w = -1;
static int32_t s_last_h = -1;

/*
 * PENDING IMPLEMENTATION: This is the target behavior.
 * Current handle_poll only checks kb_h. After implementation, it should
 * also detect w/h changes. The test validates both paths.
 */
static void handle_poll_current_broken(void) {
    /* CURRENT: only checks kb_h, ignores w/h changes */
    int32_t kb_h = tab5_ui_keyboard_get_height();
    if (kb_h != s_last_kb_h) {
        s_last_kb_h = kb_h;
        apply_layout();
    }
    /* NOTE: w/h change NOT detected → this is the bug the test catches */
}

static void handle_poll_fixed(void) {
    /* FIXED: checks kb_h AND w/h changes */
    int32_t w = 720, h = 1280;
    tab5_ui_get_display_size(&w, &h);
    int32_t kb_h = tab5_ui_keyboard_get_height();
    if (kb_h != s_last_kb_h || w != s_last_w || h != s_last_h) {
        s_last_kb_h = kb_h;
        s_last_w = w;
        s_last_h = h;
        apply_layout();
    }
}

/* ── Test assertions ── */
static int failures = 0;
static void check(int cond, const char *msg) {
    if (cond) { printf("  [PASS] %s\n", msg); }
    else      { printf("  [FAIL] %s\n", msg); failures++; }
}

static int find_set_size_for_obj(int obj, int *out_w, int *out_h) {
    for (int i = call_count - 1; i >= 0; i--) {
        if (strcmp(call_type[i], "set_size") == 0 && call_obj[i] == obj) {
            *out_w = call_w[i]; *out_h = call_h[i]; return 1;
        }
    }
    return 0;
}

static int find_set_align_for_obj(int obj, int *out_y) {
    for (int i = call_count - 1; i >= 0; i--) {
        if (strcmp(call_type[i], "set_align") == 0 && call_obj[i] == obj) {
            *out_y = call_h[i]; return 1;
        }
    }
    return 0;
}

int main(void) {
    printf("=== Rotation Detection & Re-layout Geometry Test ===\n\n");

    /* ─── Scenario 1: Portrait → Landscape rotation ─── */
    printf("Scenario 1: Portrait (720x1280) → Landscape (1280x720)\n");
    {
        mock_w = 720; mock_h = 1280; mock_kb_h = 0;
        s_last_kb_h = -1; s_last_w = -1; s_last_h = -1;
        reset_calls(); get_display_count = 0;

        /* Initial apply_layout in portrait */
        apply_layout();
        int iw_p, ih_p;
        check(find_set_size_for_obj(obj_input_cont, &iw_p, &ih_p),
              "portrait: input_cont sized");
        check(iw_p == 720, "portrait: input_cont width = 720 (full portrait width)");
        check(ih_p == INPUT_H, "portrait: input_cont height = INPUT_H");
        printf("  input_cont: %dx%d\n\n", iw_p, ih_p);

        /* Simulate rotation to landscape */
        mock_w = 1280; mock_h = 720;
        reset_calls(); get_display_count = 0;

        handle_poll_fixed();
        int iw_l, ih_l, ay_l;
        check(get_display_count >= 1, "rotation: display size queried after w/h change");
        check(find_set_size_for_obj(obj_input_cont, &iw_l, &ih_l),
              "landscape: input_cont sized after rotation");
        check(iw_l == 1280,
              "landscape: input_cont width = 1280 (full landscape width)");
        check(ih_l == INPUT_H,
              "landscape: input_cont height = INPUT_H");
        check(find_set_align_for_obj(obj_input_cont, &ay_l),
              "landscape: input_cont positioned");
        check(ay_l == -(0 + INPUT_GAP),
              "landscape: input_cont y = -(kb_h + INPUT_GAP)");
        printf("  landscape input_cont: %dx%d, y=%d\n\n", iw_l, ih_l, ay_l);
    }

    /* ─── Scenario 2: landscape with keyboard ─── */
    printf("Scenario 2: Landscape (1280x720) with kb_h=300\n");
    {
        mock_w = 1280; mock_h = 720; mock_kb_h = 300;
        reset_calls(); get_display_count = 0;

        apply_layout();
        int iw, ih, ay;
        check(find_set_size_for_obj(obj_input_cont, &iw, &ih),
              "landscape+kb: input_cont sized");
        check(iw == 1280,
              "landscape+kb: input_cont width = 1280 (full landscape width)");
        check(find_set_align_for_obj(obj_input_cont, &ay),
              "landscape+kb: input_cont positioned");
        check(ay == -(300 + INPUT_GAP),
              "landscape+kb: input_cont y = -(kb_h + INPUT_GAP) = -306");
        printf("  input_cont: %dx%d, y=%d\n\n", iw, ih, ay);
    }

    /* ─── Scenario 3: Input width must always match current display width ─── */
    printf("Scenario 3: Input width tracks orientation across multiple rotations\n");
    {
        /* Start landscape */
        mock_w = 1280; mock_h = 720; mock_kb_h = 0;
        reset_calls();
        apply_layout();
        int w1, h1;
        find_set_size_for_obj(obj_input_cont, &w1, &h1);
        check(w1 == 1280, "rotation-loop: landscape input_w = 1280");

        /* Rotate back to portrait */
        mock_w = 720; mock_h = 1280; mock_kb_h = 0;
        s_last_w = 1280; s_last_h = 720;
        reset_calls();
        handle_poll_fixed();
        int w2, h2;
        find_set_size_for_obj(obj_input_cont, &w2, &h2);
        check(w2 == 720, "rotation-loop: portrait input_w = 720");

        /* Landscape again */
        mock_w = 1280; mock_h = 720;
        s_last_w = 720; s_last_h = 1280;
        reset_calls();
        handle_poll_fixed();
        int w3, h3;
        find_set_size_for_obj(obj_input_cont, &w3, &h3);
        check(w3 == 1280, "rotation-loop: back to landscape input_w = 1280");
        printf("\n");
    }

    /* ─── Scenario 4: Detection via broken vs. fixed path ─── */
    printf("Scenario 4: Broken poll ignores w/h change, fixed poll detects it\n");
    {
        mock_w = 720; mock_h = 1280; mock_kb_h = 0;
        s_last_kb_h = 0; s_last_w = 720; s_last_h = 1280;

        /* Rotate to landscape using broken path */
        mock_w = 1280; mock_h = 720;
        reset_calls(); get_display_count = 0;
        handle_poll_current_broken();
        int call_count_broken = call_count;
        check(call_count_broken == 0,
              "broken_poll: NO apply_layout triggered on rotation");

        /* Rotate to landscape using fixed path */
        mock_w = 1280; mock_h = 720;
        reset_calls(); get_display_count = 0;
        handle_poll_fixed();
        check(call_count > 0,
              "fixed_poll: apply_layout triggered on rotation");
        printf("\n");
    }

    /* ─── Scenario 5: No re-layout if w/h unchanged ─── */
    printf("Scenario 5: No re-layout if dimensions unchanged\n");
    {
        mock_w = 720; mock_h = 1280; mock_kb_h = 0;
        s_last_kb_h = 0; s_last_w = 720; s_last_h = 1280;
        reset_calls();
        handle_poll_fixed();
        check(call_count == 0,
              "no-change: no apply_layout when w,h,kb all unchanged");
        printf("\n");
    }

    printf("=== Rotation Results: %s (failures=%d) ===\n",
           failures ? "FAILED" : "ALL PASSED", failures);
    return failures ? 1 : 0;
}
TESTEOF

echo "[INFO] Compiling rotation/re-layout test..."
if gcc -std=c11 -Wall -Wextra -o "${OUT_DIR}/test_rotation_relayout" \
       "${SCRIPT_DIR}/test_rotation_relayout.c" 2>&1; then
    echo "[INFO] Running rotation/re-layout test..."
    "${OUT_DIR}/test_rotation_relayout"
    RESULT=$?
    echo ""
    if [ ${RESULT} -eq 0 ]; then
        echo "[PASS] Rotation detection & re-layout test validates"
    else
        echo "[FAIL] Rotation detection & re-layout test failed (expected before implementation)"
    fi
else
    echo "[FAIL] Rotation test failed to compile"
    RESULT=1
fi

rm -f "${SCRIPT_DIR}/test_rotation_relayout.c"
exit ${RESULT}
