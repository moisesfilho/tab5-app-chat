#!/usr/bin/env bash
# test_modal_interior_contract.sh - Contrato dos elementos INTERIORES do modal:
#   btns, s_modal (inativo), s_modal_backdrop, s_cfg_*, botões de ação.
#
# Cobertura (requisitos do plano aprovado — modal compacto 2x2, nada rolável):
#   REQ-BODY  -> cfg_body: filho de card, set_scrollable(false), flex COLUMN
#                (NÃO usa flex_grow; contém a grade 2x2). Nada no modal rola.
#   REQ-CARD  -> s_modal_card: set_scrollable(false) e PCT(96) x SIZE_CONTENT
#                (altura automática — o conteúdo cabe, não rola).
#   REQ-GRID  -> duas linhas row1/row2 (filhas de cfg_body, FLEX_FLOW_ROW,
#                PCT(100) x SIZE_CONTENT, gap horizontal 0) cada uma com 2 células
#                PCT(50) x SIZE_CONTENT (FLEX_FLOW_COLUMN, gap 4); cada célula
#                contém um rótulo (lbl_*) + textarea (s_cfg_* PCT(100) x 42).
#   REQ-FOOT  -> btns: filho DIRETO de card (fora do corpo), scrollable(false),
#                PCT(100) x 48 — linha de botões fixa não rolável.
#   REQ-BTNS  -> btns: FLEX_FLOW_ROW, bg=0/opacity=0, border=0/width=0, pad=0,
#                gap=0 (PCT(50)+PCT(50) cabe sem overflow)
#   REQ-MODAL -> s_modal: set_scrollable(false), size 0x0 (inativo), pad=0,
#                bg=0, border=0, radius=0
#   REQ-BDROP -> s_modal_backdrop: set_scrollable(false), PCT(100)xPCT(100),
#                TOP_LEFT(0,0), bg=0x000000/opacity=170, border=0, radius=0, pad=0
#   REQ-CFG   -> s_cfg_url/token/model/max_tokens: set_scrollable(false)
#                (campos com altura fixa 42 dentro das células da grade 2x2)
#   REQ-BTNA  -> s_btn_cancel_cfg/s_btn_save: PCT(50)x44, cores, ícones
#   REQ-CLEAN -> close_config_modal: invalida 8 handles + s_modal size=0
#   REQ-THEME -> app_on_theme_changed: invalida todos os handles modal
#
# Invariante global: o ÚNICO set_scrollable(..., true) em src/main.c é
# s_messages_cont; cfg_body/modal/backdrop/card/linhas/células/campos/rodapé
# são todos false.
#
# Partes:
#   A. Estática (grep em src/main.c) — padrões obrigatórios
#   B. Extração Python dos corpos REAIS — contratos semânticos
#   C. Runtime C instrumentado — réplica do layout-alvo
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC="${APP_DIR}/src/main.c"
OUT_DIR="${SCRIPT_DIR}/.build"
mkdir -p "${OUT_DIR}"

echo "=== Modal Interior Contract (btns/modal/backdrop/cfg/btns_action/cleanup) ==="
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
echo "--- A. Estática: padrões em src/main.c ---"

# A1. btns: scrollável = false
if grep -qP 'tab5_ui_obj_set_scrollable\(\s*btns\s*,\s*false\s*\)' "${SRC}"; then
    run_test "btns = set_scrollable(false)" "PASS"
else
    run_test "btns = set_scrollable(false)" "FAIL"
fi

# A2. btns: FLEX_FLOW_ROW
if grep -qP 'tab5_ui_obj_set_flex_flow\(\s*btns\s*,\s*TAB5_UI_FLEX_FLOW_ROW\s*\)' "${SRC}"; then
    run_test "btns = FLEX_FLOW_ROW" "PASS"
else
    run_test "btns = FLEX_FLOW_ROW" "FAIL"
fi

# A3. btns: PCT(100) x 48
if grep -qP 'tab5_ui_obj_set_size\(\s*btns\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*,\s*48\s*\)' "${SRC}"; then
    run_test "btns = PCT(100) x 48" "PASS"
else
    run_test "btns = PCT(100) x 48" "FAIL"
fi

# A4. btns: bg transparente
if grep -qP 'tab5_ui_obj_set_style_bg\(\s*btns\s*,\s*0\s*,\s*0\s*\)' "${SRC}"; then
    run_test "btns: bg = 0/opacity = 0 (transparente)" "PASS"
else
    run_test "btns: bg = 0/opacity = 0 (transparente)" "FAIL"
fi

# A5. btns: border zero
if grep -qP 'tab5_ui_obj_set_style_border\(\s*btns\s*,\s*0\s*,\s*0\s*\)' "${SRC}"; then
    run_test "btns: border = 0/width = 0" "PASS"
else
    run_test "btns: border = 0/width = 0" "FAIL"
fi

# A6. btns: pad zero
if grep -qP 'tab5_ui_obj_set_pad\(\s*btns\s*,\s*0\s*\)' "${SRC}"; then
    run_test "btns: pad = 0" "PASS"
else
    run_test "btns: pad = 0" "FAIL"
fi

# A7. btns: gap 0 (PCT(50)+PCT(50) cabe sem overflow)
if grep -qP 'tab5_ui_obj_set_gap\(\s*btns\s*,\s*0\s*\)' "${SRC}"; then
    run_test "btns: gap = 0 (fit horizontal)" "PASS"
else
    run_test "btns: gap = 0 (fit horizontal)" "FAIL"
fi

echo ""

# --- s_modal (inativo) ---
echo "--- A. Estática: s_modal (inativo) ---"

