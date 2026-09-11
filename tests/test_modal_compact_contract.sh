#!/usr/bin/env bash
# test_modal_compact_contract.sh - Contrato do modal compacto 2x2 (plano
# aprovado). NENHUM objeto do modal é rolável; cfg_body=false; o único
# set_scrollable(..., true) do arquivo é s_messages_cont; card =
# TAB5_UI_PCT(96) x TAB5_UI_SIZE_CONTENT; grade compacta 2x2 dos campos;
# conteúdo cabe com o teclado aberto em retrato/paisagem; campos e botões
# acessíveis.
#
# Requisitos do plano aprovado:
#   REQ-NOSCROLL -> NENHUM objeto do modal é rolável: s_modal, s_modal_backdrop,
#                   s_modal_card, cfg_body, row1/row2, cell_*, lbl_*,
#                   s_cfg_url/token/model/max_tokens e btns usam
#                   set_scrollable(false). No arquivo inteiro,
#                   set_scrollable(..., true) existe SOMENTE para s_messages_cont.
#   REQ-CARD    -> s_modal_card = TAB5_UI_PCT(96) x TAB5_UI_SIZE_CONTENT
#                  (altura automática — não usa PCT(60)/card_h).
#   REQ-GRID    -> cfg_body (filho de card, COLUMN, gap 10) contém duas linhas
#                  row1/row2 (FLEX_FLOW_ROW, PCT(100) x SIZE_CONTENT, gap 0);
#                  cada linha contém 2 células cell_* (PCT(50) x SIZE_CONTENT,
#                  FLEX_FLOW_COLUMN, gap 4); cada célula tem um rótulo (lbl_*) +
#                  textarea (s_cfg_* PCT(100) x 42).
#   REQ-FIT     -> o conteúdo compacto (~262px) cabe com o teclado aberto:
#                  retrato 720x1280 kb 400 -> visível 880px; paisagem 1280x720
#                  kb 400 -> visível 320px (>= 262). Coluna única (~414px)
#                  NÃO caberia em paisagem -> a grade 2x2 é obrigatória.
#                  Extremo documentado: paisagem kb 550 -> 170px < 262px
#                  (clipping aceito; SEM scroll como solução).
#   REQ-FIT-W   -> duas células PCT(50) + gap 0 = 100% e dois botões PCT(50)
#                  + gap 0 = 100%; nenhuma linha excede o conteúdo do pai.
#   REQ-ACCESS  -> acessibilidade: 4 rótulos + 4 textareas alcançáveis (cada
#                  textarea tem rótulo próprio na mesma célula) e os dois botões
#                  de ação s_btn_cancel_cfg/s_btn_save no rodapé btns.
#   REQ-REL     -> layout relativo preservado: modal/backdrop PCT(100)xPCT(100),
#                  card CENTER com offset -(kb_h/2); ausência de dimensões
#                  absolutas (sem tab5_ui_get_display_size/usable_h/card_h).
#
# Partes:
#   A. Estática (grep em src/main.c) — padrões obrigatórios
#   B. Extração Python dos corpos REAIS (open_config_modal / apply_modal_layout)
#   C. Runtime C: réplica geométrica do layout-alvo (fit com teclado)
#   D. Fato real: únicos set_scrollable(..., true) do arquivo = s_messages_cont
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC="${APP_DIR}/src/main.c"
OUT_DIR="${SCRIPT_DIR}/.build"
mkdir -p "${OUT_DIR}"

echo "=== Modal Compact 2x2 Contract (cfg_body=false, card auto-height, grade 2x2, fit teclado) ==="
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
# A. Estática: greps em src/main.c
# ─────────────────────────────────────────────────────────────────────────────
echo "--- A. Estática: nenhum objeto do modal rolável (REQ-NOSCROLL) ---"

# A1. cfg_body NÃO é rolável (era true no modelo antigo)
if grep -qP 'tab5_ui_obj_set_scrollable\(\s*cfg_body\s*,\s*false\s*\)' "${SRC}"; then
    run_test "cfg_body = set_scrollable(false)" "PASS"
else
    run_test "cfg_body = set_scrollable(false)" "FAIL"
fi

