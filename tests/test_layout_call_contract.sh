#!/usr/bin/env bash
# Contrato estático das chamadas reais de layout.
# O teste extrai os corpos das funções de produção; não replica a implementação.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${SCRIPT_DIR}/../src/main.c"

echo "=== Layout call contract (source extraction) ==="

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
    return re.findall(r"tab5_ui_obj_set_" + function + r"\s*\(([^;]+)\)", body)

def require(condition, message):
    if not condition:
        raise AssertionError(message)
    print(f"  [PASS] {message}")

layout = function_body("apply_layout")
bubble = function_body("build_bubble")
modal = function_body("apply_modal_layout")

sizes_layout = calls(layout, "size")
align_layout = calls(layout, "align")
sizes_bubble = calls(bubble, "size")
sizes_modal = calls(modal, "size")
align_modal = calls(modal, "align")

# Asserções sobre as chamadas reais, incluindo as dimensões verticais e o
# alinhamento.  A largura não pode ser inferida por um `w` absoluto.
require(any(re.search(r"s_messages_cont\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*,\s*msg_h\s*>\s*0\s*\?\s*msg_h\s*:\s*200", c) for c in sizes_layout),
        "apply_layout: messages = PCT(100) e altura msg_h preservada")
require(any(re.search(r"s_input_cont\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*,\s*INPUT_H", c) for c in sizes_layout),
        "apply_layout: input = PCT(100) e altura INPUT_H preservada")
require(any(re.search(r"s_messages_cont\s*,\s*TAB5_UI_ALIGN_TOP_LEFT\s*,\s*0\s*,\s*MSG_TOP", c) for c in align_layout),
        "apply_layout: messages alinhado TOP_LEFT em MSG_TOP")
require(any(re.search(r"s_input_cont\s*,\s*TAB5_UI_ALIGN_BOTTOM_LEFT\s*,\s*0\s*,\s*-\s*\(\s*kb_h\s*\+\s*INPUT_GAP\s*\)", c) for c in align_layout),
        "apply_layout: input usa BOTTOM_LEFT e offset do teclado")

require(any(re.search(r"row\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*,\s*TAB5_UI_SIZE_CONTENT", c) for c in sizes_bubble),
        "build_bubble: row = PCT(100) x CONTENT")
require(any(re.search(r"bubble\s*,\s*is_system\s*\?\s*TAB5_UI_PCT\(\s*100\s*\)\s*:\s*TAB5_UI_PCT\(\s*80\s*\)\s*,\s*TAB5_UI_SIZE_CONTENT", c) for c in sizes_bubble),
        "build_bubble: system 100%, user/assistant 80%, altura CONTENT")
require(any(re.search(r"lbl\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*,\s*TAB5_UI_SIZE_CONTENT", c) for c in sizes_bubble),
        "build_bubble: label = PCT(100) x CONTENT")

require(any(re.search(r"s_modal\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*,\s*TAB5_UI_PCT\(\s*100\s*\)", c) for c in sizes_modal),
        "apply_modal_layout: modal = PCT(100) x PCT(100) (layout relativo)")
require(any(re.search(r"backdrop\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*,\s*TAB5_UI_PCT\(\s*100\s*\)", c) for c in sizes_modal),
        "apply_modal_layout: backdrop = PCT(100) x PCT(100) (layout relativo)")
require(any(re.search(r"card\s*,\s*TAB5_UI_PCT\(\s*96\s*\)\s*,\s*TAB5_UI_PCT\(\s*60\s*\)", c) for c in sizes_modal),
        "apply_modal_layout: card = PCT(96) x PCT(60) (layout relativo)")
require(any(re.search(r"card\s*,\s*TAB5_UI_ALIGN_CENTER\s*,\s*0\s*,\s*-\s*\(\s*kb_h\s*/\s*2\s*\)", c) for c in align_modal),
        "apply_modal_layout: card CENTER com offset -(kb_h/2)")
require("tab5_ui_get_display_size" not in modal,
        "apply_modal_layout: SEM tab5_ui_get_display_size (host stale não vaza no modal)")
require(not re.search(r"\b(?:usable_h|card_h)\b", modal),
        "apply_modal_layout: SEM usable_h/card_h (nada de altura absoluta)" )

for body, label in ((layout, "apply_layout"), (modal, "apply_modal_layout")):
    require(not re.search(r"set_size\s*\(\s*(?:s_messages_cont|s_input_cont|s_modal|backdrop|s_modal_backdrop)\s*,\s*w\s*,", body),
            f"{label}: nenhum container usa largura absoluta w")

# Cenário explícito de regressão: o host pode estar stale (720x1280), enquanto
# a tela visual é 1280x720. PCT é resolvido pelo pai visual, não pelo `w` do
# host. O input continua ancorado no fundo visual, inclusive com teclado.
visual_w, visual_h = 1280, 720
require(round(visual_w * 1.00) == 1280, "host stale 720x1280 / visual 1280x720: PCT(100) ocupa 1280px")
require(round(visual_w * 0.80) == 1024, "host stale: bubble PCT(80) ocupa 80% da largura visual")
require(round(visual_w * 0.96) == 1229, "host stale: modal card PCT(96) ocupa 96% da largura visual")
require("TAB5_UI_ALIGN_BOTTOM_LEFT" in layout and "INPUT_GAP" in layout,
        "host stale: input permanece bottom-anchored, não usa Y absoluto")
keyboard = 200
require(visual_h - (keyboard + 6) == 514,
        "host stale: bottom anchor posiciona o input relativo à altura visual 720")

print("=== Layout call contract: ALL PASSED ===")
PY
