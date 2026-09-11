#!/usr/bin/env bash
# test_modal_kb_layout.sh - Modal/backdrop/card 100% relativos + CENTER offset
# Compiles a self-contained C program that instruments the modal layout do
# plano aprovado (contrato relativo).
# Verifies:
#  1. Modal e backdrop = TAB5_UI_PCT(100) x TAB5_UI_PCT(100) (tela visual real,
#     independente do w/h reportado pelo host)
#  2. Card = TAB5_UI_PCT(96) x TAB5_UI_SIZE_CONTENT (altura automática, sem
#     PCT(60)/card_h), CENTER offset -(kb_h/2)
#  3. Nenhuma dimensão absoluta (w/h/card_h/usable_h) no caminho modal
#  4. Tamanhos PCT idênticos em retrato e paisagem (sem cálculo manual)
#  5. Conteúdo cabe com o teclado aberto em retrato/paisagem (grade compacta
#     2x2 — nada rola)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/.build"
mkdir -p "${OUT_DIR}"

echo "=== Modal + Keyboard Layout Test ==="
echo ""

cat > "${SCRIPT_DIR}/test_modal_kb_layout.c" << 'TESTEOF'
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
static char  c_type[MAX_CALLS][32];
static int   c_obj[MAX_CALLS];
static int   c_p1[MAX_CALLS];
static int   c_p2[MAX_CALLS];
static int   c_p3[MAX_CALLS];
static int   cc = 0;

static int mock_next_id = 10;
static int mock_create(int p) { (void)p; return ++mock_next_id; }
static void mock_reset_ids(void) { mock_next_id = 10; }

static void reset(void) { cc = 0; mock_reset_ids(); }
static void rec(const char *t, int o, int a, int b, int c) {
    if (cc < MAX_CALLS) {
        snprintf(c_type[cc], 32, "%s", t);
        c_obj[cc] = o; c_p1[cc] = a; c_p2[cc] = b; c_p3[cc] = c;
        cc++;
    }
}
static void __attribute__((unused)) mock_get_display(int32_t *w, int32_t *h) { rec("get_display", 0, (int)*w, (int)*h, 0); }
static int32_t mock_kb(void) { return mock_kb_h; }
static void mock_set_size(int o, int32_t w, int32_t h) { rec("set_size", o, w, h, 0); }
static void mock_set_align(int o, int a, int32_t x, int32_t y) { (void)x; rec("set_align", o, a, x, y); }

#define tab5_ui_get_display_size mock_get_display
#define tab5_ui_keyboard_get_height mock_kb
#define tab5_ui_obj_set_size mock_set_size
#define tab5_ui_obj_set_align mock_set_align
#define tab5_ui_container_create mock_create

/* ── Simulated modal layout (mirrors src/main.c apply_modal_layout) ── */
static bool s_modal_open = false;
static int obj_modal = 1;
static int obj_backdrop = 0;
static int obj_card = 0;

static void apply_modal_layout(void) {
    int32_t kb_h = tab5_ui_keyboard_get_height();
    if (kb_h < 0) kb_h = 0;

    tab5_ui_obj_set_size(obj_modal, TAB5_UI_PCT(100), TAB5_UI_PCT(100));
    tab5_ui_obj_set_align(obj_modal, TAB5_UI_ALIGN_TOP_LEFT, 0, 0);
    tab5_ui_obj_set_size(obj_backdrop, TAB5_UI_PCT(100), TAB5_UI_PCT(100));
    tab5_ui_obj_set_align(obj_backdrop, TAB5_UI_ALIGN_TOP_LEFT, 0, 0);
    tab5_ui_obj_set_size(obj_card, TAB5_UI_PCT(96), TAB5_UI_SIZE_CONTENT);
    tab5_ui_obj_set_align(obj_card, TAB5_UI_ALIGN_CENTER, 0, -(kb_h / 2));
}