# A8. s_modal: size 0x0 (inativo, antes de open_config_modal)
if grep -qP 'tab5_ui_obj_set_size\(\s*s_modal\s*,\s*0\s*,\s*0\s*\)' "${SRC}"; then
    run_test "s_modal: size = 0x0 (inativo)" "PASS"
else
    run_test "s_modal: size = 0x0 (inativo)" "FAIL"
fi

# A9. s_modal: pad 0
if grep -qP 'tab5_ui_obj_set_pad\(\s*s_modal\s*,\s*0\s*\)' "${SRC}"; then
    run_test "s_modal: pad = 0" "PASS"
else
    run_test "s_modal: pad = 0" "FAIL"
fi

# A10. s_modal: bg zero
if grep -qP 'tab5_ui_obj_set_style_bg\(\s*s_modal\s*,\s*0\s*,\s*0\s*\)' "${SRC}"; then
    run_test "s_modal: bg = 0/opacity = 0" "PASS"
else
    run_test "s_modal: bg = 0/opacity = 0" "FAIL"
fi

# A11. s_modal: border zero
if grep -qP 'tab5_ui_obj_set_style_border\(\s*s_modal\s*,\s*0\s*,\s*0\s*\)' "${SRC}"; then
    run_test "s_modal: border = 0/width = 0" "PASS"
else
    run_test "s_modal: border = 0/width = 0" "FAIL"
fi

# A12. s_modal: radius zero
if grep -qP 'tab5_ui_obj_set_style_radius\(\s*s_modal\s*,\s*0\s*\)' "${SRC}"; then
    run_test "s_modal: radius = 0" "PASS"
else
    run_test "s_modal: radius = 0" "FAIL"
fi

# A12b. s_modal: não rolável (não captura gestos fora do card)
if grep -qP 'tab5_ui_obj_set_scrollable\(\s*s_modal\s*,\s*false\s*\)' "${SRC}"; then
    run_test "s_modal: scrollable = false" "PASS"
else
    run_test "s_modal: scrollable = false" "FAIL"
fi

echo ""

# --- s_modal_backdrop ---
echo "--- A. Estática: s_modal_backdrop ---"

# A13. backdrop: bg 0x000000 / opacity 170
if grep -qP 'tab5_ui_obj_set_style_bg\(\s*s_modal_backdrop\s*,\s*0x000000\s*,\s*170\s*\)' "${SRC}"; then
    run_test "backdrop: bg = 0x000000/opacity = 170" "PASS"
else
    run_test "backdrop: bg = 0x000000/opacity = 170" "FAIL"
fi

# A14. backdrop: border zero
if grep -qP 'tab5_ui_obj_set_style_border\(\s*s_modal_backdrop\s*,\s*0\s*,\s*0\s*\)' "${SRC}"; then
    run_test "backdrop: border = 0/width = 0" "PASS"
else
    run_test "backdrop: border = 0/width = 0" "FAIL"
fi

# A15. backdrop: radius zero
if grep -qP 'tab5_ui_obj_set_style_radius\(\s*s_modal_backdrop\s*,\s*0\s*\)' "${SRC}"; then
    run_test "backdrop: radius = 0" "PASS"
else
    run_test "backdrop: radius = 0" "FAIL"
fi

# A16. backdrop: pad zero
if grep -qP 'tab5_ui_obj_set_pad\(\s*s_modal_backdrop\s*,\s*0\s*\)' "${SRC}"; then
    run_test "backdrop: pad = 0" "PASS"
else
    run_test "backdrop: pad = 0" "FAIL"
fi

# A17. backdrop: PCT(100) x PCT(100) + TOP_LEFT(0,0)
if grep -qP 'tab5_ui_obj_set_size\(\s*s_modal_backdrop\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*,\s*TAB5_UI_PCT\(\s*100\s*\)' "${SRC}"; then
    run_test "backdrop: PCT(100) x PCT(100)" "PASS"
else
    run_test "backdrop: PCT(100) x PCT(100)" "FAIL"
fi

# A18. backdrop: align TOP_LEFT(0,0)
if grep -qP 'tab5_ui_obj_set_align\(\s*s_modal_backdrop\s*,\s*TAB5_UI_ALIGN_TOP_LEFT\s*,\s*0\s*,\s*0\s*\)' "${SRC}"; then
    run_test "backdrop: align = TOP_LEFT(0,0)" "PASS"
else
    run_test "backdrop: align = TOP_LEFT(0,0)" "FAIL"
fi

# A18b. backdrop: não rolável (não captura swipe destinado ao card)
if grep -qP 'tab5_ui_obj_set_scrollable\(\s*s_modal_backdrop\s*,\s*false\s*\)' "${SRC}"; then
    run_test "backdrop: scrollable = false" "PASS"
else
    run_test "backdrop: scrollable = false" "FAIL"
fi

echo ""

# --- s_cfg_* textareas ---
echo "--- A. Estática: s_cfg_* textareas ---"

# A19. s_cfg_url: PCT(100) x 42
if grep -qP 'tab5_ui_obj_set_size\(\s*s_cfg_url\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*,\s*42\s*\)' "${SRC}"; then
    run_test "s_cfg_url: PCT(100) x 42" "PASS"
else
    run_test "s_cfg_url: PCT(100) x 42" "FAIL"
fi

# A20. s_cfg_token: PCT(100) x 42
if grep -qP 'tab5_ui_obj_set_size\(\s*s_cfg_token\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*,\s*42\s*\)' "${SRC}"; then
    run_test "s_cfg_token: PCT(100) x 42" "PASS"
else
    run_test "s_cfg_token: PCT(100) x 42" "FAIL"
fi