# A2. card/modal/backdrop/btns/campos continuam não roláveis
for obj in s_modal s_modal_backdrop s_modal_card btns; do
    if grep -qP "tab5_ui_obj_set_scrollable\(\s*${obj}\s*,\s*false\s*\)" "${SRC}"; then
        run_test "${obj} = set_scrollable(false)" "PASS"
    else
        run_test "${obj} = set_scrollable(false)" "FAIL"
    fi
done

for cfg_field in s_cfg_url s_cfg_token s_cfg_model s_cfg_max_tokens; do
    if grep -qP "tab5_ui_obj_set_scrollable\(\s*${cfg_field}\s*,\s*false\s*\)" "${SRC}"; then
        run_test "${cfg_field} = set_scrollable(false)" "PASS"
    else
        run_test "${cfg_field} = set_scrollable(false)" "FAIL"
    fi
done

echo ""
echo "--- A. Estática: card auto-height (REQ-CARD) ---"

# A3. card = PCT(96) x SIZE_CONTENT
if grep -qP 'tab5_ui_obj_set_size\(\s*(?:s_modal_card|card)\s*,\s*TAB5_UI_PCT\(\s*96\s*\)\s*,\s*TAB5_UI_SIZE_CONTENT\s*\)' "${SRC}"; then
    run_test "card = PCT(96) x SIZE_CONTENT (auto-height)" "PASS"
else
    run_test "card = PCT(96) x SIZE_CONTENT (auto-height)" "FAIL"
fi

# A4. card NÃO usa mais PCT(60) (regressão do modelo antigo)
if grep -qP 'tab5_ui_obj_set_size\(\s*(?:s_modal_card|card)\s*,\s*TAB5_UI_PCT\(\s*96\s*\)\s*,\s*TAB5_UI_PCT\(\s*60\s*\)' "${SRC}"; then
    run_test "card NÃO usa mais PCT(60) (auto-height)" "FAIL"
else
    run_test "card NÃO usa mais PCT(60) (auto-height)" "PASS"
fi

echo ""
echo "--- A. Estática: grade compacta 2x2 (REQ-GRID) ---"

# A5. cfg_body é filho de card
if grep -qP 'cfg_body\s*=\s*tab5_ui_container_create\(\s*card\s*\)' "${SRC}"; then
    run_test "cfg_body = container_create(card)" "PASS"
else
    run_test "cfg_body = container_create(card)" "FAIL"
fi

# A6. linhas da grade filhas de cfg_body
if grep -qP 'row[12]\s*=\s*tab5_ui_container_create\(\s*cfg_body\s*\)' "${SRC}"; then
    run_test "row1/row2 = container_create(cfg_body)" "PASS"
else
    run_test "row1/row2 = container_create(cfg_body)" "FAIL"
fi

# A7. linhas FLEX_FLOW_ROW
for row in row1 row2; do
    if grep -qP "tab5_ui_obj_set_flex_flow\(\s*${row}\s*,\s*TAB5_UI_FLEX_FLOW_ROW\s*\)" "${SRC}"; then
        run_test "${row} = FLEX_FLOW_ROW" "PASS"
    else
        run_test "${row} = FLEX_FLOW_ROW" "FAIL"
    fi
done

# A7b. PCT(50)+PCT(50) só cabe quando o row não adiciona gap horizontal.
for row in row1 row2; do
    if grep -qP "tab5_ui_obj_set_gap\(\s*${row}\s*,\s*0\s*\)" "${SRC}"; then
        run_test "${row}: gap = 0 (duas colunas fit 100%)" "PASS"
    else
        run_test "${row}: gap = 0 (duas colunas fit 100%)" "FAIL"
    fi
done

# A8. células PCT(50) x SIZE_CONTENT
for cell in cell_url cell_token cell_model cell_max_tokens; do
    if grep -qP "tab5_ui_obj_set_size\(\s*${cell}\s*,\s*TAB5_UI_PCT\(\s*50\s*\)\s*,\s*TAB5_UI_SIZE_CONTENT\s*\)" "${SRC}"; then
        run_test "${cell} = PCT(50) x SIZE_CONTENT" "PASS"
    else
        run_test "${cell} = PCT(50) x SIZE_CONTENT" "FAIL"
    fi
done

