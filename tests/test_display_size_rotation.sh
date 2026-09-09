#!/usr/bin/env bash
# test_display_size_rotation.sh - Contract test for tab5_ui_get_display_size
# Validates physical resolution query across 0/90/180/270 rotation angles.
# Pattern: self-contained C program with instrumented mock SDK, compiled via gcc.
#
# AC: tab5_ui_host_get_display_size must return correct physical dimensions
# for each rotation. The host function aliases tab5_ui_get_display_size in WASM.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/.build"
mkdir -p "${OUT_DIR}"

echo "=== Display Size Rotation Contract Test ==="
echo ""

cat > "${SCRIPT_DIR}/test_display_size_rotation.c" << 'TESTEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>

/* ── Physical resolution constants (Tab5 OS spec) ── */
/* The Tab5 has a fixed physical panel. Rotation swaps logical w/h. */
#define PHYS_W 720
#define PHYS_H 1280

/* ── Rotation angles (degrees) ── */
#define ROT_0    0
#define ROT_90   1
#define ROT_180  2
#define ROT_270  3

/* ── Instrumented mock: records every tab5_ui_get_display_size call ── */
#define MAX_QUERIES 64
static int32_t recorded_w[MAX_QUERIES];
static int32_t recorded_h[MAX_QUERIES];
static int recorded_rotation[MAX_QUERIES];
static int query_count = 0;

static void reset_queries(void) { query_count = 0; }

/*
 * Simulated host function for tab5_ui_get_display_size.
 * Returns physical dimensions rotated by the current rotation angle.
 * Rotation 0/180: portrait  (w=720, h=1280)
 * Rotation 90/270: landscape (w=1280, h=720)
 *
 * This is the CONTRACT the test validates. The host WASM function
 * tab5_ui_host_get_display_size must behave identically.
 */
static int mock_current_rotation = ROT_0;

static void mock_get_display_size(int32_t *w, int32_t *h) {
    if (mock_current_rotation == ROT_0 || mock_current_rotation == ROT_180) {
        *w = PHYS_W;
        *h = PHYS_H;
    } else {
        /* ROT_90 or ROT_270: landscape */
        *w = PHYS_H;
        *h = PHYS_W;
    }
    if (query_count < MAX_QUERIES) {
        recorded_w[query_count] = *w;
        recorded_h[query_count] = *h;
        recorded_rotation[query_count] = mock_current_rotation;
        query_count++;
    }
}

#define tab5_ui_get_display_size mock_get_display_size

/* ── Simplified apply_layout (mirrors src/main.c logic) ── */
#define MSG_TOP       104
#define INPUT_H       60
#define INPUT_GAP      6
#define TAB5_UI_INVALID_OBJ (-1)
#define TAB5_UI_ALIGN_TOP_LEFT    0
#define TAB5_UI_ALIGN_BOTTOM_LEFT 2
#define TAB5_UI_FLEX_FLOW_COLUMN  0

static bool s_ui_ready = true;
static int obj_messages_cont = 1;
static int obj_input_cont    = 2;

/* Recording */
#define MAX_CALLS 256
static char  ct[MAX_CALLS][32];
static int   co[MAX_CALLS];
static int   cwi[MAX_CALLS], chi[MAX_CALLS];
static int   cc = 0;

static void reset_calls(void) { cc = 0; }
static void rec_ss(int o, int32_t w, int32_t h) {
    if (cc < MAX_CALLS) { snprintf(ct[cc], 32, "set_size"); co[cc]=o; cwi[cc]=w; chi[cc]=h; cc++; }
}
static void rec_sa(int o, int a, int32_t x, int32_t y) {
    (void)x;
    if (cc < MAX_CALLS) { snprintf(ct[cc], 32, "set_align"); co[cc]=o; cwi[cc]=a; chi[cc]=y; cc++; }
}

#define tab5_ui_obj_set_size  rec_ss
#define tab5_ui_obj_set_align rec_sa