# A21. s_cfg_model: PCT(100) x 42
if grep -qP 'tab5_ui_obj_set_size\(\s*s_cfg_model\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*,\s*42\s*\)' "${SRC}"; then
    run_test "s_cfg_model: PCT(100) x 42" "PASS"
else
    run_test "s_cfg_model: PCT(100) x 42" "FAIL"
fi

# A22. s_cfg_max_tokens: PCT(100) x 42
if grep -qP 'tab5_ui_obj_set_size\(\s*s_cfg_max_tokens\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*,\s*42\s*\)' "${SRC}"; then
    run_test "s_cfg_max_tokens: PCT(100) x 42" "PASS"
else
    run_test "s_cfg_max_tokens: PCT(100) x 42" "FAIL"
fi

# A23. s_cfg_token: password mode
if grep -qP 'tab5_ui_textarea_set_password_mode\(\s*s_cfg_token\s*,\s*true\s*\)' "${SRC}"; then
    run_test "s_cfg_token: set_password_mode(true)" "PASS"
else
    run_test "s_cfg_token: set_password_mode(true)" "FAIL"
fi

# A24. Nenhum s_cfg_* usa largura absoluta
if grep -qP 'tab5_ui_obj_set_size\(\s*s_cfg_(?:url|token|model|max_tokens)\s*,\s*[0-9]+\s*,' "${SRC}"; then
    run_test "NENHUM s_cfg_* usa largura absoluta literal" "FAIL"
else
    run_test "NENHUM s_cfg_* usa largura absoluta literal" "PASS"
fi

# A24b-A24e. Campos não roláveis (altura fixa 42; NADA no modal rola)
for cfg_field in s_cfg_url s_cfg_token s_cfg_model s_cfg_max_tokens; do
    if grep -qP "tab5_ui_obj_set_scrollable\(\s*${cfg_field}\s*,\s*false\s*\)" "${SRC}"; then
        run_test "${cfg_field}: scrollable = false (altura fixa 42)" "PASS"
    else
        run_test "${cfg_field}: scrollable = false (altura fixa 42)" "FAIL"
    fi
done

echo ""

# --- Botões de ação ---
echo "--- A. Estática: botões de ação (cancelar/salvar) ---"

# A25. s_btn_cancel_cfg: PCT(50) x 44
if grep -qP 'tab5_ui_obj_set_size\(\s*s_btn_cancel_cfg\s*,\s*TAB5_UI_PCT\(\s*50\s*\)\s*,\s*44\s*\)' "${SRC}"; then
    run_test "s_btn_cancel_cfg: PCT(50) x 44" "PASS"
else
    run_test "s_btn_cancel_cfg: PCT(50) x 44" "FAIL"
fi

# A26. s_btn_save: PCT(50) x 44
if grep -qP 'tab5_ui_obj_set_size\(\s*s_btn_save\s*,\s*TAB5_UI_PCT\(\s*50\s*\)\s*,\s*44\s*\)' "${SRC}"; then
    run_test "s_btn_save: PCT(50) x 44" "PASS"
else
    run_test "s_btn_save: PCT(50) x 44" "FAIL"
fi

# A27. s_btn_save: bg = pal_accent
if grep -qP 'tab5_ui_obj_set_style_bg\(\s*s_btn_save\s*,\s*pal_accent\s*,\s*255\s*\)' "${SRC}"; then
    run_test "s_btn_save: bg = pal_accent/255" "PASS"
else
    run_test "s_btn_save: bg = pal_accent/255" "FAIL"
fi

# A28. s_btn_save: text color branco
if grep -qP 'tab5_ui_obj_set_style_text_color\(\s*s_btn_save\s*,\s*0xFFFFFF\s*,\s*255\s*\)' "${SRC}"; then
    run_test "s_btn_save: text_color = 0xFFFFFF" "PASS"
else
    run_test "s_btn_save: text_color = 0xFFFFFF" "FAIL"
fi

# A29. s_btn_cancel_cfg: bg = pal_bg
if grep -qP 'tab5_ui_obj_set_style_bg\(\s*s_btn_cancel_cfg\s*,\s*pal_bg\s*,\s*255\s*\)' "${SRC}"; then
    run_test "s_btn_cancel_cfg: bg = pal_bg/255" "PASS"
else
    run_test "s_btn_cancel_cfg: bg = pal_bg/255" "FAIL"
fi

# A30. s_btn_cancel_cfg: text color = pal_text
if grep -qP 'tab5_ui_obj_set_style_text_color\(\s*s_btn_cancel_cfg\s*,\s*pal_text\s*,\s*255\s*\)' "${SRC}"; then
    run_test "s_btn_cancel_cfg: text_color = pal_text" "PASS"
else
    run_test "s_btn_cancel_cfg: text_color = pal_text" "FAIL"
fi

echo ""

# --- close_config_modal: limpeza ---
echo "--- A. Estática: close_config_modal limpeza ---"

# A31-A36. close_config_modal invalida os 6 handles
for handle in s_cfg_url s_cfg_token s_cfg_model s_cfg_max_tokens s_btn_save s_btn_cancel_cfg; do
    if grep -qP "${handle}\s*=\s*TAB5_UI_INVALID_OBJ" "${SRC}"; then
        run_test "close_config_modal invalida ${handle}" "PASS"
    else
        run_test "close_config_modal invalida ${handle}" "FAIL"
    fi
done

# A37. close_config_modal: s_modal size = 0x0
if grep -qP 'tab5_ui_obj_set_size\(\s*s_modal\s*,\s*0\s*,\s*0\s*\)' "${SRC}"; then
    run_test "close_config_modal: s_modal size = 0x0" "PASS"
else
    run_test "close_config_modal: s_modal size = 0x0" "FAIL"
fi

echo ""

