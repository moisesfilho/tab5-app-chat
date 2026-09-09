#!/usr/bin/env bash
# test_modal_landscape_keyboard.sh - Contrato do modal CHAT em paisagem com teclado.
# Valida o plano aprovado (contrato relativo): modal/backdrop PCT(100) x PCT(100),
# card PCT(96) x PCT(60), CENTER offset -(kb_h/2), sem dimensões absolutas
# (w/h/card_h/usable_h) no caminho modal. O card resolve contra a tela VISUAL;
# quando o host está stale (720x1280) e a tela visual é 1280x720, a geometria
# segue o visual e o teclado preserva o offset centralizado.
# Padrão: programa C autocontido com mock SDK instrumentado, compilado por gcc.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/.build"
mkdir -p "${OUT_DIR}"

echo "=== Modal Landscape + Keyboard Test ==="
echo ""

cat > "${SCRIPT_DIR}/test_modal_landscape_kb.c" << 'TESTEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>

/* ── Constants (espelham tab5_sdk.h) ── */
#define TAB5_UI_ALIGN_CENTER     1
#define TAB5_UI_ALIGN_TOP_LEFT  0
#define TAB5_UI_FLEX_FLOW_COLUMN 0
#define TAB5_UI_FLEX_FLOW_ROW    1
#define TAB5_UI_PCT(x)          (-1000 - (x))   /* encoding real do SDK */
#define TAB5_UI_SIZE_CONTENT    (-1)
#define TAB5_UI_INVALID_OBJ     (-1)

/* Resolução percentual host-side (base * pct / 100, arredondado). */
static int pctpx(int base, int pct) { return (base * pct + 50) / 100; }

/* ── Instrumented mock ── */
static int32_t mock_w = 720, mock_h = 1280;
static int32_t mock_kb_h = 0;

#define MAX_CALLS 512
static char  ct[MAX_CALLS][40];
static int   co[MAX_CALLS];
static int32_t cv1[MAX_CALLS], cv2[MAX_CALLS], cv3[MAX_CALLS];
static int   cc = 0;

static int mock_next_id = 10;
static void reset_calls(void) { cc = 0; mock_next_id = 10; }
static void rec(const char *t, int o, int32_t a, int32_t b, int32_t c) {
    if (cc < MAX_CALLS) {
        snprintf(ct[cc], 40, "%s", t);
        co[cc] = o; cv1[cc] = a; cv2[cc] = b; cv3[cc] = c;
        cc++;
    }
}

static void __attribute__((unused)) mock_gds(int32_t *w, int32_t *h) { rec("get_display", 0, *w, *h, 0); }
static int32_t mock_kb(void) { return mock_kb_h; }
static int mock_create(int p) { (void)p; return ++mock_next_id; }
static void mock_ss(int o, int32_t w, int32_t h) { rec("set_size", o, w, h, 0); }
static void mock_sa(int o, int a, int32_t x, int32_t y) { (void)x; rec("set_align", o, a, x, y); }

#define tab5_ui_get_display_size   mock_gds
#define tab5_ui_keyboard_get_height mock_kb
#define tab5_ui_container_create   mock_create
#define tab5_ui_obj_set_size       mock_ss
#define tab5_ui_obj_set_align      mock_sa

/* ── apply_modal_layout (mirrors src/main.c apply_modal_layout) ── */
static bool s_modal_open = false;
static int OBJ_MODAL = 1;
static int OBJ_BACKDROP = 0;
static int OBJ_CARD = 0;

static void apply_modal_layout(void) {
    if (!s_modal_open || OBJ_MODAL == TAB5_UI_INVALID_OBJ) return;

    int32_t kb_h = tab5_ui_keyboard_get_height();
    if (kb_h < 0) kb_h = 0;

    tab5_ui_obj_set_size(OBJ_MODAL, TAB5_UI_PCT(100), TAB5_UI_PCT(100));
    tab5_ui_obj_set_align(OBJ_MODAL, TAB5_UI_ALIGN_TOP_LEFT, 0, 0);
    if (OBJ_BACKDROP != 0) {
        tab5_ui_obj_set_size(OBJ_BACKDROP, TAB5_UI_PCT(100), TAB5_UI_PCT(100));
        tab5_ui_obj_set_align(OBJ_BACKDROP, TAB5_UI_ALIGN_TOP_LEFT, 0, 0);
    }
    if (OBJ_CARD != 0) {
        tab5_ui_obj_set_size(OBJ_CARD, TAB5_UI_PCT(96), TAB5_UI_PCT(60));
        tab5_ui_obj_set_align(OBJ_CARD, TAB5_UI_ALIGN_CENTER, 0, -(kb_h / 2));
    }
}