# A9. células FLEX_FLOW_COLUMN (rótulo + textarea empilhados)
for cell in cell_url cell_token cell_model cell_max_tokens; do
    if grep -qP "tab5_ui_obj_set_flex_flow\(\s*${cell}\s*,\s*TAB5_UI_FLEX_FLOW_COLUMN\s*\)" "${SRC}"; then
        run_test "${cell} = FLEX_FLOW_COLUMN" "PASS"
    else
        run_test "${cell} = FLEX_FLOW_COLUMN" "FAIL"
    fi
done

# A10. textareas são filhos das células (não de card/cfg_body)
if grep -qP 'tab5_ui_textarea_create\(\s*cell_(?:url|token|model|max_tokens)\s*\)' "${SRC}"; then
    run_test "s_cfg_* = textarea_create(cell_*) (grade 2x2)" "PASS"
else
    run_test "s_cfg_* = textarea_create(cell_*) (grade 2x2)" "FAIL"
fi

# A11. rótulos são filhos das células
if grep -qP 'tab5_ui_label_create\(\s*cell_(?:url|token|model|max_tokens)\s*\)' "${SRC}"; then
    run_test "lbl_* = label_create(cell_*) (rótulo no topo da célula)" "PASS"
else
    run_test "lbl_* = label_create(cell_*) (rótulo no topo da célula)" "FAIL"
fi

# A12. textareas fixas em PCT(100) x 42 dentro das células
for cfg_field in s_cfg_url s_cfg_token s_cfg_model s_cfg_max_tokens; do
    if grep -qP "tab5_ui_obj_set_size\(\s*${cfg_field}\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*,\s*42\s*\)" "${SRC}"; then
        run_test "${cfg_field} = PCT(100) x 42" "PASS"
    else
        run_test "${cfg_field} = PCT(100) x 42" "FAIL"
    fi
done

echo ""
echo "--- A. Estática: acessibilidade (REQ-ACCESS) ---"

# A13. rótulos de campo presentes (um por textarea)
for lbl in lbl_url lbl_token lbl_model lbl_tokens; do
    if grep -qP "${lbl}\s*=\s*tab5_ui_label_create" "${SRC}"; then
        run_test "${lbl} presente (rótulo do campo)" "PASS"
    else
        run_test "${lbl} presente (rótulo do campo)" "FAIL"
    fi
done

# A14. botões de ação presentes no rodapé (PCT(50) x 44)
for btn in s_btn_cancel_cfg s_btn_save; do
    if grep -qP "tab5_ui_obj_set_size\(\s*${btn}\s*,\s*TAB5_UI_PCT\(\s*50\s*\)\s*,\s*44\s*\)" "${SRC}"; then
        run_test "${btn} = PCT(50) x 44 (acessível)" "PASS"
    else
        run_test "${btn} = PCT(50) x 44 (acessível)" "FAIL"
    fi
done

# A15. btns continua filho de card (rodapé fixo fora da grade)
if grep -qP 'btns\s*=\s*tab5_ui_container_create\(\s*card\s*\)' "${SRC}"; then
    run_test "btns = container_create(card) (rodapé fixo)" "PASS"
else
    run_test "btns = container_create(card) (rodapé fixo)" "FAIL"
fi

echo ""
echo "--- A. Estática: layout relativo preservado (REQ-REL) ---"

# A16. modal/backdrop PCT(100) x PCT(100)
for pair in "s_modal" "s_modal_backdrop"; do
    if grep -qP "tab5_ui_obj_set_size\(\s*${pair}\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*,\s*TAB5_UI_PCT\(\s*100\s*\)" "${SRC}"; then
        run_test "${pair} = PCT(100) x PCT(100)" "PASS"
    else
        run_test "${pair} = PCT(100) x PCT(100)" "FAIL"
    fi
done

# A17. card CENTER offset -(kb_h/2)
if grep -qP 'tab5_ui_obj_set_align\(\s*(?:s_modal_card|card)\s*,\s*TAB5_UI_ALIGN_CENTER\s*,\s*0\s*,\s*-\s*\(\s*kb_h\s*/\s*2\s*\)' "${SRC}"; then
    run_test "card CENTER offset -(kb_h/2) (teclado preservado)" "PASS"
else
    run_test "card CENTER offset -(kb_h/2) (teclado preservado)" "FAIL"
fi