# --- app_on_theme_changed: invalidação total ---
echo "--- A. Estática: app_on_theme_changed invalidação ---"

# A38-A43. app_on_theme_changed invalida todos os handles do modal
for handle in s_cfg_url s_cfg_token s_cfg_model s_cfg_max_tokens s_btn_save s_btn_cancel_cfg; do
    # Conta quantas vezes aparece — deve ter pelo menos 1 em app_on_theme_changed
    count=$(grep -cP "${handle}\s*=\s*TAB5_UI_INVALID_OBJ" "${SRC}" 2>/dev/null || true)
    if [ "${count}" -ge 2 ]; then
        run_test "app_on_theme_changed invalida ${handle} (mín 2 ocorrências no arquivo)" "PASS"
    else
        run_test "app_on_theme_changed invalida ${handle} (mín 2 ocorrências no arquivo)" "FAIL"
    fi
done

# A44. app_on_theme_changed: modal/backdrop/card invalidados
for handle in s_modal_backdrop s_modal_card; do
    count=$(grep -cP "${handle}\s*=\s*TAB5_UI_INVALID_OBJ" "${SRC}" 2>/dev/null || true)
    if [ "${count}" -ge 2 ]; then
        run_test "app_on_theme_changed invalida ${handle} (mín 2 ocorrências)" "PASS"
    else
        run_test "app_on_theme_changed invalida ${handle} (mín 2 ocorrências)" "FAIL"
    fi
done

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# B. Extração Python: corpos REAIS de open_config_modal / close_config_modal
#                    / app_on_theme_changed
# ─────────────────────────────────────────────────────────────────────────────
echo "--- B. Extração: corpos REAIS de funções modal ---"

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

def calls(body, fn):
    return re.findall(r"tab5_ui_obj_" + fn + r"\s*\(([^;]+)\)", body)

failures = 0
def require(condition, message):
    global failures
    if condition:
        print(f"  [PASS] {message}")
    else:
        print(f"  [FAIL] {message}")
        failures += 1

open_body = function_body("open_config_modal")
close_body = function_body("close_config_modal")
theme_body = function_body("app_on_theme_changed")
chat_body = function_body("build_chat_ui")

# ── open_config_modal ──
print("--- B1: open_config_modal (btns, backdrop, cfg_*) ---")

# btns container
require(re.search(r'btns\s*=\s*tab5_ui_container_create\s*\(\s*card\s*\)', open_body) is not None,
        "btns criado como filho de card (flex child)")
require(re.search(r'set_scrollable\(\s*btns\s*,\s*false\s*\)', open_body) is not None,
        "btns: set_scrollable(false) no corpo REAL")
require(re.search(r'set_flex_flow\(\s*btns\s*,\s*TAB5_UI_FLEX_FLOW_ROW\s*\)', open_body) is not None,
        "btns: FLEX_FLOW_ROW no corpo REAL")
require(re.search(r'set_size\(\s*btns\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*,\s*48\s*\)', open_body) is not None,
        "btns: PCT(100) x 48 no corpo REAL")

# backdrop
require(re.search(r's_modal_backdrop\s*=\s*tab5_ui_container_create\s*\(\s*s_modal\s*\)', open_body) is not None,
        "s_modal_backdrop criado como filho de s_modal")
require(re.search(r'set_style_bg\(\s*s_modal_backdrop\s*,\s*0x000000\s*,\s*170\s*\)', open_body) is not None,
        "backdrop: bg=0x000000/170 no corpo REAL")
require(re.search(r'set_scrollable\(\s*s_modal_backdrop\s*,\s*false\s*\)', open_body) is not None,
        "backdrop: set_scrollable(false) no corpo REAL (não captura swipe)")

# cfg_body (corpo de campos — plano aprovado compacto 2x2: NADA rola). O corpo
# contém as duas linhas da grade 2x2; os campos passam a ser filhos das células
# PCT(50) e o card deixa de ser o container rolável (altura automática).
require(re.search(r'cfg_body\s*=\s*tab5_ui_container_create\s*\(\s*card\s*\)', open_body) is not None,
        "cfg_body criado como filho de card (corpo de campos)")
require(re.search(r'set_scrollable\(\s*cfg_body\s*,\s*false\s*\)', open_body) is not None,
        "cfg_body: set_scrollable(false) (nenhum objeto do modal é rolável)")
require(not re.search(r'set_flex_grow\(\s*cfg_body\s*,\s*1\s*\)', open_body),
        "cfg_body: SEM flex_grow(1) (grade compacta 2x2 ocupa só o conteúdo)")

# Grade 2x2: duas linhas FLEX_ROW filhas de cfg_body, cada uma com 2 células
# PCT(50) (FLEX_COLUMN). Cada célula contém um rótulo + textarea do campo.
for row in ("row1", "row2"):
    require(re.search(rf'{row}\s*=\s*tab5_ui_container_create\s*\(\s*cfg_body\s*\)', open_body) is not None,
            f"{row} criado como filho de cfg_body (linha da grade 2x2)")
    require(re.search(rf'set_flex_flow\(\s*{row}\s*,\s*TAB5_UI_FLEX_FLOW_ROW\s*\)', open_body) is not None,
            f"{row}: FLEX_FLOW_ROW (dois campos lado a lado)")
    require(re.search(rf'set_scrollable\(\s*{row}\s*,\s*false\s*\)', open_body) is not None,
            f"{row}: set_scrollable(false)")

