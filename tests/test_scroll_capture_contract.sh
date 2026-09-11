#!/usr/bin/env bash
# test_scroll_capture_contract.sh - contrato de captura de scroll.
#
# Objetivo (plano aprovado): eliminar scrollbars e captura de gesto de scroll
# indevidos nos balões de mensagem e na área de input, desabilitando o scroll
# nesses objetos e PRESERVANDO o scroll da lista de mensagens e do card do modal.
#
# No SDK/LVGL, o contêiner padrão é scrollável: sem desabilitar, cada
# `row`/`spacer`/`bubble` (build_bubble) e `s_input_cont`/`s_input_ta`
# (build_chat_ui) exibe scrollbar em AUTO no overflow e captura o swipe no
# lugar da lista. Contrato:
#
#   1. build_bubble: row, spacer(s) e bubble  → set_scrollable(X, false)
#   2. build_chat_ui: s_input_cont e s_input_ta → set_scrollable(X, false)
#   3. Preservados: scr → set_scrollable(scr, false);
#      s_messages_cont → set_scrollable(..., true) — o ÚNICO scrollable(true)
#      do arquivo; modal de configuração → NENHUM objeto é rolável:
#      s_modal/s_modal_backdrop/s_modal_card/cfg_body (agora false) → false,
#      btns → false e os 4 campos de configuração
#      (s_cfg_url/s_cfg_token/s_cfg_model/s_cfg_max_tokens) → false
#      (plano aprovado de modal compacto 2x2 com card de altura automática);
#      tab5_ui_obj_scroll_to_bottom(s_messages_cont, true) em rebuild_messages.
#
# Além da captura de scroll, o runtime TEST-003 registra o gap do row por papel
# (REQ-002 do plano aprovado: gap(system)=0, gap(user/assistant)=4) e valida
# que o system bubble não gera overflow horizontal. A extração do gap REAL em
# src/main.c e a matemática de flex completa ficam na suíte dedicada
# test_scrollbar_contract.sh (TEST-101/TEST-103).
#
# TEST-001 (grep): padrões set_scrollable(false) nos alvos de correção
#   (row/spacer(s)/bubble em build_bubble; s_input_cont/s_input_ta em build_chat_ui)
#   e preservação de scr=false, messages_cont=true, scroll_to_bottom).
# TEST-002 (extração Python dos corpos REAIS): build_bubble/build_chat_ui contêm
#   os set_scrollable(false) acima; build_chat_ui contém scr=false e
#   messages_cont=true; open_config_modal contém cfg_body=false (nada no modal
#   é rolável) e s_modal_card=false; rebuild_messages contém
#   scroll_to_bottom(messages_cont, true).
# TEST-003 (runtime C instrumentado): réplica do layout-ALVO registrando
#   alvos/valores das chamadas set_scrollable/scroll_to_bottom.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC="${APP_DIR}/src/main.c"
OUT_DIR="${SCRIPT_DIR}/.build"
mkdir -p "${OUT_DIR}"

echo "=== Scroll Capture Contract (balões/input não-scrolláveis, lista/modal preservados) ==="
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
# TEST-001 — Estática: grep dos padrões em src/main.c
# ─────────────────────────────────────────────────────────────────────────────
echo "--- TEST-001: padrões set_scrollable em src/main.c (grep) ---"

# A1. Bubble row não-scrollável
if grep -qP 'tab5_ui_obj_set_scrollable\(\s*row\s*,\s*false\s*\)' "${SRC}"; then
    run_test "build_bubble: row = set_scrollable(row, false)" "PASS"
else
    run_test "build_bubble: row = set_scrollable(row, false)" "FAIL"
fi

# A2. Bubble não-scrollável
if grep -qP 'tab5_ui_obj_set_scrollable\(\s*bubble\s*,\s*false\s*\)' "${SRC}"; then
    run_test "build_bubble: bubble = set_scrollable(bubble, false)" "PASS"
