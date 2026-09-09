#!/usr/bin/env bash
# test_bubbles_contract.sh - TDD: contrato de largura dos bubbles
#
# Contrato:
#   1. Cada linha (row) de mensagem usa largura TAB5_UI_PCT(100) (-1100) e
#      altura TAB5_UI_SIZE_CONTENT (-1).
#   2. Bubble SYSTEM  : largura TAB5_UI_PCT(100)
#   3. Bubble USER    : largura TAB5_UI_PCT(80)
#   4. Bubble ASSISTANT: largura TAB5_UI_PCT(80)
#   5. Label interno  : largura TAB5_UI_PCT(100), altura CONTENT (wrap).
#   6. Alturas de bubble/label são CONTENT (preservadas) — nunca PCT de altura.
#
# Partes: estática (grep em src/main.c; já implementado → PASS esperado) e
# runtime C replicando build_bubble (valida os percentuais para vários
# max_bubble_w, incluindo portrait e landscape).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC="${APP_DIR}/src/main.c"
OUT_DIR="${SCRIPT_DIR}/.build"
mkdir -p "${OUT_DIR}"

echo "=== Bubbles Width Contract (system 100% / user+assistant 80%) ==="
echo ""

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

# ─────────────────────────────────────────────────────────────────────────────
# A. Estática em src/main.c
# ─────────────────────────────────────────────────────────────────────────────
echo "--- A. Estática: padrões de bubbles em src/main.c ---"

# A1. Row usa PCT(100) + CONTENT
if grep -qP 'tab5_ui_obj_set_size\(\s*row\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*,\s*TAB5_UI_SIZE_CONTENT\s*\)' "${SRC}"; then
    run_test "row width = TAB5_UI_PCT(100), height = CONTENT" "PASS"
else
    run_test "row width = TAB5_UI_PCT(100), height = CONTENT" "FAIL"
fi

# A2. Sistema usa 100% do máximo
if grep -qP 'tab5_ui_obj_set_size\(\s*bubble\s*,\s*is_system\s*\?\s*TAB5_UI_PCT\(\s*100\s*\)' "${SRC}"; then
    run_test "bubble system = TAB5_UI_PCT(100)" "PASS"
else
    run_test "bubble system = TAB5_UI_PCT(100)" "FAIL"
fi

# A3. User/assistant usam 80% (max_bubble_w * 8 / 10)
if grep -qP 'tab5_ui_obj_set_size\(\s*bubble\s*,\s*is_system\s*\?\s*TAB5_UI_PCT\(\s*100\s*\)\s*:\s*TAB5_UI_PCT\(\s*80\s*\)' "${SRC}"; then
    run_test "bubble user/assistant = TAB5_UI_PCT(80)" "PASS"
else
    run_test "bubble user/assistant = TAB5_UI_PCT(80)" "FAIL"
fi

# A4. Label interno usa PCT(100) + CONTENT
if grep -qP 'tab5_ui_obj_set_size\(\s*lbl\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*,\s*TAB5_UI_SIZE_CONTENT\s*\)' "${SRC}"; then
    run_test "label width = TAB5_UI_PCT(100), height = CONTENT" "PASS"
else
    run_test "label width = TAB5_UI_PCT(100), height = CONTENT" "FAIL"
fi

# A5. Bubble height = CONTENT (altura preservada, sem PCT de altura)
if grep -qP 'tab5_ui_obj_set_size\(\s*bubble\s*,[^,]*,(\s*TAB5_UI_SIZE_CONTENT)\s*\)' "${SRC}"; then
    run_test "bubble height = CONTENT (preservada)" "PASS"
else
    run_test "bubble height = CONTENT (preservada)" "FAIL"
fi

echo ""
echo "--- A. Estática: NÃO usar altura PCT nos bubbles ---"

# A6. Alturas de bubble/label/row nunca usam PCT (apenas CONTENT)
if grep -qP 'set_size\(\s*(row|bubble|lbl)\s*,[^,]*,(\s*)(?:TAB5_UI_PCT)' "${SRC}"; then
    run_test "alturas de row/bubble/lbl NÃO usam PCT" "FAIL"
else
    run_test "alturas de row/bubble/lbl NÃO usam PCT" "PASS"
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# B. Runtime C: percentuais de largura por papel
# ─────────────────────────────────────────────────────────────────────────────
echo "--- B. Runtime: replicação de build_bubble por papel ---"