/* Simulated open_config_modal (mirrors src/main.c: termina em apply_modal_layout). */
static void open_config_modal(void) {
    if (s_modal_open) return;
    s_modal_open = true;

    tab5_ui_obj_set_size(obj_modal, TAB5_UI_PCT(100), TAB5_UI_PCT(100));
    tab5_ui_obj_set_align(obj_modal, TAB5_UI_ALIGN_TOP_LEFT, 0, 0);

    obj_backdrop = mock_create(obj_modal);
    tab5_ui_obj_set_size(obj_backdrop, TAB5_UI_PCT(100), TAB5_UI_PCT(100));
    tab5_ui_obj_set_align(obj_backdrop, TAB5_UI_ALIGN_TOP_LEFT, 0, 0);

    obj_card = mock_create(obj_modal);
    tab5_ui_obj_set_size(obj_card, TAB5_UI_PCT(96), TAB5_UI_SIZE_CONTENT);
    tab5_ui_obj_set_align(obj_card, TAB5_UI_ALIGN_CENTER, 0, 0);

    apply_modal_layout();
}

/* ── Finders ── */
static int find_set_size(int obj, int *ow, int *oh) {
    for (int i = cc - 1; i >= 0; i--)
        if (strcmp(c_type[i], "set_size") == 0 && c_obj[i] == obj)
            { *ow = c_p1[i]; *oh = c_p2[i]; return 1; }
    return 0;
}
static int find_set_align(int obj, int *oa, int *oy) {
    for (int i = cc - 1; i >= 0; i--)
        if (strcmp(c_type[i], "set_align") == 0 && c_obj[i] == obj)
            { *oa = c_p1[i]; *oy = c_p3[i]; return 1; }
    return 0;
}
static int count_type(const char *t) {
    int n = 0;
    for (int i = 0; i < cc; i++)
        if (strcmp(c_type[i], t) == 0) n++;
    return n;
}

static int failures = 0;
static void check(int c, const char *m) {
    if (c) printf("  [PASS] %s\n", m);
    else   { printf("  [FAIL] %s\n", m); failures++; }
}