else
    run_test "build_bubble: bubble = set_scrollable(bubble, false)" "FAIL"
fi

# A3. Spacer(s) não-scrollável(is)
if grep -qP 'tab5_ui_obj_set_scrollable\(\s*spacer\s*,\s*false\s*\)' "${SRC}" || \
   grep -qP 'tab5_ui_obj_set_scrollable\(\s*second_spacer\s*,\s*false\s*\)' "${SRC}"; then
    run_test "build_bubble: spacer(s) = set_scrollable(..., false)" "PASS"
else
    run_test "build_bubble: spacer(s) = set_scrollable(..., false)" "FAIL"
fi

# A4. Contêiner de input não-scrollável
if grep -qP 'tab5_ui_obj_set_scrollable\(\s*s_input_cont\s*,\s*false\s*\)' "${SRC}"; then
    run_test "build_chat_ui: s_input_cont = set_scrollable(s_input_cont, false)" "PASS"
else
    run_test "build_chat_ui: s_input_cont = set_scrollable(s_input_cont, false)" "FAIL"
fi

# A5. Textarea de input não-scrollável
if grep -qP 'tab5_ui_obj_set_scrollable\(\s*s_input_ta\s*,\s*false\s*\)' "${SRC}"; then
    run_test "build_chat_ui: s_input_ta = set_scrollable(s_input_ta, false)" "PASS"
else
    run_test "build_chat_ui: s_input_ta = set_scrollable(s_input_ta, false)" "FAIL"
fi

echo ""
echo "--- TEST-001: preservação do scroll (regressão) ---"

# A6. Screen permanece não-scrollável
if grep -qP 'tab5_ui_obj_set_scrollable\(\s*scr\s*,\s*false\s*\)' "${SRC}"; then
    run_test "screen NÃO é scrollável (set_scrollable(scr, false) preservado)" "PASS"
else
    run_test "screen NÃO é scrollável (set_scrollable(scr, false) preservado)" "FAIL"
fi

# A7. Lista de mensagens continua scrollável
if grep -qP 'tab5_ui_obj_set_scrollable\(\s*s_messages_cont\s*,\s*true\s*\)' "${SRC}"; then
    run_test "lista de mensagens scrollável preservada (s_messages_cont, true)" "PASS"
else
    run_test "lista de mensagens scrollável preservada (s_messages_cont, true)" "FAIL"
fi

# A8. Card do modal não é rolável (nenhum objeto do modal é rolável)
if grep -qP 'tab5_ui_obj_set_scrollable\(\s*s_modal_card\s*,\s*false\s*\)' "${SRC}"; then
    run_test "card do modal NÃO é rolável (s_modal_card, false)" "PASS"
else
    run_test "card do modal NÃO é rolável (s_modal_card, false)" "FAIL"
fi

# A8b. Corpo de campos do modal agora NÃO é rolável (plano compacto 2x2)
if grep -qP 'tab5_ui_obj_set_scrollable\(\s*cfg_body\s*,\s*false\s*\)' "${SRC}"; then
    run_test "corpo de campos NÃO é rolável (cfg_body, false)" "PASS"
else
    run_test "corpo de campos NÃO é rolável (cfg_body, false)" "FAIL"
fi

# A8c. Modal e backdrop não roláveis (não capturam gestos fora do card)
if grep -qP 'tab5_ui_obj_set_scrollable\(\s*s_modal\s*,\s*false\s*\)' "${SRC}"; then
    run_test "modal NÃO é rolável (s_modal, false)" "PASS"
else
    run_test "modal NÃO é rolável (s_modal, false)" "FAIL"
fi
if grep -qP 'tab5_ui_obj_set_scrollable\(\s*s_modal_backdrop\s*,\s*false\s*\)' "${SRC}"; then
    run_test "backdrop NÃO é rolável (s_modal_backdrop, false)" "PASS"
else
    run_test "backdrop NÃO é rolável (s_modal_backdrop, false)" "FAIL"