/* ── open_config_modal (mirrors src/main.c: termina em apply_modal_layout) ── */
static void open_config_modal_landscape(void) {
    if (s_modal_open) return;
    s_modal_open = true;

    /* Modal: tela cheia relativa (PCT(100) x PCT(100)) */
    tab5_ui_obj_set_size(OBJ_MODAL, TAB5_UI_PCT(100), TAB5_UI_PCT(100));
    tab5_ui_obj_set_align(OBJ_MODAL, TAB5_UI_ALIGN_TOP_LEFT, 0, 0);

    /* Backdrop: tela cheia relativa */
    OBJ_BACKDROP = mock_create(OBJ_MODAL);
    tab5_ui_obj_set_size(OBJ_BACKDROP, TAB5_UI_PCT(100), TAB5_UI_PCT(100));
    tab5_ui_obj_set_align(OBJ_BACKDROP, TAB5_UI_ALIGN_TOP_LEFT, 0, 0);

    /* Card */
    OBJ_CARD = mock_create(OBJ_MODAL);
    tab5_ui_obj_set_size(OBJ_CARD, TAB5_UI_PCT(96), TAB5_UI_PCT(60));
    tab5_ui_obj_set_align(OBJ_CARD, TAB5_UI_ALIGN_CENTER, 0, 0);

    apply_modal_layout();
}

/* ── Field content estimate for landscape modal ── */
/*
 * Card internal layout (from src/main.c):
 *   Padding top:     16px
 *   Title label      ~24px
 *   Base URL label   ~18px
 *   Textarea          42px
 *   Token label      ~18px
 *   Textarea          42px
 *   Model label      ~18px
 *   Textarea          42px
 *   Max tokens label ~18px
 *   Textarea          42px
 *   Buttons row       48px
 *   Gaps: 10px × ~9 = 90px
 *   Padding bottom:  16px
 *   Total ≈ 376px
 */
#define ESTIMATED_CONTENT_H 376

/* ── Finders ── */
static int find_ss(int obj, int *ow, int *oh) {
    for (int i = cc - 1; i >= 0; i--)
        if (strcmp(ct[i], "set_size") == 0 && co[i] == obj)
            { if (ow) *ow = (int)cv1[i]; if (oh) *oh = (int)cv2[i]; return 1; }
    return 0;
}
static int find_sa(int obj, int *oa, int *oy) {
    for (int i = cc - 1; i >= 0; i--)
        if (strcmp(ct[i], "set_align") == 0 && co[i] == obj)
            { *oa = (int)cv1[i]; *oy = (int)cv3[i]; return 1; }
    return 0;
}
static int count_gds(void) {
    int n = 0;
    for (int i = 0; i < cc; i++)
        if (strcmp(ct[i], "get_display") == 0) n++;
    return n;
}

/* ── Assertions ── */
static int failures = 0;
static void check(int c, const char *m) {
    if (c) printf("  [PASS] %s\n", m);
    else   { printf("  [FAIL] %s\n", m); failures++; }
}