for cell in ("cell_url", "cell_token", "cell_model", "cell_max_tokens"):
    require(re.search(rf'{cell}\s*=\s*tab5_ui_container_create\s*\((?:row1|row2)\s*\)', open_body) is not None,
            f"{cell} criado como filho de row (célula PCT(50) da grade)")
    require(re.search(rf'set_size\(\s*{cell}\s*,\s*TAB5_UI_PCT\(\s*50\s*\)\s*,\s*TAB5_UI_SIZE_CONTENT\s*\)', open_body) is not None,
            f"{cell}: PCT(50) x SIZE_CONTENT (coluna da grade 2x2)")
    require(re.search(rf'set_flex_flow\(\s*{cell}\s*,\s*TAB5_UI_FLEX_FLOW_COLUMN\s*\)', open_body) is not None,
            f"{cell}: FLEX_FLOW_COLUMN (rótulo + textarea empilhados)")
    require(re.search(rf'set_scrollable\(\s*{cell}\s*,\s*false\s*\)', open_body) is not None,
            f"{cell}: set_scrollable(false)")

for cfg in ("s_cfg_url", "s_cfg_token", "s_cfg_model", "s_cfg_max_tokens"):
    cell = {"s_cfg_url": "cell_url", "s_cfg_token": "cell_token",
            "s_cfg_model": "cell_model", "s_cfg_max_tokens": "cell_max_tokens"}[cfg]
    require(re.search(rf'{cfg}\s*=\s*tab5_ui_textarea_create\s*\(\s*{cell}\s*\)', open_body) is not None,
            f"{cfg} criado como filho da célula {cell} (grade 2x2)")
    require(not re.search(rf'{cfg}\s*=\s*tab5_ui_textarea_create\s*\(\s*card\s*\)', open_body),
            f"{cfg} NÃO é mais filho de card (fora do corpo)")
    require(re.search(rf'set_scrollable\(\s*{cfg}\s*,\s*false\s*\)', open_body) is not None,
            f"{cfg}: set_scrollable(false) no corpo REAL (altura fixa 42)")

# password mode
require(re.search(r'set_password_mode\(\s*s_cfg_token\s*,\s*true\s*\)', open_body) is not None,
        "s_cfg_token: set_password_mode(true) no corpo REAL")

# T6: verificar o corpo real da função de produção, não uma réplica do layout.
require(re.search(r'tab5_ui_obj_set_scrollable\(\s*cfg_body\s*,\s*false\s*\)', open_body) is not None,
        "T6: cfg_body: set_scrollable(false) no corpo REAL (nada no modal rola)")
require(re.search(r'tab5_ui_obj_set_scrollable\(\s*s_modal_card\s*,\s*false\s*\)', open_body) is not None,
        "T6: s_modal_card: set_scrollable(false) no corpo REAL (card não rola)")
require(re.search(r'tab5_ui_obj_set_scrollable\(\s*btns\s*,\s*false\s*\)', open_body) is not None,
        "T6: btns: set_scrollable(false) no corpo REAL (linha de botões fixa)")

# botões
require(re.search(r's_btn_cancel_cfg\s*=\s*tab5_ui_btn_create\s*\(\s*btns\s*,', open_body) is not None,
        "s_btn_cancel_cfg criado como filho de btns")
require(re.search(r's_btn_save\s*=\s*tab5_ui_btn_create\s*\(\s*btns\s*,', open_body) is not None,
        "s_btn_save criado como filho de btns")
require(re.search(r'set_size\(\s*s_btn_cancel_cfg\s*,\s*TAB5_UI_PCT\(\s*50\s*\)\s*,\s*44\s*\)', open_body) is not None,
        "s_btn_cancel_cfg: PCT(50) x 44")
require(re.search(r'set_size\(\s*s_btn_save\s*,\s*TAB5_UI_PCT\(\s*50\s*\)\s*,\s*44\s*\)', open_body) is not None,
        "s_btn_save: PCT(50) x 44")

# build_chat_ui: s_modal criado e desabilitado o scroll (não captura swipe)
require(re.search(r's_modal\s*=\s*tab5_ui_container_create\s*\(\s*scr\s*\)', chat_body) is not None,
        "build_chat_ui REAL: s_modal criado como filho de scr")
require(re.search(r'set_scrollable\(\s*s_modal\s*,\s*false\s*\)', chat_body) is not None,
        "build_chat_ui REAL: s_modal -> set_scrollable(false) (modal não rola)")

print()

# ── close_config_modal ──
print("--- B2: close_config_modal (limpeza de handles) ---")

invalidated = re.findall(r'(\w+)\s*=\s*TAB5_UI_INVALID_OBJ', close_body)
for handle in ["s_cfg_url", "s_cfg_token", "s_cfg_model", "s_cfg_max_tokens",
               "s_btn_save", "s_btn_cancel_cfg", "s_modal_backdrop", "s_modal_card"]:
    require(handle in invalidated, f"close_config_modal invalida {handle}")

require(re.search(r'tab5_ui_obj_clean\(\s*s_modal\s*\)', close_body) is not None,
        "close_config_modal: tab5_ui_obj_clean(s_modal)")
require(re.search(r'tab5_ui_obj_set_size\(\s*s_modal\s*,\s*0\s*,\s*0\s*\)', close_body) is not None,
        "close_config_modal: s_modal size = 0x0")
require(re.search(r'tab5_ui_keyboard_hide\(\)', close_body) is not None,
        "close_config_modal: tab5_ui_keyboard_hide()")

print()

# ── app_on_theme_changed ──
print("--- B3: app_on_theme_changed (invalidação total modal) ---")

theme_invalidated = re.findall(r'(\w+)\s*=\s*TAB5_UI_INVALID_OBJ', theme_body)
for handle in ["s_cfg_url", "s_cfg_token", "s_cfg_model", "s_cfg_max_tokens",
               "s_btn_save", "s_btn_cancel_cfg", "s_modal_backdrop", "s_modal_card"]:
    require(handle in theme_invalidated, f"app_on_theme_changed invalida {handle}")