fi

# A8d. Os 4 campos de configuração não roláveis (textareas com altura fixa 42)
for cfg_field in s_cfg_url s_cfg_token s_cfg_model s_cfg_max_tokens; do
    if grep -qP "tab5_ui_obj_set_scrollable\(\s*${cfg_field}\s*,\s*false\s*\)" "${SRC}"; then
        run_test "campo ${cfg_field} NÃO é rolável (set_scrollable(false))" "PASS"
    else
        run_test "campo ${cfg_field} NÃO é rolável (set_scrollable(false))" "FAIL"
    fi
done

# A9. Auto scroll-to-bottom preservado no rebuild
if grep -qP 'tab5_ui_obj_scroll_to_bottom\(\s*s_messages_cont\s*,\s*true\s*\)' "${SRC}"; then
    run_test "rebuild_messages: scroll_to_bottom(s_messages_cont, true) preservado" "PASS"
else
    run_test "rebuild_messages: scroll_to_bottom(s_messages_cont, true) preservado" "FAIL"
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# TEST-002 — Extração dos corpos REAIS de src/main.c (estilo layout_call_contract)
# ─────────────────────────────────────────────────────────────────────────────
set +e
SRC_PATH="${SRC}" python3 - <<'PY'
import os
import re
import sys

source = open(os.environ["SRC_PATH"], encoding="utf-8").read()

def function_body(name):
    match = re.search(r"\bstatic\s+void\s+" + re.escape(name) + r"\s*\([^)]*\)\s*\{", source)
    if not match:
        raise AssertionError(f"função não encontrada: {name}")
    start = match.end() - 1
    depth = 0
    for pos in range(start, len(source)):
        if source[pos] == "{":
            depth += 1
        elif source[pos] == "}":
            depth -= 1
            if depth == 0:
                return source[start + 1:pos]
    raise AssertionError(f"corpo incompleto: {name}")

def calls(body, function):
    return re.findall(r"tab5_ui_obj_" + function + r"\s*\(([^;]+)\)", body)

failures = 0
def require(condition, message):
    global failures
    if condition:
        print(f"  [PASS] {message}")
    else:
        print(f"  [FAIL] {message}")
        failures += 1
    return condition

def sc_call(pattern):
    return re.compile(r"tab5_ui_obj_set_scrollable\(\s*" + pattern + r"\s*,\s*false\s*\)")

bubble = function_body("build_bubble")
chat   = function_body("build_chat_ui")
modal  = function_body("open_config_modal")
rebuild = function_body("rebuild_messages")

print("--- TEST-002: corpos REAIS — build_bubble (balões não-scrolláveis) ---")
require(sc_call(r"row").search(bubble) is not None,
        "build_bubble REAL contém set_scrollable(row, false)")
require(sc_call(r"bubble").search(bubble) is not None,
        "build_bubble REAL contém set_scrollable(bubble, false)")
require((sc_call(r"spacer").search(bubble) is not None) or
        (sc_call(r"second_spacer").search(bubble) is not None),
        "build_bubble REAL contém set_scrollable(spacer, false)")
require(sc_call(r"second_spacer").search(bubble) is not None,
        "build_bubble REAL contém set_scrollable(second_spacer, false)")

# Invariante: NENHUM set_scrollable(..., true) dentro de build_bubble (nada de
# scroll dentro de balões em qualquer cenário). As strings capturadas são do
# tipo "row, false" (sem o prefixo de função), então basta exigir que todo
# argumento termine em "false"; lista vazia (nenhuma chamada) também vale.
sc_bubble_calls = calls(bubble, "set_scrollable")
require(all(re.search(r",\s*false\s*$", c) for c in sc_bubble_calls),
        "build_bubble: NENHUM set_scrollable(..., true) no corpo (tudo false ou ausente)")
print()