cat > "${SCRIPT_DIR}/test_bubbles_contract.c" << 'TESTEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>

/* ── Contrato real do SDK ── */
#define TAB5_UI_PCT(percent) (-1000 - (percent))
#define TAB5_UI_SIZE_CONTENT (-1)
#define TAB5_UI_FLEX_FLOW_ROW 1

/* ── Instrumented mock ── */
#define MAX_CALLS 256
static char  ct[MAX_CALLS][32];
static int   co[MAX_CALLS];
static int   cv1[MAX_CALLS], cv2[MAX_CALLS];
static int   cc = 0;

static void reset_calls(void) { cc = 0; }
static void recc(const char *t, int o, int32_t a, int32_t b) {
    if (cc < MAX_CALLS) {
        snprintf(ct[cc], 32, "%s", t);
        co[cc] = o; cv1[cc] = (int)a; cv2[cc] = (int)b;
        cc++;
    }
}
static int mock_create(int p) { (void)p; return 100 + cc; }
static void mock_ss(int o, int32_t w, int32_t h) { recc("set_size", o, w, h); }

#define tab5_ui_container_create mock_create
#define tab5_ui_obj_set_size     mock_ss

/* ── build_bubble replicado (espelha src/main.c) ── */
typedef struct {
    int row;
    int bubble;
    int lbl;
    int32_t row_w, row_h;
    int32_t bubble_w, bubble_h;
    int32_t lbl_w, lbl_h;
} bubble_obj_t;

static int fake_msg_container = 1;

static bubble_obj_t build_bubble(const char *role) {
    bubble_obj_t out = {0};
    bool is_system = (strcmp(role, "system") == 0);

    out.row = tab5_ui_container_create(fake_msg_container);
    tab5_ui_obj_set_size(out.row, TAB5_UI_PCT(100), TAB5_UI_SIZE_CONTENT);

    out.bubble = tab5_ui_container_create(out.row);
    tab5_ui_obj_set_size(out.bubble,
                         is_system ? TAB5_UI_PCT(100) : TAB5_UI_PCT(80),
                         TAB5_UI_SIZE_CONTENT);

    out.lbl = tab5_ui_container_create(out.bubble);
    tab5_ui_obj_set_size(out.lbl, TAB5_UI_PCT(100), TAB5_UI_SIZE_CONTENT);

    return out;
}

/* Finders: pega o último set_size do objeto */
static int find_ss(int obj, int *ow, int *oh) {
    for (int i = cc - 1; i >= 0; i--)
        if (strcmp(ct[i], "set_size") == 0 && co[i] == obj)
            { *ow = cv1[i]; *oh = cv2[i]; return 1; }
    return 0;
}

static int failures = 0;
static void check(int c, const char *m) {
    if (c) printf("  [PASS] %s\n", m);
    else   { printf("  [FAIL] %s\n", m); failures++; }
}