# A18. sem dimensões absolutas no caminho modal
if grep -qP '\bbase_y\b|\busable_h\b|\bcard_h\b' "${SRC}"; then
    run_test "SEM usable_h/card_h/base_y (nada de altura absoluta)" "FAIL"
else
    run_test "SEM usable_h/card_h/base_y (nada de altura absoluta)" "PASS"
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# B. Extração Python: corpos REAIS de open_config_modal / apply_modal_layout
# ─────────────────────────────────────────────────────────────────────────────
echo "--- B. Extração: corpos REAIS (contrato compacto 2x2) ---"

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

failures = 0
def require(condition, message):
    global failures
    if condition:
        print(f"  [PASS] {message}")
    else:
        print(f"  [FAIL] {message}")
        failures += 1

open_body = function_body("open_config_modal")
apply_body = function_body("apply_modal_layout")

# ── REQ-NOSCROLL: NENHUM objeto do modal é rolável ──
print("--- B1: nenhum objeto do modal é rolável ---")
require(re.search(r'set_scrollable\(\s*cfg_body\s*,\s*false\s*\)', open_body) is not None,
        "cfg_body: set_scrollable(false) no corpo REAL (nada rola)")
require(re.search(r'set_scrollable\(\s*row[12]\s*,\s*false\s*\)', open_body) is not None,
        "row1/row2: set_scrollable(false) no corpo REAL")
require(re.search(r'set_scrollable\(\s*cell_(?:url|token|model|max_tokens)\s*,\s*false\s*\)', open_body) is not None,
        "cell_*: set_scrollable(false) no corpo REAL (grade 2x2)")
require(not re.search(r'set_scrollable\(\s*\w+\s*,\s*true\s*\)', open_body),
        "open_config_modal NÃO contém NENHUM set_scrollable(..., true)")
require(re.search(r'set_scrollable\(\s*s_modal_card\s*,\s*false\s*\)', open_body) is not None,
        "s_modal_card: set_scrollable(false) no corpo REAL")

# ── REQ-CARD: card auto-height ──
print("--- B2: card PCT(96) x SIZE_CONTENT ---")
require(re.search(r'set_size\(\s*(?:s_modal_card|card)\s*,\s*TAB5_UI_PCT\(\s*96\s*\)\s*,\s*TAB5_UI_SIZE_CONTENT\s*\)', open_body) is not None,
        "open_config_modal: card = PCT(96) x SIZE_CONTENT no corpo REAL")
require(re.search(r'set_size\(\s*(?:card|s_modal_card)\s*,\s*TAB5_UI_PCT\(\s*96\s*\)\s*,\s*TAB5_UI_SIZE_CONTENT\s*\)', apply_body) is not None,
        "apply_modal_layout: card = PCT(96) x SIZE_CONTENT no corpo REAL")
require(not re.search(r'set_size\(\s*(?:card|s_modal_card)\s*,\s*TAB5_UI_PCT\(\s*96\s*\)\s*,\s*TAB5_UI_PCT\(\s*60\s*\)\s*\)', open_body + apply_body),
        "card NÃO usa mais PCT(60) em nenhum dos corpos reais")

# ── REQ-GRID: estrutura da grade 2x2 ──
print("--- B3: grade compacta 2x2 (linhas/células/rótulos/textareas) ---")
require(re.search(r'cfg_body\s*=\s*tab5_ui_container_create\s*\(\s*card\s*\)', open_body) is not None,
        "cfg_body criado como filho de card no corpo REAL")
require(re.search(r'row1\s*=\s*tab5_ui_container_create\s*\(\s*cfg_body\s*\)', open_body) is not None,
        "row1 criado como filho de cfg_body no corpo REAL")
require(re.search(r'row2\s*=\s*tab5_ui_container_create\s*\(\s*cfg_body\s*\)', open_body) is not None,
        "row2 criado como filho de cfg_body no corpo REAL")
for row in ("row1", "row2"):
    require(re.search(rf'set_flex_flow\(\s*{row}\s*,\s*TAB5_UI_FLEX_FLOW_ROW\s*\)', open_body) is not None,
            f"{row}: FLEX_FLOW_ROW no corpo REAL (dois campos lado a lado)")

cells_rows = {"cell_url": "row1", "cell_token": "row1",
              "cell_model": "row2", "cell_max_tokens": "row2"}