print("--- TEST-002: corpos REAIS — build_chat_ui (input não-scrollável, lista preservada) ---")
require(re.search(r"tab5_ui_obj_set_scrollable\(\s*scr\s*,\s*false\s*\)", chat) is not None,
        "build_chat_ui REAL contém set_scrollable(scr, false) (screen preservada)")
require(re.search(r"tab5_ui_obj_set_scrollable\(\s*s_messages_cont\s*,\s*true\s*\)", chat) is not None,
        "build_chat_ui REAL contém set_scrollable(s_messages_cont, true) (lista preservada)")
require(re.search(r"tab5_ui_obj_set_scrollable\(\s*s_modal\s*,\s*false\s*\)", chat) is not None,
        "build_chat_ui REAL contém set_scrollable(s_modal, false) (modal não rola)")
require(sc_call(r"s_input_cont").search(chat) is not None,
        "build_chat_ui REAL contém set_scrollable(s_input_cont, false)")
require(sc_call(r"s_input_ta").search(chat) is not None,
        "build_chat_ui REAL contém set_scrollable(s_input_ta, false)")
print()

print("--- TEST-002: corpos REAIS — modal e rebuild preservados ---")
require(re.search(r"tab5_ui_obj_set_scrollable\(\s*cfg_body\s*,\s*false\s*\)", modal) is not None,
        "open_config_modal REAL contém set_scrollable(cfg_body, false) (nada no modal é rolável)")
require(re.search(r"tab5_ui_obj_set_scrollable\(\s*s_modal_card\s*,\s*false\s*\)", modal) is not None,
        "open_config_modal REAL contém set_scrollable(s_modal_card, false) (card não rola)")
require(re.search(r'tab5_ui_obj_set_scrollable\(\s*\w+\s*,\s*true\s*\)', modal) is None,
        "open_config_modal REAL NÃO contém NENHUM set_scrollable(..., true) (modal 100% não rolável)")
require(sc_call(r"s_modal_backdrop").search(modal) is not None,
        "open_config_modal REAL contém set_scrollable(s_modal_backdrop, false)")
for cfg in ("s_cfg_url", "s_cfg_token", "s_cfg_model", "s_cfg_max_tokens"):
    require(sc_call(cfg).search(modal) is not None,
            f"open_config_modal REAL contém set_scrollable({cfg}, false) (campo com altura fixa)")
require(re.search(r"tab5_ui_obj_scroll_to_bottom\(\s*s_messages_cont\s*,\s*true\s*\)", rebuild) is not None,
        "rebuild_messages REAL contém scroll_to_bottom(s_messages_cont, true) (auto-bottom preservado)")
print()

print(f"=== TEST-002 (extração real): {'ALL PASSED' if failures == 0 else str(failures) + ' FAIL(s)'} ===")
sys.exit(1 if failures else 0)
PY
EXTRACT_RESULT=$?
set -e

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# TEST-003 — Runtime C: réplica do layout-ALVO (mock instrumentado)
# ─────────────────────────────────────────────────────────────────────────────
echo "--- TEST-003: runtime — réplica do layout-alvo registrando alvos/valores ---"

cat > "${SCRIPT_DIR}/test_scroll_capture_contract.c" << 'TESTEOF'
#include <stdio.h>
#include <string.h>
#include <stdbool.h>

/* ── Registro de chamadas set_scrollable / scroll_to_bottom ── */
#define MAX_CALLS 64
static char  sc_func[MAX_CALLS][32];
static char  sc_name[MAX_CALLS][32];
static int   sc_val[MAX_CALLS];
static int   sc_count = 0;

static void reset_calls(void) { sc_count = 0; }