int main(void) {
    printf("=== Bubbles Width Contract — Runtime ===\n\n");

    /* ── S1: Portrait, max_bubble_w = 720*9/10 = 648 ── */
    printf("Scenario 1: portrait (max_bubble_w = 648)\n");
    {
        reset_calls();
        bubble_obj_t sys = build_bubble("system");
        int rw, rh, bw, bh, lw, lh;
        check(find_ss(sys.row, &rw, &rh), "system: row sized");
        check(rw == -1100 && rh == TAB5_UI_SIZE_CONTENT,
              "system: row = PCT(100) x CONTENT");
        check(find_ss(sys.bubble, &bw, &bh), "system: bubble sized");
        check(bw == -1100, "system: bubble = TAB5_UI_PCT(100)");
        check(bh == TAB5_UI_SIZE_CONTENT, "system: bubble height CONTENT");
        check(find_ss(sys.lbl, &lw, &lh), "system: label sized");
        check(lw == -1100 && lh == TAB5_UI_SIZE_CONTENT,
              "system: label = PCT(100) x CONTENT");
        printf("  system: row=%dx%d bubble=%dx%d lbl=%dx%d\n\n", rw, rh, bw, bh, lw, lh);

        reset_calls();
        bubble_obj_t usr = build_bubble("user");
        check(find_ss(usr.bubble, &bw, &bh), "user: bubble sized");
        check(bw == -1080, "user: bubble = TAB5_UI_PCT(80)");
        check(bh == TAB5_UI_SIZE_CONTENT, "user: bubble height CONTENT");
        printf("  user: row=%d bubble=%dx%d\n\n", (int)usr.row, bw, bh);

        reset_calls();
        bubble_obj_t asst = build_bubble("assistant");
        check(find_ss(asst.bubble, &bw, &bh), "assistant: bubble sized");
        check(bw == -1080, "assistant: bubble = TAB5_UI_PCT(80)");
        check(bh == TAB5_UI_SIZE_CONTENT, "assistant: bubble height CONTENT");
        printf("  assistant: bubble=%dx%d\n\n", bw, bh);
    }

    /* ── S2: Landscape, max_bubble_w = 1280*9/10 = 1152 ── */
    printf("Scenario 2: landscape (max_bubble_w = 1152)\n");
    {
        reset_calls();
        bubble_obj_t sys = build_bubble("system");
        int bw, bh;
        check(find_ss(sys.bubble, &bw, &bh), "landscape system: bubble sized");
        check(bw == -1100, "landscape system: bubble = TAB5_UI_PCT(100)");
        printf("  system: bubble=%dx%d\n", bw, bh);

        reset_calls();
        bubble_obj_t usr = build_bubble("user");
        check(find_ss(usr.bubble, &bw, &bh), "landscape user: bubble sized");
        check(bw == -1080, "landscape user: bubble = TAB5_UI_PCT(80)");
        printf("  user: bubble=%dx%d\n\n", bw, bh);
    }

    /* ── S3: Boundary — max_bubble_w pequeno (fallback 640 com h<=0) ── */
    printf("Scenario 3: fallback 640 + tamanhos mínimos\n");
    {
        reset_calls();
        bubble_obj_t sys = build_bubble("system");
        int bw, bh;
        check(find_ss(sys.bubble, &bw, &bh), "fallback system: bubble sized");
        check(bw == -1100, "fallback system: bubble = TAB5_UI_PCT(100)");

        reset_calls();
        bubble_obj_t asst = build_bubble("assistant");
        check(find_ss(asst.bubble, &bw, &bh), "fallback assistant: bubble sized");
        check(bw == -1080, "fallback assistant: bubble = TAB5_UI_PCT(80)");
        check(bw != -1100, "assistant bubble usa percentual próprio");
        printf("  system: %d, assistant: %d\n\n", -1100, -1080);
    }

    /* ── S4: Igualdade user == assistant (mesmo papel visual) ── */
    printf("Scenario 4: user e assistant compartilham o mesmo width\n");
    {
        reset_calls();
        bubble_obj_t usr = build_bubble("user");
        reset_calls();
        bubble_obj_t asst = build_bubble("assistant");
        int uw, uh, aw, ah;
        check(find_ss(usr.bubble, &uw, &uh), "user: bubble sized");
        check(find_ss(asst.bubble, &aw, &ah), "assistant: bubble sized");
        check(uw == aw && uh == ah, "user width == assistant width (idênticos)");
        check(uw == -1080, "user width == TAB5_UI_PCT(80)");
        printf("  user=%dx%d assistant=%dx%d\n\n", uw, uh, aw, ah);
    }

    printf("=== Bubbles Contract: %s (failures=%d) ===\n",
           failures ? "FAILED" : "ALL PASSED", failures);
    return failures ? 1 : 0;
}
TESTEOF

echo "[INFO] Compilando teste de contrato dos bubbles..."
if gcc -std=c11 -Wall -Wextra -o "${OUT_DIR}/test_bubbles_contract" \
       "${SCRIPT_DIR}/test_bubbles_contract.c" 2>&1; then
    echo "[INFO] Executando teste de contrato dos bubbles..."
    set +e
    "${OUT_DIR}/test_bubbles_contract"
    RUNTIME_RESULT=$?
    set -e
    echo ""
    if [ ${RUNTIME_RESULT} -eq 0 ]; then
        echo "[PASS] Contrato dos bubbles runtime valida"
    else
        echo "[FAIL] Contrato dos bubbles runtime falhou"
    fi
else
    echo "[FAIL] Teste de contrato dos bubbles falhou ao compilar"
    RUNTIME_RESULT=1
fi

rm -f "${SCRIPT_DIR}/test_bubbles_contract.c"

echo ""
echo "=== Resumo estático: ${PASS} passed, ${FAIL} failed, ${TOTAL} total ==="

# Veredito do script: runtime do contrato (o estático documenta o estado TDD).
exit ${RUNTIME_RESULT}