print()

print(f"=== EXTRAÇÃO (B): {'ALL PASSED' if failures == 0 else str(failures) + ' FAIL(s)'} ===")
sys.exit(1 if failures else 0)
PY
EXTRACT_RESULT=$?
set -e

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# C. Runtime C: réplica instrumentada do layout-alvo modal interior
# ─────────────────────────────────────────────────────────────────────────────
echo "--- C. Runtime: layout-alvo do modal interior ---"

cat > "${SCRIPT_DIR}/test_modal_interior_contract.c" << 'TESTEOF'
#include <stdio.h>
#include <string.h>
#include <stdbool.h>

#define TAB5_UI_PCT(percent) (-1000 - (percent))
#define TAB5_UI_FLEX_FLOW_ROW 1
#define TAB5_UI_FLEX_FLOW_COLUMN 0
#define TAB5_UI_ALIGN_TOP_LEFT 0
#define TAB5_UI_ALIGN_CENTER 1
#define TAB5_UI_INVALID_OBJ (-1)
#define TAB5_UI_SIZE_CONTENT (-1)

/* ── Registro de chamadas ── */
#define MAX_CALLS 128
static char  cf[MAX_CALLS][32];
static char  cn[MAX_CALLS][32];
static int   cv1[MAX_CALLS], cv2[MAX_CALLS], cv3[MAX_CALLS];
static int   cc = 0;

static void reset_calls(void) { cc = 0; }
static void rec(const char *fn, const char *name, int v1, int v2, int v3) {
    if (cc < MAX_CALLS) {
        snprintf(cf[cc], 32, "%s", fn);
        snprintf(cn[cc], 32, "%s", name);
        cv1[cc] = v1; cv2[cc] = v2; cv3[cc] = v3;
        cc++;
    }
}

#define SC(name, val)    rec("set_scrollable", (name), (val), 0, 0)
#define SS(name, w, h)   rec("set_size", (name), (w), (h), 0)
#define SA(name, a, x, y) rec("set_align", (name), (a), (x), (y))
#define SFL(name, f)     rec("set_flex_flow", (name), (f), 0, 0)
#define SP(name, p)      rec("set_pad", (name), (p), 0, 0)
#define SG(name, g)      rec("set_gap", (name), (g), 0, 0)
#define SBG(name, c, o)  rec("set_style_bg", (name), (c), (o), 0)
#define SBR(name, c, w_) rec("set_style_border", (name), (c), (w_), 0)
#define SR(name, r)      rec("set_style_radius", (name), (r), 0, 0)
#define STC(name, c, o)  rec("set_style_text_color", (name), (c), (o), 0)

static int has(const char *fn, const char *name, int v1) {
    for (int i = 0; i < cc; i++)
        if (strcmp(cf[i], fn) == 0 && strcmp(cn[i], name) == 0 && cv1[i] == v1)
            return 1;
    return 0;
}
static int has2(const char *fn, const char *name, int v1, int v2) {
    for (int i = 0; i < cc; i++)
        if (strcmp(cf[i], fn) == 0 && strcmp(cn[i], name) == 0 && cv1[i] == v1 && cv2[i] == v2)
            return 1;
    return 0;
}

static int failures = 0;
static void check(int c, const char *m) {
    if (c) printf("  [PASS] %s\n", m);
    else   { printf("  [FAIL] %s\n", m); failures++; }
}