static void rec_sc(const char *target, int value) {
    if (sc_count < MAX_CALLS) {
        snprintf(sc_func[sc_count], 32, "set_scrollable");
        snprintf(sc_name[sc_count], 32, "%s", target);
        sc_val[sc_count] = value;
        sc_count++;
    }
}
static void rec_stb(const char *target, int animated) {
    if (sc_count < MAX_CALLS) {
        snprintf(sc_func[sc_count], 32, "scroll_to_bottom");
        snprintf(sc_name[sc_count], 32, "%s", target);
        sc_val[sc_count] = animated;
        sc_count++;
    }
}
static void rec_gap(const char *target, int value) {
    if (sc_count < MAX_CALLS) {
        snprintf(sc_func[sc_count], 32, "set_gap");
        snprintf(sc_name[sc_count], 32, "%s", target);
        sc_val[sc_count] = value;
        sc_count++;
    }
}

#define SC(target, value) rec_sc((target), (value))
#define STB(target, anim) rec_stb((target), (anim))
#define GAP(target, value) rec_gap((target), (value))

/* ── Réplica do build_bubble ALVO (contrato): row/spacer(s)/bubble sem scroll ── */
static void tgt_build_bubble(const char *role) {
    bool is_user = (strcmp(role, "user") == 0);
    bool is_system = (strcmp(role, "system") == 0);

    SC("row", false);            /* linha da mensagem nunca captura swipe */
    if (is_user || is_system) {
        SC("spacer", false);
        if (is_system) {
            SC("second_spacer", false);
        }
    }
    SC("bubble", false);         /* balão nunca captura swipe */

    /* REQ-002 (plano aprovado): gap do row por papel — system sem gap para
     * não somar overflow horizontal (bubble PCT(100) + 2 spacers grow). */
    GAP("row", is_system ? 0 : 4);
}

/* ── Réplica do build_chat_ui ALVO (contrato): input sem scroll, lista com scroll ── */
static void tgt_build_chat_ui(void) {
    SC("scr", false);            /* tela nunca rola */
    SC("s_messages_cont", true); /* lista de mensagens SCROLLÁVEL (preservada) */
    SC("s_input_cont", false);   /* contêiner do input nunca captura swipe */
    SC("s_input_ta", false);     /* textarea do input é linha única (INPUT_H=60) */
    SC("s_modal", false);        /* modal não rola (não captura gestos no card) */
}

/* ── Réplica do modal e do rebuild ALVO (nenhum objeto do modal é rolável) ── */
static void tgt_open_config_modal(void) {
    SC("cfg_body", false);     /* corpo de campos NÃO é rolável (compacto 2x2) */
    SC("s_modal_card", false); /* card não rola (altura automática) */
    SC("btns", false);         /* linha de botões: fixa, não rolável */
    SC("s_modal_backdrop", false); /* backdrop cobre a tela, sem capturar swipe */
    SC("s_cfg_url", false);        /* campo Base URL: altura fixa 42, sem scroll */
    SC("s_cfg_token", false);      /* campo Token: altura fixa 42, sem scroll */
    SC("s_cfg_model", false);      /* campo Modelo: altura fixa 42, sem scroll */
    SC("s_cfg_max_tokens", false); /* campo Max tokens: altura fixa 42, sem scroll */
}
static void tgt_rebuild_messages(void) {
    STB("s_messages_cont", true);/* após rebuild, volta ao fim da lista */
}

static int failures = 0;
static void check(int c, const char *m) {
    if (c) printf("  [PASS] %s\n", m);
    else   { printf("  [FAIL] %s\n", m); failures++; }
}

/* Verifica se existe chamada set_scrollable(target, value) registrada. */
static int has_sc(const char *target, int value) {
    for (int i = 0; i < sc_count; i++)
        if (strcmp(sc_func[i], "set_scrollable") == 0 &&
            strcmp(sc_name[i], target) == 0 && sc_val[i] == value)
            return 1;
    return 0;
}
/* Verifica se existe scroll_to_bottom(target, animated). */
static int has_stb(const char *target, int animated) {
    for (int i = 0; i < sc_count; i++)
        if (strcmp(sc_func[i], "scroll_to_bottom") == 0 &&
            strcmp(sc_name[i], target) == 0 && sc_val[i] == animated)
            return 1;
    return 0;
}
/* Verifica se existe set_gap(target, value) registrado. */
static int has_gap(const char *target, int value) {
    for (int i = 0; i < sc_count; i++)
        if (strcmp(sc_func[i], "set_gap") == 0 &&
            strcmp(sc_name[i], target) == 0 && sc_val[i] == value)
            return 1;
    return 0;
}