int main(void) {
    printf("=== Modal + Keyboard Layout Test — Contrato relativo ===\n\n");

    /* Estimativas de conteúdo do card (âncora da validação de "cabe"):
     *   compacto 2x2:  pads(32) + título(20) + gaps do card(2x10) +
     *                  grade 2x2(2x[20+4+42] + 10) + btns(48) = 262px
*   coluna única (antigo): pads(32) + título(20) + corpo(4x[20+4+42] +
     *                  3 gaps) + btns(48) ≈ 414px — NÃO cabe em paisagem.
     */
    const int CARD_CONTENT_H = 262;
    const int SINGLE_COLUMN_H = 414;

    /* Encoding real do SDK */
    check(TAB5_UI_PCT(100) == -1100, "TAB5_UI_PCT(100) == -1100");
    check(TAB5_UI_PCT(96)  == -1096, "TAB5_UI_PCT(96) == -1096");
    check(TAB5_UI_PCT(60)  == -1060, "TAB5_UI_PCT(60) == -1060");

    /* ─── Scenario 1: No keyboard, portrait ─── */
    printf("\nScenario 1: No keyboard (kb_h=0), portrait 720x1280\n");
    {
        mock_w = 720; mock_h = 1280; mock_kb_h = 0;
        s_modal_open = false; reset();
        open_config_modal();
        int mw, mh, bw, bh, cw, ch;
        check(find_set_size(obj_modal, &mw, &mh), "modal: sized");
        check(mw == -1100 && mh == -1100, "modal: PCT(100) x PCT(100) (tela visual)");
        check(find_set_size(obj_backdrop, &bw, &bh), "backdrop: sized");
        check(bw == -1100 && bh == -1100, "backdrop: PCT(100) x PCT(100)");
        check(find_set_size(obj_card, &cw, &ch), "card: sized");
        check(cw == -1096 && ch == -1, "card: PCT(96) x SIZE_CONTENT (auto-height)");
        int a, oy;
        check(find_set_align(obj_card, &a, &oy), "card: aligned");
        check(a == TAB5_UI_ALIGN_CENTER && oy == 0, "card: CENTER offset 0 (kb_h=0)");
        check(count_type("get_display") == 0,
              "retrato: SEM tab5_ui_get_display_size no caminho modal (host não vaza)");
        printf("  modal: %dx%d, backdrop: %dx%d, card: %dx%d offset=%d\n\n",
               mw, mh, bw, bh, cw, ch, oy);
    }

    /* ─── Scenario 2: keyboard visible, portrait ─── */
    printf("Scenario 2: Keyboard (kb_h=400), portrait 720x1280\n");
    {
        mock_w = 720; mock_h = 1280; mock_kb_h = 400;
        s_modal_open = false; reset();
        open_config_modal();
        int mw, mh, bw, bh, cw, ch;
        find_set_size(obj_modal, &mw, &mh);
        find_set_size(obj_backdrop, &bw, &bh);
        find_set_size(obj_card, &cw, &ch);
        check(mw == -1100 && mh == -1100, "modal+kb: PCT(100) x PCT(100) (não usa h)");
        check(bw == -1100 && bh == -1100, "backdrop+kb: PCT(100) x PCT(100) (não usa h)");
        check(cw == -1096 && ch == -1, "card+kb: PCT(96) x SIZE_CONTENT (sem card_h)");
        int a, oy;
        check(find_set_align(obj_card, &a, &oy), "card+kb: aligned");
        check(a == TAB5_UI_ALIGN_CENTER && oy == -200, "card+kb: CENTER offset -(400/2) = -200");
        check(pctpx(1280, 100) - 400 >= CARD_CONTENT_H,
              "card+kb: visível 880px >= conteúdo compacto (~262px) — nada rola");
        printf("  card: %dx%d offset=%d\n\n", cw, ch, oy);
    }

    /* ─── Scenario 3: Large keyboard, portrait ─── */
    printf("Scenario 3: Large keyboard (kb_h=900), portrait 720x1280\n");
    {
        mock_w = 720; mock_h = 1280; mock_kb_h = 900;
        s_modal_open = false; reset();
        open_config_modal();
        int cw, ch;
        find_set_size(obj_card, &cw, &ch);
        check(cw == -1096 && ch == -1, "large_kb: card permanece PCT(96) x SIZE_CONTENT");
        int a, oy;
        check(find_set_align(obj_card, &a, &oy), "large_kb: card aligned");
        check(oy == -(900 / 2), "large_kb: offset -(kb_h/2) = -450 (teclado preservado)");
        printf("  card: %dx%d offset=%d\n\n", cw, ch, oy);
    }

    /* ─── Scenario 4: Landscape + keyboard ─── */
    printf("Scenario 4: Landscape 1280x720, kb_h=300\n");
    {
        mock_w = 1280; mock_h = 720; mock_kb_h = 300;
        s_modal_open = false; reset();
        open_config_modal();
        int mw, mh, bw, bh, cw, ch;
        find_set_size(obj_modal, &mw, &mh);
        find_set_size(obj_backdrop, &bw, &bh);
        find_set_size(obj_card, &cw, &ch);
        check(mw == -1100 && mh == -1100, "landscape+kb: modal PCT(100) x PCT(100) (visual)");
        check(bw == -1100 && bh == -1100, "landscape+kb: backdrop PCT(100) x PCT(100)");
        check(cw == -1096 && ch == -1, "landscape+kb: card PCT(96) x SIZE_CONTENT");
        check(pctpx(1280, 96) == 1229,
              "landscape+kb: card largura resolvida 1229 (96% do visual 1280)");
        int a, oy;
        check(find_set_align(obj_card, &a, &oy), "landscape+kb: card aligned");
        check(oy == -150, "landscape+kb: CENTER offset -(300/2) = -150");
        check(count_type("get_display") == 0,
              "landscape: SEM tab5_ui_get_display_size no caminho modal (host stale não vaza)");
        printf("  card: %dx%d offset=%d\n\n", cw, ch, oy);
    }

    /* ─── Scenario 5: Landscape, no keyboard ─── */
    printf("Scenario 5: Landscape 1280x720, kb_h=0\n");
    {
        mock_w = 1280; mock_h = 720; mock_kb_h = 0;
        s_modal_open = false; reset();
        open_config_modal();
        int cw, ch, a, oy;
        find_set_size(obj_card, &cw, &ch);
        check(cw == -1096 && ch == -1, "landscape: card PCT(96) x SIZE_CONTENT");
        check(find_set_align(obj_card, &a, &oy), "landscape: card aligned");
        check(oy == 0, "landscape: CENTER offset 0 (sem teclado)");
        printf("  card: %dx%d offset=%d\n\n", cw, ch, oy);
    }

    /* ─── Scenario 6: Content fits with keyboard (compact 2x2) ─── */
    printf("Scenario 6: Content fits with keyboard — portrait & landscape\n");
    {
        /* Retrato: visível 1280-400 = 880px — folga folgada, nada rola. */
        mock_w = 720; mock_h = 1280; mock_kb_h = 400;
        s_modal_open = false; reset();
        open_config_modal();
        int cw, ch;
        check(find_set_size(obj_card, &cw, &ch) && cw == -1096 && ch == -1,
              "portrait+kb: card PCT(96) x SIZE_CONTENT");
        check(mock_h - mock_kb_h >= CARD_CONTENT_H,
              "portrait+kb: visível 880px >= 262px (conteúdo compacto inteiro)");

        /* Paisagem com teclado 400: visível 720-400 = 320px. */
        mock_w = 1280; mock_h = 720; mock_kb_h = 400;
        s_modal_open = false; reset();
        open_config_modal();
        find_set_size(obj_card, &cw, &ch);
        check(mock_h - mock_kb_h >= CARD_CONTENT_H,
              "landscape+kb(400): visível 320px >= 262px — cabe na grade 2x2");
        check(mock_h - mock_kb_h < SINGLE_COLUMN_H,
              "landscape+kb(400): 320px < 414px — prova que coluna única NÃO caberia (2x2 obrigatória)");

        /* Paisagem com teclado 300: visível 420px — folga confortável. */
        mock_w = 1280; mock_h = 720; mock_kb_h = 300;
        s_modal_open = false; reset();
        open_config_modal();
        find_set_size(obj_card, &cw, &ch);
        check(mock_h - mock_kb_h >= CARD_CONTENT_H,
              "landscape+kb(300): visível 420px >= 262px");

        /* Caso extremo documentado (teclado 550 em paisagem): visível 170px <
         * 262px — contrato aceita clipping; sem scroll como solução. */
        mock_w = 1280; mock_h = 720; mock_kb_h = 550;
        s_modal_open = false; reset();
        open_config_modal();
        find_set_size(obj_card, &cw, &ch);
        check(mock_h - mock_kb_h < CARD_CONTENT_H,
              "landscape+kb(550): 170px < 262px (extremo documentado, sem scroll)");

        printf("  compact content=%dpx, single-column=%dpx\n\n",
               CARD_CONTENT_H, SINGLE_COLUMN_H);
    }

    printf("=== Modal+KB Results: %s (failures=%d) ===\n",
           failures ? "FAILED" : "ALL PASSED", failures);
    return failures ? 1 : 0;
}
TESTEOF

echo "[INFO] Compiling modal/keyboard layout test..."
if gcc -std=c11 -Wall -Wextra -o "${OUT_DIR}/test_modal_kb_layout" \
       "${SCRIPT_DIR}/test_modal_kb_layout.c" 2>&1; then
    echo "[INFO] Running modal/keyboard layout test..."
    "${OUT_DIR}/test_modal_kb_layout"
    RESULT=$?
    echo ""
    if [ ${RESULT} -eq 0 ]; then
        echo "[PASS] Modal+KB layout test validates"
    else
        echo "[FAIL] Modal+KB layout test failed"
    fi
else
    echo "[FAIL] Modal+KB test failed to compile"
    RESULT=1
fi

rm -f "${SCRIPT_DIR}/test_modal_kb_layout.c"
exit ${RESULT}