/* ── Réplica do layout-alvo: open_config_modal (elementos interiores) ── */
static void tgt_open_config_modal(void) {
    /* s_modal: inativo 0x0, não rolável, pad/bg/border/radius = 0 */
    SS("s_modal", 0, 0);
    SC("s_modal", false);
    SP("s_modal", 0);
    SBG("s_modal", 0, 0);
    SBR("s_modal", 0, 0);
    SR("s_modal", 0);

    /* backdrop: PCT(100) x PCT(100), TOP_LEFT(0,0), bg 0x000000/170,
       não rolável (não captura swipe) */
    SS("s_modal_backdrop", TAB5_UI_PCT(100), TAB5_UI_PCT(100));
    SA("s_modal_backdrop", TAB5_UI_ALIGN_TOP_LEFT, 0, 0);
    SC("s_modal_backdrop", false);
    SBG("s_modal_backdrop", 0x000000, 170);
    SBR("s_modal_backdrop", 0, 0);
    SR("s_modal_backdrop", 0);
    SP("s_modal_backdrop", 0);

    /* card: PCT(96) x SIZE_CONTENT (altura automática — nada rola), CENTER */
    SS("s_modal_card", TAB5_UI_PCT(96), TAB5_UI_SIZE_CONTENT);
    SA("s_modal_card", TAB5_UI_ALIGN_CENTER, 0, 0);
    SC("s_modal_card", false);

    /* cfg_body: corpo de campos — NÃO rolável, FLEX_COLUMN, gap 10 */
    SC("cfg_body", false);
    SFL("cfg_body", TAB5_UI_FLEX_FLOW_COLUMN);
    SG("cfg_body", 10);
    SS("cfg_body", TAB5_UI_PCT(100), TAB5_UI_SIZE_CONTENT);

    /* Grade 2x2: row1/row2 → cell_* → textarea */
    SS("row1", TAB5_UI_PCT(100), TAB5_UI_SIZE_CONTENT);
    SFL("row1", TAB5_UI_FLEX_FLOW_ROW);
    SG("row1", 0);
    SC("row1", false);
    SS("row2", TAB5_UI_PCT(100), TAB5_UI_SIZE_CONTENT);
    SFL("row2", TAB5_UI_FLEX_FLOW_ROW);
    SG("row2", 0);
    SC("row2", false);

    SS("cell_url", TAB5_UI_PCT(50), TAB5_UI_SIZE_CONTENT);
    SFL("cell_url", TAB5_UI_FLEX_FLOW_COLUMN);
    SG("cell_url", 4);
    SC("cell_url", false);
    SS("cell_token", TAB5_UI_PCT(50), TAB5_UI_SIZE_CONTENT);
    SFL("cell_token", TAB5_UI_FLEX_FLOW_COLUMN);
    SG("cell_token", 4);
    SC("cell_token", false);
    SS("cell_model", TAB5_UI_PCT(50), TAB5_UI_SIZE_CONTENT);
    SFL("cell_model", TAB5_UI_FLEX_FLOW_COLUMN);
    SG("cell_model", 4);
    SC("cell_model", false);
    SS("cell_max_tokens", TAB5_UI_PCT(50), TAB5_UI_SIZE_CONTENT);
    SFL("cell_max_tokens", TAB5_UI_FLEX_FLOW_COLUMN);
    SG("cell_max_tokens", 4);
    SC("cell_max_tokens", false);

    /* cfg_*: PCT(100) x 42, não roláveis */
    SS("s_cfg_url", TAB5_UI_PCT(100), 42);
    SC("s_cfg_url", false);
    SS("s_cfg_token", TAB5_UI_PCT(100), 42);
    SC("s_cfg_token", false);
    SS("s_cfg_model", TAB5_UI_PCT(100), 42);
    SC("s_cfg_model", false);
    SS("s_cfg_max_tokens", TAB5_UI_PCT(100), 42);
    SC("s_cfg_max_tokens", false);

    /* btns: PCT(100) x 48, scrollable=false, FLEX_ROW, pad=0, gap=0 */
    SS("btns", TAB5_UI_PCT(100), 48);
    SC("btns", false);
    SFL("btns", TAB5_UI_FLEX_FLOW_ROW);
    SP("btns", 0);
    SG("btns", 0);
    SBG("btns", 0, 0);
    SBR("btns", 0, 0);

    /* botões: PCT(50) x 44 */
    SS("s_btn_cancel_cfg", TAB5_UI_PCT(50), 44);
    SS("s_btn_save", TAB5_UI_PCT(50), 44);
    SBG("s_btn_save", 1, 255);  /* pal_accent, 255 */
    STC("s_btn_save", 0xFFFFFF, 255);
    SBG("s_btn_cancel_cfg", 0, 255);  /* pal_bg, 255 */
    STC("s_btn_cancel_cfg", 3, 255);  /* pal_text, 255 */
}

/* ── close_config_modal: verificado na parte B (extração), que garante a
   invalidação dos 8 handles e o retorno do s_modal a 0x0. */