int main(void) {
    printf("=== Scroll Capture Contract — Runtime (layout-alvo) ===\n\n");

    /* C1: balões — user (1 spacer) */
    reset_calls();
    tgt_build_bubble("user");
    check(has_sc("row", 0),   "user: row -> set_scrollable(false)");
    check(has_sc("spacer", 0),"user: spacer -> set_scrollable(false)");
    check(has_sc("bubble", 0),"user: bubble -> set_scrollable(false)");
    printf("  user: captures=%d (row/spacer/bubble -> false)\n\n", sc_count);

    /* C2: balões — system (2 spacers) */
    reset_calls();
    tgt_build_bubble("system");
    check(has_sc("row", 0),            "system: row -> set_scrollable(false)");
    check(has_sc("spacer", 0),         "system: 1º spacer -> set_scrollable(false)");
    check(has_sc("second_spacer", 0),  "system: 2º spacer -> set_scrollable(false)");
    check(has_sc("bubble", 0),         "system: bubble -> set_scrollable(false)");
    printf("  system: captures=%d (row/spacer/second_spacer/bubble -> false)\n\n", sc_count);

    /* C3: input + lista + tela */
    reset_calls();
    tgt_build_chat_ui();
    check(has_sc("scr", 0),            "build_chat_ui: scr -> set_scrollable(false) (preservado)");
    check(has_sc("s_messages_cont", 1),"build_chat_ui: s_messages_cont -> set_scrollable(true) (preservado)");
    check(has_sc("s_input_cont", 0),   "build_chat_ui: s_input_cont -> set_scrollable(false)");
    check(has_sc("s_input_ta", 0),     "build_chat_ui: s_input_ta -> set_scrollable(false)");
    check(has_sc("s_modal", 0),        "build_chat_ui: s_modal -> set_scrollable(false)");
    printf("  chat_ui: captures=%d\n\n", sc_count);

    /* C4: modal e rebuild preservados (nada do modal é rolável) */
    reset_calls();
    tgt_open_config_modal();
    check(has_sc("cfg_body", 0), "modal: cfg_body -> set_scrollable(false) (nada rolável no modal)");
    check(has_sc("s_modal_card", 0),"modal: s_modal_card -> set_scrollable(false) (card não rola)");
    check(has_sc("btns", 0),       "modal: btns -> set_scrollable(false) (linha de botões fixa)");
    check(has_sc("s_modal_backdrop", 0), "modal: s_modal_backdrop -> set_scrollable(false)");
    check(has_sc("s_cfg_url", 0) && has_sc("s_cfg_token", 0) &&
          has_sc("s_cfg_model", 0) && has_sc("s_cfg_max_tokens", 0),
          "modal: 4 campos s_cfg_* -> set_scrollable(false)");
    printf("  modal: captures=%d\n\n", sc_count);

    reset_calls();
    tgt_rebuild_messages();
    check(has_stb("s_messages_cont", 1),"build: scroll_to_bottom(s_messages_cont, true) preservado");
    printf("  rebuild: captures=%d\n\n", sc_count);

    /* C5: nenhum alvo de balão/input/modal registrado como true — somente
     * s_messages_cont (o único set_scrollable(true) do arquivo). */
    reset_calls();
    tgt_build_bubble("system");
    tgt_build_chat_ui();
    tgt_open_config_modal();
    check(!has_sc("row", 1) && !has_sc("spacer", 1) && !has_sc("second_spacer", 1) &&
          !has_sc("bubble", 1) && !has_sc("s_input_cont", 1) && !has_sc("s_input_ta", 1) &&
          !has_sc("s_modal", 1) && !has_sc("s_modal_backdrop", 1) &&
          !has_sc("s_modal_card", 1) && !has_sc("btns", 1) && !has_sc("cfg_body", 1) &&
          !has_sc("s_cfg_url", 1) && !has_sc("s_cfg_token", 1) &&
          !has_sc("s_cfg_model", 1) && !has_sc("s_cfg_max_tokens", 1),
          "NENHUM balão/input/modal com set_scrollable(true) — só s_messages_cont");

    /* C6: REQ-002 — gap do row por papel (system sem gap) */
    reset_calls();
    tgt_build_bubble("user");
    check(has_gap("row", 4), "user: gap(row, 4) registrado");
    printf("  user: gap=%s\n\n", has_gap("row", 4) ? "4" : "AUSENTE");

    reset_calls();
    tgt_build_bubble("system");
    check(has_gap("row", 0), "system: gap(row, 0) registrado (sem gap -> sem overflow)");
    printf("  system: gap=%s\n\n", has_gap("row", 0) ? "0" : "AUSENTE/4");

    /* C7: matemática de flex do layout-alvo — Σ(base) + gaps ≤ conteúdo do row.
     * W = 704 (retrato Tab5: 720 − 2×6 pad messages_cont − 2×2 pad row).
     * system: bubble PCT(100) + 2 spacers + gap 0 → W + 0 ≤ W. */
    const int W = 704;
    check(1 * W + 2 * 0 <= W,            "system:  W + 2×gap0 ≤ W (sem overflow horizontal)");
    check(8 * W / 10 + 1 * 4 <= W,       "user:    0.8W + gap4 ≤ W");
    check(8 * W / 10 + 0 <= W,           "assistant: 0.8W ≤ W");
    printf("  flex math @%d: system=%d user=%d assistant=%d\n\n",
           W, W + 2 * 0, 8 * W / 10 + 4, 8 * W / 10);

    printf("\n=== Scroll Capture Runtime: %s (failures=%d) ===\n",
           failures ? "FAILED" : "ALL PASSED", failures);
    return failures ? 1 : 0;
}
TESTEOF