int main(void) {
    printf("=== Modal Landscape + Keyboard Test — Contrato relativo ===\n\n");

    check(TAB5_UI_PCT(100) == -1100, "TAB5_UI_PCT(100) == -1100");
    check(TAB5_UI_PCT(96)  == -1096, "TAB5_UI_PCT(96) == -1096");
    check(TAB5_UI_PCT(60)  == -1060, "TAB5_UI_PCT(60) == -1060");

    /* ─── Scenario 1: Landscape 1280x720, no keyboard ─── */
    printf("\nScenario 1: Landscape 1280x720, kb_h=0\n");
    {
        mock_w = 1280; mock_h = 720; mock_kb_h = 0;
        s_modal_open = false; reset_calls();
        open_config_modal_landscape();

        int mw, mh, bw, bh, cw, ch;
        check(find_ss(OBJ_MODAL, &mw, &mh), "modal: sized");
        check(mw == -1100 && mh == -1100, "landscape: modal = PCT(100) x PCT(100)");
        check(find_ss(OBJ_BACKDROP, &bw, &bh), "backdrop: sized");
        check(bw == -1100 && bh == -1100, "landscape: backdrop = PCT(100) x PCT(100)");
        check(find_ss(OBJ_CARD, &cw, &ch), "card: sized");
        check(cw == -1096 && ch == -1060, "landscape: card = PCT(96) x PCT(60)");
        check(pctpx(1280, 96) == 1229 && pctpx(720, 60) == 432,
              "landscape: card resolvido 1229x432 (visual 1280x720)");
        int a, oy;
        check(find_sa(OBJ_CARD, &a, &oy), "card: aligned");
        check(a == TAB5_UI_ALIGN_CENTER && oy == 0, "landscape: CENTER offset 0 (sem teclado)");
        check(count_gds() == 0,
              "landscape: SEM tab5_ui_get_display_size no caminho modal (host não vaza)");
        printf("  card: %dx%d offset=%d\n\n", cw, ch, oy);
    }

    /* ─── Scenario 2: Landscape + moderate keyboard ─── */
    printf("Scenario 2: Landscape 1280x720, kb_h=200\n");
    {
        mock_w = 1280; mock_h = 720; mock_kb_h = 200;
        s_modal_open = false; reset_calls();
        open_config_modal_landscape();

        int cw, ch, oy;
        check(find_ss(OBJ_CARD, &cw, &ch), "card: sized");
        check(cw == -1096 && ch == -1060, "landscape+mod_kb: card PCT(96) x PCT(60) (sem card_h)");
        check(pctpx(720, 60) >= ESTIMATED_CONTENT_H,
              "landscape+mod_kb: card resolvido 432px acomoda os campos");
        int a;
        check(find_sa(OBJ_CARD, &a, &oy), "landscape+mod_kb: card positioned");
        check(a == TAB5_UI_ALIGN_CENTER && oy == -(200 / 2),
              "landscape+mod_kb: CENTER offset = -(kb_h/2) = -100");
        printf("  card_h=%d, content=%d, y=%d\n\n", pctpx(720, 60), ESTIMATED_CONTENT_H, oy);
    }

    /* ─── Scenario 3: Landscape + large keyboard ─── */
    printf("Scenario 3: Landscape 1280x720, kb_h=400\n");
    {
        mock_w = 1280; mock_h = 720; mock_kb_h = 400;
        s_modal_open = false; reset_calls();
        open_config_modal_landscape();

        int cw, ch, a, oy;
        check(find_ss(OBJ_CARD, &cw, &ch), "card: sized");
        check(cw == -1096 && ch == -1060, "landscape+large_kb: card PCT(96) x PCT(60)");
        check(pctpx(720, 60) >= ESTIMATED_CONTENT_H,
              "landscape+large_kb: card 432px ainda acomoda os campos (PCT(60) do visual)");
        check(find_sa(OBJ_CARD, &a, &oy), "landscape+large_kb: card positioned");
        check(oy == -(400 / 2), "landscape+large_kb: CENTER offset = -(400/2) = -200");
        printf("  card resolvido=%dpx, y=%d\n\n", pctpx(720, 60), oy);
    }

    /* ─── Scenario 4: Landscape + keyboard fills most of screen ─── */
    printf("Scenario 4: Landscape 1280x720, kb_h=550 (extreme)\n");
    {
        mock_w = 1280; mock_h = 720; mock_kb_h = 550;
        s_modal_open = false; reset_calls();
        open_config_modal_landscape();

        int cw, ch, a, oy;
        check(find_ss(OBJ_CARD, &cw, &ch), "card: sized");
        check(cw == -1096 && ch == -1060, "landscape+extreme_kb: card permanece PCT(96) x PCT(60)");
        check(find_sa(OBJ_CARD, &a, &oy), "landscape+extreme_kb: card positioned");
        check(oy == -(550 / 2), "landscape+extreme_kb: CENTER offset = -(550/2) = -275");
        check(720 - 550 < ESTIMATED_CONTENT_H,
              "landscape+extreme_kb: área visível 170px < 376px → conteúdo rola (card scrollable)");
        printf("  card: %dx%d offset=%d\n\n", cw, ch, oy);
    }

    /* ─── Scenario 5: apply_modal_layout updates after a keyboard change ─── */
    printf("Scenario 5: apply_modal_layout repositions after keyboard appears\n");
    {
        mock_w = 1280; mock_h = 720; mock_kb_h = 0;
        s_modal_open = false; reset_calls();
        open_config_modal_landscape();

        int a_before, oy_before, ch_before;
        find_ss(OBJ_CARD, NULL, &ch_before);
        find_sa(OBJ_CARD, &a_before, &oy_before);

        /* Keyboard appears */
        mock_kb_h = 300;
        reset_calls();
        apply_modal_layout();

        int ch_after, a_after, oy_after;
        find_ss(OBJ_CARD, NULL, &ch_after);
        find_sa(OBJ_CARD, &a_after, &oy_after);

        check(ch_after == -1060 && oy_after == -150,
              "apply_modal: card permanece PCT(60) com offset -(kb_h/2) = -150");
        check(oy_after != oy_before, "apply_modal: offset mudou com o teclado");
        printf("  before: ch=%d y=%d, after: ch=%d y=%d\n\n",
               ch_before, oy_before, ch_after, oy_after);
    }

    /* ─── Scenario 6: Full cycle — landscape → kb → kb hide ─── */
    printf("Scenario 6: Full lifecycle — landscape → kb → hide\n");
    {
        mock_w = 1280; mock_h = 720; mock_kb_h = 0;
        s_modal_open = false; reset_calls();
        open_config_modal_landscape();

        int a, oy1;
        find_sa(OBJ_CARD, &a, &oy1);
        check(oy1 == 0, "lifecycle: initial CENTER offset 0 (no kb)");

        /* Keyboard appears */
        mock_kb_h = 300;
        reset_calls();
        apply_modal_layout();
        int oy2;
        find_sa(OBJ_CARD, &a, &oy2);
        check(oy2 == -150, "lifecycle: kb appears → offset -(300/2) = -150");

        /* Keyboard disappears */
        mock_kb_h = 0;
        reset_calls();
        apply_modal_layout();
        int oy3;
        find_sa(OBJ_CARD, &a, &oy3);
        check(oy3 == 0, "lifecycle: kb hides → offset 0");
        printf("\n");
    }

    /* ─── Scenario 7: Portrait vs landscape com mesma geometria PCT ─── */
    printf("Scenario 7: Same kb_h across portrait and landscape\n");
    {
        /* Portrait */
        mock_w = 720; mock_h = 1280; mock_kb_h = 400;
        s_modal_open = false; reset_calls();
        open_config_modal_landscape();
        int pw, ph, cw_p, ch_p, a_p, oy_p;
        find_ss(OBJ_MODAL, &pw, &ph);
        find_ss(OBJ_CARD, &cw_p, &ch_p);
        find_sa(OBJ_CARD, &a_p, &oy_p);
        check(count_gds() == 0,
              "portrait: SEM tab5_ui_get_display_size no caminho modal (host não vaza)");

        /* Landscape */
        mock_w = 1280; mock_h = 720; mock_kb_h = 400;
        s_modal_open = false; reset_calls();
        open_config_modal_landscape();
        int lw, lh, cw_l, ch_l, a_l, oy_l;
        find_ss(OBJ_MODAL, &lw, &lh);
        find_ss(OBJ_CARD, &cw_l, &ch_l);
        find_sa(OBJ_CARD, &a_l, &oy_l);
        check(count_gds() == 0,
              "landscape: SEM tab5_ui_get_display_size no caminho modal (host stale não vaza)");

        check(pw == -1100 && ph == -1100, "portrait: modal = PCT(100) x PCT(100)");
        check(lw == -1100 && lh == -1100, "landscape: modal = PCT(100) x PCT(100)");
        check(cw_p == -1096 && cw_l == -1096, "card width PCT(96) em ambas as orientações");
        check(ch_p == -1060 && ch_l == -1060, "card height PCT(60) em ambas as orientações");
        check(pctpx(1280, 60) > pctpx(720, 60),
              "landscape: card resolvido é mais baixo que o retrato (432 < 768 — espaço visual)");
        check(oy_p == -200 && oy_l == -200, "offset -(400/2) idêntico em ambas as orientações");
        printf("  portrait: card %dx%d, landscape: card %dx%d\n\n",
               pctpx(720, 96), pctpx(1280, 60), pctpx(1280, 96), pctpx(720, 60));
    }

    /* ─── Scenario 8: Card width sempre PCT(96), independente da resolução ─── */
    printf("Scenario 8: Card width sempre = TAB5_UI_PCT(96) (-1096)\n");
    {
        int widths[][2] = {{720, 1280}, {1280, 720}, {1080, 1920}};
        bool all_ok = true;
        for (int i = 0; i < 3; i++) {
            mock_w = widths[i][0]; mock_h = widths[i][1]; mock_kb_h = 200;
            s_modal_open = false; reset_calls();
            open_config_modal_landscape();
            int cw;
            find_ss(OBJ_CARD, &cw, NULL);
            if (cw != -1096) all_ok = false;
            printf("  display: %dx%d, card_w: %d\n",
                   widths[i][0], widths[i][1], cw);
        }
        check(all_ok, "card width = TAB5_UI_PCT(96) (-1096) em qualquer resolução (sem w-48)");
        printf("\n");
    }

    printf("=== Modal Landscape+KB Results: %s (failures=%d) ===\n",
           failures ? "FAILED" : "ALL PASSED", failures);
    return failures ? 1 : 0;
}
TESTEOF

echo "[INFO] Compiling modal landscape + keyboard test..."
if gcc -std=c11 -Wall -Wextra -o "${OUT_DIR}/test_modal_landscape_kb" \
       "${SCRIPT_DIR}/test_modal_landscape_kb.c" 2>&1; then
    echo "[INFO] Running modal landscape + keyboard test..."
    "${OUT_DIR}/test_modal_landscape_kb"
    RESULT=$?
    echo ""
    if [ ${RESULT} -eq 0 ]; then
        echo "[PASS] Modal landscape+keyboard test validates"
    else
        echo "[FAIL] Modal landscape+keyboard test failed"
    fi
else
    echo "[FAIL] Modal landscape+keyboard test failed to compile"
    RESULT=1
fi

rm -f "${SCRIPT_DIR}/test_modal_landscape_kb.c"
exit ${RESULT}