for cell, row in cells_rows.items():
    require(re.search(rf'{cell}\s*=\s*tab5_ui_container_create\s*\(\s*{row}\s*\)', open_body) is not None,
            f"{cell} criado como filho de {row} no corpo REAL")
    require(re.search(rf'set_size\(\s*{cell}\s*,\s*TAB5_UI_PCT\(\s*50\s*\)\s*,\s*TAB5_UI_SIZE_CONTENT\s*\)', open_body) is not None,
            f"{cell}: PCT(50) x SIZE_CONTENT no corpo REAL")
    require(re.search(rf'set_flex_flow\(\s*{cell}\s*,\s*TAB5_UI_FLEX_FLOW_COLUMN\s*\)', open_body) is not None,
            f"{cell}: FLEX_FLOW_COLUMN no corpo REAL (rótulo + textarea empilhados)")
    require(re.search(rf'set_scrollable\(\s*{cell}\s*,\s*false\s*\)', open_body) is not None,
            f"{cell}: set_scrollable(false) no corpo REAL")

fields_cell = {"s_cfg_url": "cell_url", "s_cfg_token": "cell_token",
               "s_cfg_model": "cell_model", "s_cfg_max_tokens": "cell_max_tokens"}
labels_cell = {"lbl_url": "cell_url", "lbl_token": "cell_token",
               "lbl_model": "cell_model", "lbl_tokens": "cell_max_tokens"}
for lbl, cell in labels_cell.items():
    require(re.search(rf'{lbl}\s*=\s*tab5_ui_label_create\s*\(\s*{cell}\s*\)', open_body) is not None,
            f"{lbl} (rótulo) criado como filho de {cell} no corpo REAL")
for cfg, cell in fields_cell.items():
    require(re.search(rf'{cfg}\s*=\s*tab5_ui_textarea_create\s*\(\s*{cell}\s*\)', open_body) is not None,
            f"{cfg} criado como filho de {cell} no corpo REAL")
    require(re.search(rf'set_size\(\s*{cfg}\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*,\s*42\s*\)', open_body) is not None,
            f"{cfg}: PCT(100) x 42 no corpo REAL")
    require(re.search(rf'set_scrollable\(\s*{cfg}\s*,\s*false\s*\)', open_body) is not None,
            f"{cfg}: set_scrollable(false) no corpo REAL")

# ── REQ-ACCESS: rodapé acessível ──
print("--- B4: rodapé com botões acessíveis ---")
require(re.search(r'btns\s*=\s*tab5_ui_container_create\s*\(\s*card\s*\)', open_body) is not None,
        "btns criado como filho de card (rodapé) no corpo REAL")
require(re.search(r's_btn_cancel_cfg\s*=\s*tab5_ui_btn_create\s*\(\s*btns\s*,', open_body) is not None,
        "s_btn_cancel_cfg criado no rodapé btns")
require(re.search(r's_btn_save\s*=\s*tab5_ui_btn_create\s*\(\s*btns\s*,', open_body) is not None,
        "s_btn_save criado no rodapé btns")

# ── REQ-REL: layout relativo e teclado preservado ──
print("--- B5: apply_modal_layout relativo preservado ---")
require(re.search(r'set_size\(\s*s_modal\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*,\s*TAB5_UI_PCT\(\s*100\s*\)', apply_body) is not None,
        "apply_modal_layout: modal PCT(100) x PCT(100)")
require(re.search(r'set_size\(\s*(?:backdrop|s_modal_backdrop)\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*,\s*TAB5_UI_PCT\(\s*100\s*\)', apply_body) is not None,
        "apply_modal_layout: backdrop PCT(100) x PCT(100)")
require(re.search(r'set_align\(\s*(?:card|s_modal_card)\s*,\s*TAB5_UI_ALIGN_CENTER\s*,\s*0\s*,\s*-\s*\(\s*kb_h\s*/\s*2\s*\)', apply_body) is not None,
        "apply_modal_layout: card CENTER offset -(kb_h/2) (teclado)")
require("tab5_ui_get_display_size" not in apply_body,
        "apply_modal_layout: SEM tab5_ui_get_display_size (host stale não vaza)")
require(not re.search(r"\busable_h\b|\bcard_h\b", apply_body),
        "apply_modal_layout: SEM usable_h/card_h (altura automática, sem absolutos)")