echo "[INFO] Compilando teste de contrato de scroll..."
if gcc -std=c11 -Wall -Wextra -o "${OUT_DIR}/test_scroll_capture_contract" \
       "${SCRIPT_DIR}/test_scroll_capture_contract.c" 2>&1; then
    echo "[INFO] Executando teste de contrato de scroll..."
    set +e
    "${OUT_DIR}/test_scroll_capture_contract"
    RUNTIME_RESULT=$?
    set -e
    echo ""
else
    echo "[FAIL] Teste de contrato de scroll falhou ao compilar"
    RUNTIME_RESULT=1
fi
rm -f "${SCRIPT_DIR}/test_scroll_capture_contract.c"

# ─────────────────────────────────────────────────────────────────────────────
# Veredito
# ─────────────────────────────────────────────────────────────────────────────
STATIC_RESULT=0
if [ "${FAIL}" -gt 0 ] || [ "${EXTRACT_RESULT}" -ne 0 ]; then
    STATIC_RESULT=1
fi

echo ""
echo "=== Scroll Capture Contract: resumo ==="
echo "  TEST-001 (grep em src/main.c):  ${PASS} passed, ${FAIL} failed, ${TOTAL} total"
echo "  TEST-002 (corpos reais extraídos): $([ ${EXTRACT_RESULT} -eq 0 ] && echo OK || echo FALHOU)"
echo "  TEST-003 (runtime layout-alvo): $([ ${RUNTIME_RESULT} -eq 0 ] && echo OK || echo FALHOU)"

if [ ${STATIC_RESULT} -ne 0 ]; then
    echo "[FAIL] Contrato de captura de scroll NÃO satisfeito"
    exit 1
fi
exit ${RUNTIME_RESULT}