int main(void) {
    printf("=== Modal Interior Contract — Runtime ===\n\n");

    /* ── T1: btns layout ── */
    printf("T1: btns container\n");
    reset_calls();
    tgt_open_config_modal();
    check(has("set_size", "btns", TAB5_UI_PCT(100)) &&
          has2("set_size", "btns", TAB5_UI_PCT(100), 48),
          "btns: PCT(100) x 48");
    check(has("set_scrollable", "btns", false),
          "btns: scrollable = false");
    check(has("set_flex_flow", "btns", TAB5_UI_FLEX_FLOW_ROW),
          "btns: FLEX_FLOW_ROW");
    check(has("set_pad", "btns", 0),
          "btns: pad = 0");
    check(has("set_gap", "btns", 0),
          "btns: gap = 0 (PCT(50)+PCT(50) sem overflow)");
    check(has2("set_style_bg", "btns", 0, 0),
          "btns: bg = 0/opacity = 0");
    printf("\n");

    /* ── T2: backdrop ── */
    printf("T2: s_modal_backdrop\n");
    reset_calls();
    tgt_open_config_modal();
    check(has2("set_size", "s_modal_backdrop", TAB5_UI_PCT(100), TAB5_UI_PCT(100)),
          "backdrop: PCT(100) x PCT(100)");
    check(has("set_align", "s_modal_backdrop", TAB5_UI_ALIGN_TOP_LEFT),
          "backdrop: TOP_LEFT");
    check(has2("set_style_bg", "s_modal_backdrop", 0x000000, 170),
          "backdrop: bg = 0x000000/170");
    check(has("set_style_border", "s_modal_backdrop", 0),
          "backdrop: border = 0");
    check(has("set_style_radius", "s_modal_backdrop", 0),
          "backdrop: radius = 0");
    check(has("set_pad", "s_modal_backdrop", 0),
          "backdrop: pad = 0");
    check(has("set_scrollable", "s_modal_backdrop", false),
          "backdrop: scrollable = false (não captura swipe)");
    printf("\n");

    /* ── T3: s_cfg_* ── */
    printf("T3: s_cfg_* textareas\n");
    reset_calls();
    tgt_open_config_modal();
    check(has2("set_size", "s_cfg_url", TAB5_UI_PCT(100), 42),
          "s_cfg_url: PCT(100) x 42");
    check(has2("set_size", "s_cfg_token", TAB5_UI_PCT(100), 42),
          "s_cfg_token: PCT(100) x 42");
    check(has2("set_size", "s_cfg_model", TAB5_UI_PCT(100), 42),
          "s_cfg_model: PCT(100) x 42");
    check(has2("set_size", "s_cfg_max_tokens", TAB5_UI_PCT(100), 42),
          "s_cfg_max_tokens: PCT(100) x 42");
    check(has("set_scrollable", "s_cfg_url", false) &&
          has("set_scrollable", "s_cfg_token", false) &&
          has("set_scrollable", "s_cfg_model", false) &&
          has("set_scrollable", "s_cfg_max_tokens", false),
          "4 campos s_cfg_*: scrollable = false (altura fixa 42)");
    printf("\n");

    /* ── T4: botões de ação ── */
    printf("T4: botões cancelar/salvar\n");
    reset_calls();
    tgt_open_config_modal();
    check(has2("set_size", "s_btn_cancel_cfg", TAB5_UI_PCT(50), 44),
          "s_btn_cancel_cfg: PCT(50) x 44");
    check(has2("set_size", "s_btn_save", TAB5_UI_PCT(50), 44),
          "s_btn_save: PCT(50) x 44");
    check(has2("set_style_bg", "s_btn_save", 1, 255),
          "s_btn_save: bg = pal_accent/255");
    check(has2("set_style_text_color", "s_btn_save", 0xFFFFFF, 255),
          "s_btn_save: text = 0xFFFFFF");
    check(has("set_style_bg", "s_btn_cancel_cfg", 0) && cv2[cc-1] == 255,
          "s_btn_cancel_cfg: bg = pal_bg/255");
    printf("\n");

    /* ── T5: s_modal inativo ── */
    printf("T5: s_modal (inativo)\n");
    reset_calls();
    tgt_open_config_modal();
    check(has2("set_size", "s_modal", 0, 0),
          "s_modal: size = 0x0 (inativo)");
    check(has("set_pad", "s_modal", 0),
          "s_modal: pad = 0");
    check(has2("set_style_bg", "s_modal", 0, 0),
          "s_modal: bg = 0/0");
    check(has("set_style_border", "s_modal", 0),
          "s_modal: border = 0");
    check(has("set_style_radius", "s_modal", 0),
          "s_modal: radius = 0");
    check(has("set_scrollable", "s_modal", false),
          "s_modal: scrollable = false (não captura swipe fora do card)");
    printf("\n");

    /* ── T6: regressão — NADA no modal é rolável (grade 2x2 compacta) ── */
    printf("T6: regressão — cfg_body=false em todos os objetos modal\n");
    reset_calls();
    tgt_open_config_modal();
    check(has("set_scrollable", "cfg_body", false),
          "cfg_body: scrollable = false (nenhum objeto do modal rola)");
    check(has2("set_size", "s_modal_card", TAB5_UI_PCT(96), TAB5_UI_SIZE_CONTENT),
          "s_modal_card: PCT(96) x SIZE_CONTENT (altura automática — nada rola)");
    check(has("set_scrollable", "row1", false) && has("set_scrollable", "row2", false),
          "row1/row2: scrollable = false (linhas da grade 2x2)");
    check(has("set_scrollable", "cell_url", false) &&
          has("set_scrollable", "cell_token", false) &&
          has("set_scrollable", "cell_model", false) &&
          has("set_scrollable", "cell_max_tokens", false),
          "4 células cell_*: scrollable = false (grade 2x2)");
    check(has("set_scrollable", "s_modal", false) &&
          has("set_scrollable", "s_modal_backdrop", false),
          "s_modal e s_modal_backdrop: scrollable = false (não capturam gesto)");
    check(has("set_scrollable", "s_modal_card", false),
          "s_modal_card: scrollable = false (card não rola)");
    check(has("set_scrollable", "btns", false),
          "btns: scrollable = false (linha de botões fixa)");
    check(has("set_scrollable", "s_cfg_url", false) &&
          has("set_scrollable", "s_cfg_token", false) &&
          has("set_scrollable", "s_cfg_model", false) &&
          has("set_scrollable", "s_cfg_max_tokens", false),
          "4 campos s_cfg_*: scrollable = false (o único scrollable(true) do arquivo é s_messages_cont)");

    printf("\n=== Modal Interior Runtime: %s (failures=%d) ===\n",
           failures ? "FAILED" : "ALL PASSED", failures);
    return failures ? 1 : 0;
}
TESTEOF

echo "[INFO] Compilando teste de contrato do modal interior..."
if gcc -std=c11 -Wall -Wextra -o "${OUT_DIR}/test_modal_interior_contract" \
       "${SCRIPT_DIR}/test_modal_interior_contract.c" 2>&1; then
    echo "[INFO] Executando teste de contrato do modal interior..."
    set +e
    "${OUT_DIR}/test_modal_interior_contract"
    RUNTIME_RESULT=$?
    set -e
    echo ""
else
    echo "[FAIL] Teste de contrato do modal interior falhou ao compilar"
    RUNTIME_RESULT=1
fi
rm -f "${SCRIPT_DIR}/test_modal_interior_contract.c"

# ─────────────────────────────────────────────────────────────────────────────
# Veredito
# ─────────────────────────────────────────────────────────────────────────────
STATIC_RESULT=0
if [ "${FAIL}" -gt 0 ] || [ "${EXTRACT_RESULT}" -ne 0 ]; then
    STATIC_RESULT=1
fi

echo ""
echo "=== Modal Interior Contract: resumo ==="
echo "  A. Estática (greps src/main.c):     ${PASS} passed, ${FAIL} failed, ${TOTAL} total"
echo "  B. Extração (corpos reais):         $([ ${EXTRACT_RESULT} -eq 0 ] && echo OK || echo FALHOU)"
echo "  C. Runtime (layout-alvo):           $([ ${RUNTIME_RESULT} -eq 0 ] && echo OK || echo FALHOU)"

if [ ${STATIC_RESULT} -ne 0 ]; then
    echo ""
    echo "[FAIL] Contrato do modal interior NÃO satisfeito"
    exit 1
fi
exit ${RUNTIME_RESULT}