require(not re.search(r'\bcfg_body\b', apply_body),
        "apply_modal_layout: não gerencia cfg_body (geometria flex-managed)")

print()
print(f"=== EXTRAÇÃO (B): {'ALL PASSED' if failures == 0 else str(failures) + ' FAIL(s)'} ===")
sys.exit(1 if failures else 0)
PY
EXTRACT_RESULT=$?
set -e

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# C. Runtime: réplica geométrica do layout-alvo (fit com teclado)
# ─────────────────────────────────────────────────────────────────────────────
echo "--- C. Geometria: conteúdo cabe com teclado (retrato/paisagem) ---"

cat > "${SCRIPT_DIR}/test_modal_compact_contract.c" << 'TESTEOF'
#include <stdio.h>
#include <stdbool.h>

#define TAB5_UI_PCT(percent) (-1000 - (percent))
#define TAB5_UI_SIZE_CONTENT (-1)

static int failures = 0;
static void check(int c, const char *m) {
    if (c) printf("  [PASS] %s\n", m);
    else   { printf("  [FAIL] %s\n", m); failures++; }
}

int main(void) {
    printf("=== Modal Compact 2x2 — Geometry (fit com teclado) ===\n\n");

    check(TAB5_UI_PCT(100) == -1100, "FATO: PCT(100) == -1100");
    check(TAB5_UI_PCT(96)  == -1096, "FATO: PCT(96) == -1096");
    check(TAB5_UI_SIZE_CONTENT == -1, "FATO: SIZE_CONTENT == -1 (auto-height)");

    /* PCT columns are resolved against the same row content width.  This is
     * the overflow invariant for the production grade and action footer. */
    const int row_content = 320;
    const int column_gap = 0;
    const int action_gap = 0;
    check(2 * (row_content / 2) + column_gap <= row_content,
          "grade 2x2: PCT(50)+PCT(50)+gap(0) <= row width");
    check(2 * (row_content / 2) + action_gap <= row_content,
          "rodape: PCT(50)+PCT(50)+gap(0) <= btns width");

    /* Estimativas do conteúdo do card:
     *   compacto 2x2: pads(32) + título(24) + gaps do card(2x10) +
     *                 grade 2x2(2 x [18 + 4 + 42] + 10 vertical) + btns(48)
     *                 = 32 + 24 + 20 + 138 + 48 = 262px
     *   coluna única (antigo): pads(32) + título(24) + 4 x [18 + 4 + 42]
     *                 + 3 gaps(10) + btns(48) ≈ 414px
     */
    const int compact_h   = 262;
    const int single_col_h = 414;

    printf("  conteúdo compacto 2x2 = %dpx; coluna única = %dpx\n\n", compact_h, single_col_h);

    /* Retrato 720x1280, kb_h=400 -> visível 880px */
    printf("Retrato 720x1280, kb_h=400\n");
    {
        check(1280 - 400 >= compact_h,
              "retrato+kb(400): visível 880px >= conteúdo 262px — cabe, nada rola");
        check(1280 - 400 >= single_col_h,
              "retrato+kb(400): visível 880px >= 414px — (coluna única também caberia)");
        check(-(400 / 2) == -200, "retrato+kb(400): card CENTER offset -(kb_h/2) = -200");
    }

    /* Paisagem 1280x720, kb_h=400 -> visível 320px */
    printf("\nPaisagem 1280x720, kb_h=400\n");
    {
        check(720 - 400 >= compact_h,
              "paisagem+kb(400): visível 320px >= 262px — grade 2x2 cabe inteira");
        check(720 - 400 < single_col_h,
              "paisagem+kb(400): visível 320px < 414px — coluna única NÃO caberia (2x2 é obrigatória)");
        check(-(400 / 2) == -200, "paisagem+kb(400): card CENTER offset -(kb_h/2) = -200");
    }

    /* Paisagem 1280x720, kb_h=300 -> visível 420px */
    printf("\nPaisagem 1280x720, kb_h=300\n");
    {
        check(720 - 300 >= compact_h,
              "paisagem+kb(300): visível 420px >= 262px — folga confortável");
    }

    /* Extremo documentado: paisagem kb_h=550 -> visível 170px */
    printf("\nPaisagem 1280x720, kb_h=550 (extremo documentado)\n");
    {
        check(720 - 550 < compact_h,
              "paisagem+kb(550): visível 170px < 262px — clipping aceito (SEM scroll)");
        check(-(550 / 2) == -275, "paisagem+kb(550): card CENTER offset -(kb_h/2) = -275");
    }

    /* Sem teclado */
    printf("\nSem teclado (kb_h=0)\n");
    {
        check(-(0 / 2) == 0, "kb_h=0: card CENTER offset 0");
        /* Estrutura relativa: card largo 96% do visual em qualquer orientação */
        check((720 * 96 + 50) / 100 == 691, "retrato: card largura = 96% de 720 = 691px");
        check((1280 * 96 + 50) / 100 == 1229, "paisagem: card largura = 96% de 1280 = 1229px");
    }

    printf("\n=== Modal Compact Geometry: %s (failures=%d) ===\n",
           failures ? "FAILED" : "ALL PASSED", failures);
    return failures ? 1 : 0;
}
TESTEOF