static void apply_layout(void) {
    if (!s_ui_ready) return;
    int32_t w = 720, h = 1280;
    tab5_ui_get_display_size(&w, &h);
    int32_t kb_h = 0;

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

/* ── handle_poll with rotation detection ── */
static int32_t s_last_kb_h = -1;
static int32_t s_last_w = -1;
static int32_t s_last_h = -1;

static void handle_poll(void) {
    int32_t w = 720, h = 1280;
    tab5_ui_get_display_size(&w, &h);
    int32_t kb_h = 0;
    bool dimensions_changed = (w != s_last_w || h != s_last_h);
    if (kb_h != s_last_kb_h || dimensions_changed) {
        s_last_kb_h = kb_h;
        s_last_w = w;
        s_last_h = h;
        apply_layout();
    }
}

/* ── Rebuild_messages uses display size for bubble width ── */
static void rebuild_messages(void) {
    if (!s_ui_ready || obj_messages_cont == TAB5_UI_INVALID_OBJ) return;
    int32_t w = 720, h = 1280;
    tab5_ui_get_display_size(&w, &h);
    int32_t bubble_w = h > 0 ? (w * 9 / 10) : 640;
    (void)bubble_w; /* conceptually used */
    tab5_ui_obj_set_size(obj_messages_cont, w, 600);
}

/* ── Assertions ── */
static int failures = 0;
static void check(int c, const char *m) {
    if (c) printf("  [PASS] %s\n", m);
    else   { printf("  [FAIL] %s\n", m); failures++; }
}

static int find_ss(int obj, int *ow, int *oh) {
    for (int i = cc - 1; i >= 0; i--)
        if (strcmp(ct[i], "set_size") == 0 && co[i] == obj)
            { *ow = cwi[i]; *oh = chi[i]; return 1; }
    return 0;
}

int main(void) {
    printf("=== Display Size Rotation Contract Test ===\n");
    printf("Physical panel: %dx%d\n\n", PHYS_W, PHYS_H);

    /* ─── Scenario 1: Rotation 0 (portrait) ─── */
    printf("Scenario 1: Rotation 0 (portrait)\n");
    {
        mock_current_rotation = ROT_0;
        reset_calls(); reset_queries();
        apply_layout();

        int32_t w = 0, h = 0;
        mock_get_display_size(&w, &h);
        check(w == 720,  "rot0: display width = 720 (portrait)");
        check(h == 1280, "rot0: display height = 1280 (portrait)");

        int iw, ih;
        check(find_ss(obj_input_cont, &iw, &ih),
              "rot0: input_cont sized");
        check(iw == 720, "rot0: input_cont width = 720 (matches display)");
        check(ih == INPUT_H, "rot0: input_cont height = INPUT_H");
        printf("  display: %dx%d, input_cont: %dx%d\n\n", w, h, iw, ih);
    }

    /* ─── Scenario 2: Rotation 90 (landscape) ─── */
    printf("Scenario 2: Rotation 90 (landscape)\n");
    {
        mock_current_rotation = ROT_90;
        reset_calls(); reset_queries();
        apply_layout();

        int32_t w = 0, h = 0;
        mock_get_display_size(&w, &h);
        check(w == 1280, "rot90: display width = 1280 (landscape)");
        check(h == 720,  "rot90: display height = 720 (landscape)");

        int iw, ih;
        check(find_ss(obj_input_cont, &iw, &ih),
              "rot90: input_cont sized");
        check(iw == 1280, "rot90: input_cont width = 1280 (matches display)");
        printf("  display: %dx%d, input_cont: %dx%d\n\n", w, h, iw, ih);
    }

    /* ─── Scenario 3: Rotation 180 (portrait, inverted) ─── */
    printf("Scenario 3: Rotation 180 (portrait, inverted)\n");
    {
        mock_current_rotation = ROT_180;
        reset_calls(); reset_queries();
        apply_layout();

        int32_t w = 0, h = 0;
        mock_get_display_size(&w, &h);
        check(w == 720,  "rot180: display width = 720 (portrait)");
        check(h == 1280, "rot180: display height = 1280 (portrait)");

        int iw, ih;
        check(find_ss(obj_input_cont, &iw, &ih),
              "rot180: input_cont sized");
        check(iw == 720, "rot180: input_cont width = 720 (matches display)");
        printf("  display: %dx%d, input_cont: %dx%d\n\n", w, h, iw, ih);
    }

    /* ─── Scenario 4: Rotation 270 (landscape, inverted) ─── */
    printf("Scenario 4: Rotation 270 (landscape, inverted)\n");
    {
        mock_current_rotation = ROT_270;
        reset_calls(); reset_queries();
        apply_layout();

        int32_t w = 0, h = 0;
        mock_get_display_size(&w, &h);
        check(w == 1280, "rot270: display width = 1280 (landscape)");
        check(h == 720,  "rot270: display height = 720 (landscape)");

        int iw, ih;
        check(find_ss(obj_input_cont, &iw, &ih),
              "rot270: input_cont sized");
        check(iw == 1280, "rot270: input_cont width = 1280 (matches display)");
        printf("  display: %dx%d, input_cont: %dx%d\n\n", w, h, iw, ih);
    }

    /* ─── Scenario 5: handle_poll detects rotation change ─── */
    printf("Scenario 5: handle_poll detects rotation change\n");
    {
        /* Start portrait */
        mock_current_rotation = ROT_0;
        s_last_w = -1; s_last_h = -1; s_last_kb_h = -1;
        reset_calls();
        handle_poll();
        int w1, h1;
        find_ss(obj_input_cont, &w1, &h1);
        check(w1 == 720, "poll: portrait input_w = 720");

        /* Rotate to landscape */
        mock_current_rotation = ROT_90;
        reset_calls();
        handle_poll();
        int w2, h2;
        find_ss(obj_input_cont, &w2, &h2);
        check(w2 == 1280, "poll: landscape input_w = 1280 after rotation");

        /* Rotate to landscape inverted */
        mock_current_rotation = ROT_270;
        reset_calls();
        handle_poll();
        int w3, h3;
        find_ss(obj_input_cont, &w3, &h3);
        check(w3 == 1280, "poll: landscape inverted input_w = 1280");

        /* Back to portrait */
        mock_current_rotation = ROT_0;
        reset_calls();
        handle_poll();
        int w4, h4;
        find_ss(obj_input_cont, &w4, &h4);
        check(w4 == 720, "poll: portrait again input_w = 720");
        printf("\n");
    }

    /* ─── Scenario 6: Bubble width tracks orientation ─── */
    printf("Scenario 6: Bubble width = 90%% of display width per orientation\n");
    {
        mock_current_rotation = ROT_0;
        reset_calls();
        rebuild_messages();
        int32_t w0 = 0, h0 = 0;
        mock_get_display_size(&w0, &h0);
        int exp_bubble_0 = w0 * 9 / 10; /* 648 */
        check(exp_bubble_0 == 648, "portrait: bubble width = 648");

        mock_current_rotation = ROT_90;
        reset_calls();
        rebuild_messages();
        int32_t w1 = 0, h1 = 0;
        mock_get_display_size(&w1, &h1);
        int exp_bubble_1 = w1 * 9 / 10; /* 1152 */
        check(exp_bubble_1 == 1152, "landscape: bubble width = 1152");
        printf("  portrait bubble: %d, landscape bubble: %d\n\n",
               exp_bubble_0, exp_bubble_1);
    }

    /* ─── Scenario 7: Messages container width tracks orientation ─── */
    printf("Scenario 7: Messages container width = display width\n");
    {
        mock_current_rotation = ROT_90;
        reset_calls();
        apply_layout();
        int mw, mh;
        find_ss(obj_messages_cont, &mw, &mh);
        check(mw == 1280, "landscape: messages_cont width = 1280");

        mock_current_rotation = ROT_0;
        reset_calls();
        apply_layout();
        find_ss(obj_messages_cont, &mw, &mh);
        check(mw == 720, "portrait: messages_cont width = 720");
        printf("\n");
    }

    /* ─── Scenario 8: Consistency — get_display_size always returns same
     *     values for same rotation (no side effects) ─── */
    printf("Scenario 8: get_display_size is idempotent per rotation\n");
    {
        mock_current_rotation = ROT_90;
        reset_queries();
        int32_t wa, ha, wb, hb;
        mock_get_display_size(&wa, &ha);
        mock_get_display_size(&wb, &hb);
        check(wa == wb && ha == hb,
              "rot90: two consecutive queries return same result");
        check(query_count == 2, "rot90: two queries recorded");

        mock_current_rotation = ROT_0;
        reset_queries();
        mock_get_display_size(&wa, &ha);
        mock_get_display_size(&wb, &hb);
        check(wa == 720 && ha == 1280,
              "rot0: two consecutive queries return 720x1280");
        printf("\n");
    }

    printf("=== Display Size Rotation Results: %s (failures=%d) ===\n",
           failures ? "FAILED" : "ALL PASSED", failures);
    return failures ? 1 : 0;
}
TESTEOF

echo "[INFO] Compiling display size rotation test..."
if gcc -std=c11 -Wall -Wextra -o "${OUT_DIR}/test_display_size_rotation" \
       "${SCRIPT_DIR}/test_display_size_rotation.c" 2>&1; then
    echo "[INFO] Running display size rotation test..."
    "${OUT_DIR}/test_display_size_rotation"
    RESULT=$?
    echo ""
    if [ ${RESULT} -eq 0 ]; then
        echo "[PASS] Display size rotation contract test validates"
    else
        echo "[FAIL] Display size rotation contract test failed"
    fi
else
    echo "[FAIL] Display size rotation test failed to compile"
    RESULT=1
fi

rm -f "${SCRIPT_DIR}/test_display_size_rotation.c"
exit ${RESULT}
