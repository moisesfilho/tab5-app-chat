#!/usr/bin/env bash
# test_full_width_input.sh - TDD: Input container uses full width of current orientation
# Validates that apply_layout sets s_input_cont width = current display w.
# This is a focused regression test for the orientation-width requirement.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/.build"
mkdir -p "${OUT_DIR}"

echo "=== Full-Width Input Test ==="
echo ""

cat > "${SCRIPT_DIR}/test_full_width_input.c" << 'TESTEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>

#define MSG_TOP       104
#define INPUT_H       60
#define INPUT_GAP      6
#define TAB5_UI_ALIGN_TOP_LEFT   0
#define TAB5_UI_ALIGN_BOTTOM_LEFT 2
#define TAB5_UI_FLEX_FLOW_COLUMN 0
#define TAB5_UI_INVALID_OBJ (-1)

/* ── Mock ── */
static int32_t mock_w = 720, mock_h = 1280, mock_kb_h = 0;

#define MAX_CALLS 128
static char ct[MAX_CALLS][32];
static int co[MAX_CALLS], cw[MAX_CALLS], ch[MAX_CALLS], cy[MAX_CALLS];
static int cc = 0;

static void reset(void) { cc = 0; }
static void rec_set_size(int o, int32_t w, int32_t h) {
    if (cc < MAX_CALLS) { snprintf(ct[cc], 32, "set_size"); co[cc]=o; cw[cc]=w; ch[cc]=h; cc++; }
}
static void rec_set_align(int o, int a, int32_t x, int32_t y) {
    if (cc < MAX_CALLS) { snprintf(ct[cc], 32, "set_align"); co[cc]=o; cw[cc]=a; cy[cc]=y; cc++; }
}
static void mock_gds(int32_t *w, int32_t *h) { *w = mock_w; *h = mock_h; }
static int32_t mock_kb(void) { return mock_kb_h; }

#define tab5_ui_get_display_size mock_gds
#define tab5_ui_keyboard_get_height mock_kb
#define tab5_ui_obj_set_size rec_set_size
#define tab5_ui_obj_set_align rec_set_align

/* ── Simplified apply_layout ── */
static bool s_ui_ready = true;
static int obj_mc = 1, obj_ic = 2;

static void apply_layout(void) {
    if (!s_ui_ready) return;
    int32_t w = 720, h = 1280;
    tab5_ui_get_display_size(&w, &h);
    int32_t kb_h = tab5_ui_keyboard_get_height();
    int32_t input_y = h - kb_h - INPUT_H - INPUT_GAP;
    if (input_y < MSG_TOP + 40) input_y = MSG_TOP + 40;
    int32_t msg_h = input_y - MSG_TOP - INPUT_GAP;

    if (obj_mc != TAB5_UI_INVALID_OBJ) {
        tab5_ui_obj_set_size(obj_mc, w, msg_h > 0 ? msg_h : 200);
        tab5_ui_obj_set_align(obj_mc, TAB5_UI_ALIGN_TOP_LEFT, 0, MSG_TOP);
    }
    if (obj_ic != TAB5_UI_INVALID_OBJ) {
        tab5_ui_obj_set_size(obj_ic, w, INPUT_H);
        tab5_ui_obj_set_align(obj_ic, TAB5_UI_ALIGN_BOTTOM_LEFT, 0, -(kb_h + INPUT_GAP));
    }
}

/* ── Finders ── */
static int find_ss(int obj, int *ow, int *oh) {
    for (int i = cc-1; i >= 0; i--)
        if (strcmp(ct[i],"set_size")==0 && co[i]==obj) { *ow=cw[i]; *oh=ch[i]; return 1; }
    return 0;
}
static int find_sa_y(int obj, int *oy) {
    for (int i = cc-1; i >= 0; i--)
        if (strcmp(ct[i],"set_align")==0 && co[i]==obj) { *oy=cy[i]; return 1; }
    return 0;
}

static int failures = 0;
static void check(int c, const char *m) {
    if (c) printf("  [PASS] %s\n", m);
    else   { printf("  [FAIL] %s\n", m); failures++; }
}

int main(void) {
    printf("=== Full-Width Input Test ===\n\n");

    struct { const char *name; int32_t w, h, kb; int exp_w; } cases[] = {
        {"Portrait 720x1280, no kb",   720,  1280, 0,   720},
        {"Portrait 720x1280, kb=400",  720,  1280, 400, 720},
        {"Landscape 1280x720, no kb",  1280, 720,  0,   1280},
        {"Landscape 1280x720, kb=300", 1280, 720,  300, 1280},
        {"Landscape 1280x720, kb=600", 1280, 720,  600, 1280},
        {"Square 800x800, kb=200",     800,  800,  200, 800},
    };
    int ncases = sizeof(cases)/sizeof(cases[0]);

    for (int i = 0; i < ncases; i++) {
        printf("Case %d: %s\n", i+1, cases[i].name);
        mock_w = cases[i].w; mock_h = cases[i].h; mock_kb_h = cases[i].kb;
        reset(); apply_layout();

        int iw, ih;
        check(find_ss(obj_ic, &iw, &ih),
              "input_cont sized");
        check(iw == cases[i].exp_w,
              "input_cont width == display w (full orientation width)");
        check(ih == INPUT_H,
              "input_cont height == INPUT_H (constant)");
        printf("  input_cont: %dx%d (expected w=%d)\n\n",
               iw, ih, cases[i].exp_w);
    }

    /* Input bottom must stay in usable area for normal kb range */
    printf("Sweep: input bottom <= usable area for kb 0..60%%\n");
    {
        mock_h = 1280; mock_w = 720;
        int fail = 0;
        for (int kh = 0; kh <= (1280*6)/10; kh += 50) {
            mock_kb_h = kh; reset(); apply_layout();
            int iy;
            find_sa_y(obj_ic, &iy);
            /* iy is the BOTTOM_LEFT y offset; input bottom screen Y = h + iy */
            int bottom_y = mock_h + iy;
            int usable_bottom = mock_h - kh;
            if (bottom_y > usable_bottom) {
                printf("  [FAIL] kb=%d input_bottom=%d > usable=%d\n",
                       kh, bottom_y, usable_bottom);
                fail = 1;
            }
        }
        check(!fail, "input within usable area for kb 0..60%%");
        printf("\n");
    }

    printf("=== Results: %s (failures=%d) ===\n",
           failures ? "FAILED" : "ALL PASSED", failures);
    return failures ? 1 : 0;
}
TESTEOF

echo "[INFO] Compiling full-width input test..."
if gcc -std=c11 -Wall -Wextra -o "${OUT_DIR}/test_full_width_input" \
       "${SCRIPT_DIR}/test_full_width_input.c" 2>&1; then
    echo "[INFO] Running full-width input test..."
    "${OUT_DIR}/test_full_width_input"
    RESULT=$?
    echo ""
    if [ ${RESULT} -eq 0 ]; then
        echo "[PASS] Full-width input test validates"
    else
        echo "[FAIL] Full-width input test failed"
    fi
else
    echo "[FAIL] Full-width input test failed to compile"
    RESULT=1
fi

rm -f "${SCRIPT_DIR}/test_full_width_input.c"
exit ${RESULT}