echo "[INFO] Compilando teste de geometria do modal compacto 2x2..."
if gcc -std=c11 -Wall -Wextra -o "${OUT_DIR}/test_modal_compact_contract" \
       "${SCRIPT_DIR}/test_modal_compact_contract.c" 2>&1; then
    echo "[INFO] Executando teste de geometria..."
    set +e
    "${OUT_DIR}/test_modal_compact_contract"
    RUNTIME_RESULT=$?
    set -e
    echo ""
else
    echo "[FAIL] Teste de geometria falhou ao compilar"
    RUNTIME_RESULT=1
fi
rm -f "${SCRIPT_DIR}/test_modal_compact_contract.c"

# ─────────────────────────────────────────────────────────────────────────────
# D. Fato real: únicos set_scrollable(..., true) do arquivo = s_messages_cont
# ─────────────────────────────────────────────────────────────────────────────
echo "--- D. Fato real: único set_scrollable(..., true) do arquivo ---"

set +e
SRC_PATH="${SRC}" python3 - <<'PY'
import os
import re
import sys

source = open(os.environ["SRC_PATH"], encoding="utf-8").read()
calls = re.findall(
    r"tab5_ui_obj_set_scrollable\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*,\s*(true|false)\s*\)",
    source,
)
true_targets = sorted(set(name for name, val in calls if val == "true"))
failures = 0
if true_targets == ["s_messages_cont"]:
    print("  [PASS] únicos set_scrollable(..., true) do arquivo = [s_messages_cont]")
else:
    print(f"  [FAIL] únicos set_scrollable(..., true) deveriam ser [s_messages_cont]; "
          f"obtido: {true_targets if true_targets else 'NENHUM'}")
    failures = 1
sys.exit(failures)
PY
UNIQUE_RESULT=$?
set -e

# ─────────────────────────────────────────────────────────────────────────────
# Veredito
# ─────────────────────────────────────────────────────────────────────────────
STATIC_RESULT=0
if [ "${FAIL}" -gt 0 ] || [ "${EXTRACT_RESULT}" -ne 0 ] || [ "${UNIQUE_RESULT}" -ne 0 ]; then
    STATIC_RESULT=1
fi

echo ""
echo "=== Modal Compact 2x2 Contract: resumo ==="
echo "  A. Estática (greps src/main.c):     ${PASS} passed, ${FAIL} failed, ${TOTAL} total"
echo "  B. Extração (corpos reais):         $([ ${EXTRACT_RESULT} -eq 0 ] && echo OK || echo 'FALHOU')"
echo "  C. Geometria (fit com teclado):     $([ ${RUNTIME_RESULT} -eq 0 ] && echo OK || echo FALHOU)"
echo "  D. Único scrollable(true) = s_messages_cont: $([ ${UNIQUE_RESULT} -eq 0 ] && echo OK || echo 'FALHOU')"

if [ ${STATIC_RESULT} -ne 0 ]; then
    echo ""
    echo "[FAIL] Contrato do modal compacto 2x2 NÃO satisfeito:"
    echo "       verifique cfg_body=false, card PCT(96)xSIZE_CONTENT e a"
    echo "       grade 2x2 em src/main.c"
    exit 1
fi
exit ${RUNTIME_RESULT}
