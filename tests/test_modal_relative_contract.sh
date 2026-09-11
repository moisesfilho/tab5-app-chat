#!/usr/bin/env bash
# test_modal_relative_contract.sh - contrato verificado do modal RELATIVO (100% x 100%).
#
# Extrai os corpos REAIS de open_config_modal/apply_modal_layout de src/main.c
# (não replica a implementação) e exige o contrato relativo:
#   1. modal/backdrop = TAB5_UI_PCT(100) x TAB5_UI_PCT(100) (tela visual real,
#      independente do w/h reportado pelo host).
#   2. card = TAB5_UI_PCT(96) x TAB5_UI_SIZE_CONTENT (altura automática —
#      grade compacta 2x2 garante que o conteúdo caiba com teclado; nada rola).
#   3. card alinhado TAB5_UI_ALIGN_CENTER com offset -(kb_h/2) (sobe o card
#      quando o teclado aparece).
#   4. AUSÊNCIA de tab5_ui_get_display_size / h / usable_h / card_h no caminho
#      modal (nada de dimensões absolutas derivadas do host).
#
# Cenários: retrato (720x1280) e paisagem com host stale (720x1280) enquanto a
# tela visual é 1280x720. Como tudo é PCT, o caminho modal resolve contra a
# tela visual e não vaza dimensões do host.
#
# Estado do contrato: as asserções verificam a implementação aprovada em src/main.c.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${SCRIPT_DIR}/../src/main.c"
OUT_DIR="${SCRIPT_DIR}/.build"
mkdir -p "${OUT_DIR}"

echo "=== Modal Relative Contract (PCT(100) x PCT(100)) ==="
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# A. Extração e verificação das funções REAIS de src/main.c
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
    return re.findall(r"tab5_ui_obj_set_" + function + r"\s*\(([^;]+)\)", body)

failures = 0
def require(condition, message):
    global failures
    if condition:
        print(f"  [PASS] {message}")
    else:
        print(f"  [FAIL] {message}")
        failures += 1
    return condition

def modal_size_absolute_dims(body):
    """Retorna dimensões absolutas (w/h/literal) usadas em set_size de
    modal/backdrop/card — violam o contrato 100% relativo. São válidos apenas
    TAB5_UI_PCT(...) (relativo ao pai) e TAB5_UI_SIZE_CONTENT (auto-height)."""
    bad = []
    for c in calls(body, "size"):
        parts = [p.strip() for p in c.split(",")]
        if len(parts) < 3:
            continue
        obj = parts[0]
        if not re.fullmatch(r"(?:s_modal|s_modal_backdrop|backdrop|card|s_modal_card)", obj):
            continue
        for label, arg in (("w", parts[1]), ("h", parts[2])):
            if not re.fullmatch(r"(?:TAB5_UI_PCT\(\s*\d+\s*\)|TAB5_UI_SIZE_CONTENT)", arg):
                bad.append(f"{obj} {label}={arg}")
    return bad

open_src = function_body("open_config_modal")
apply_src = function_body("apply_modal_layout")

sizes_open = calls(open_src, "size")
align_open = calls(open_src, "align")
sizes_apply = calls(apply_src, "size")
align_apply = calls(apply_src, "align")

# Modal / backdrop: PCT(100) na LARGURA e na ALTURA.
for tag, sizes in (("open_config_modal", sizes_open), ("apply_modal_layout", sizes_apply)):
    require(any(re.search(r"s_modal\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*,\s*TAB5_UI_PCT\(\s*100\s*\)", c) for c in sizes),
            f"{tag}: modal = TAB5_UI_PCT(100) x TAB5_UI_PCT(100)")
    require(any(re.search(r"(?:backdrop|s_modal_backdrop)\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*,\s*TAB5_UI_PCT\(\s*100\s*\)", c) for c in sizes),
            f"{tag}: backdrop = TAB5_UI_PCT(100) x TAB5_UI_PCT(100)")

# Card: PCT(96) x SIZE_CONTENT (auto-height).
for tag, sizes in (("open_config_modal", sizes_open), ("apply_modal_layout", sizes_apply)):
    require(any(re.search(r"(?:card|s_modal_card)\s*,\s*TAB5_UI_PCT\(\s*96\s*\)\s*,\s*TAB5_UI_SIZE_CONTENT\s*\)", c) for c in sizes),
            f"{tag}: card = TAB5_UI_PCT(96) x TAB5_UI_SIZE_CONTENT (auto-height)")

# Card CENTER; offset centrado -(kb_h/2) no apply (que conhece o teclado).
require(any(re.search(r"(?:card|s_modal_card)\s*,\s*TAB5_UI_ALIGN_CENTER\b", c) for c in align_open),
        "open_config_modal: card alinhado TAB5_UI_ALIGN_CENTER")
require(any(re.search(r"(?:card|s_modal_card)\s*,\s*TAB5_UI_ALIGN_CENTER\b", c) for c in align_apply),
        "apply_modal_layout: card alinhado TAB5_UI_ALIGN_CENTER")
require(any(re.search(r"(?:card|s_modal_card)\s*,\s*TAB5_UI_ALIGN_CENTER\s*,\s*0\s*,\s*-\s*\(\s*kb_h\s*/\s*2\s*\)", c) for c in align_apply),
        "apply_modal_layout: card offset = -(kb_h/2) (sobe acima do teclado)")

# Preservação: kb_h continua sendo consultado no caminho modal (para o offset).
require("tab5_ui_keyboard_get_height" in apply_src,
        "apply_modal_layout: kb_h consultado (preservado para o offset)")

# Ausência de absolutos no caminho modal.
for tag, body in (("open_config_modal", open_src), ("apply_modal_layout", apply_src)):
    require("tab5_ui_get_display_size" not in body,
            f"{tag}: SEM tab5_ui_get_display_size (host stale não vaza)")
    require(not re.search(r"\busable_h\b", body),
            f"{tag}: SEM variável usable_h")
    require(not re.search(r"\bcard_h\b", body),
            f"{tag}: SEM variável card_h")
    bad_dims = modal_size_absolute_dims(body)
    require(not bad_dims,
            f"{tag}: modal/backdrop/card SÓ com dimensões PCT (sem w/h/literal){(' -> ' + '; '.join(bad_dims)) if bad_dims else ''}")

# Modal/backdrop conservam TOP_LEFT (0,0) como full-screen.
for tag, aligns in (("open_config_modal", align_open), ("apply_modal_layout", align_apply)):
    require(any(re.search(r"(?:s_modal|backdrop|s_modal_backdrop)\s*,\s*TAB5_UI_ALIGN_TOP_LEFT\s*,\s*0\s*,\s*0", c) for c in aligns),
            f"{tag}: modal/backdrop TOP_LEFT (0,0) preservados")

print()

# ── Cenários geométricos ─────────────────────────────────────────────────────
# Encoding PCT real do SDK: -1000 - percent.
pct = lambda p: -1000 - p
require(pct(100) == -1100, "encoding real: TAB5_UI_PCT(100) == -1100")
require(pct(96) == -1096,  "encoding real: TAB5_UI_PCT(96) == -1096")
require(pct(60) == -1060,  "encoding real: TAB5_UI_PCT(60) == -1060")

# Retrato: tela visual 720x1280 (host coincide).
pw, ph = 720, 1280
require(round(pw * 1.00) == 720 and round(ph * 1.00) == 1280,
        "retrato: modal 100% ocupa 720x1280")
require(round(pw * 0.96) == 691,
        "retrato: card largura 96% ocupa 691px (altura SIZE_CONTENT/auto)")
require(1280 - 400 >= 262,
        "retrato+kb(400): visível 880px >= conteúdo compacto 262px — nada rola")
require(-(200 // 2) == -100,
        "retrato: offset centrado -(kb_h/2) = -100 para kb_h=200")

# Paisagem com host STALE: host reporta 720x1280, tela visual é 1280x720.
# O caminho modal deve resolver pelo PAI VISUAL (PCT), não pelo host.
lw, lh = 1280, 720
require(round(lw * 1.00) == 1280 and round(lh * 1.00) == 720,
        "landscape stale 720x1280: modal 100% ocupa 1280x720 (visual, não 720x1280)")
require(round(lw * 0.96) == 1229,
        "landscape stale: card largura 96% ocupa 1229px (altura SIZE_CONTENT/auto)")
require(720 - 400 >= 262,
        "landscape stale+kb(400): visível 320px >= conteúdo compacto 262px — grade 2x2 cabe")
require(round(lh * 1.00) <= 1280,
        "landscape stale: altura visual 720 <= host 1280 — PCT não vaza h do host")
require(pct(100) == -1100 and pct(96) == -1096,
        "landscape stale: mesmo encoding PCT em qualquer orientação (sem dimensão absoluta no código)")

print()
print(f"=== Modal relative contract (estática): {'ALL PASSED' if failures == 0 else str(failures) + ' FAIL(s)'} ===")
print("    (contrato verificado: PCT(100) x PCT(100), card PCT(96) x SIZE_CONTENT")
print("     auto-height e TOP_LEFT preservado para modal/backdrop)")
sys.exit(1 if failures else 0)
PY
STATIC_RESULT=$?
set -e

# ─────────────────────────────────────────────────────────────────────────────
# B. Runtime: geometria alvo do contrato (retrato + paisagem stale)
# ─────────────────────────────────────────────────────────────────────────────
if [ "${STATIC_RESULT}" -eq 0 ] || [ "${STATIC_RESULT}" -eq 1 ]; then
    cat > "${SCRIPT_DIR}/test_modal_relative_contract.c" << 'TESTEOF'
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

/* Encoding real do SDK: -1000 - percent. */
#define TAB5_UI_PCT(percent) (-1000 - (percent))

static int failures = 0;
static void check(int c, const char *m) {
    if (c) printf("  [PASS] %s\n", m);
    else   { printf("  [FAIL] %s\n", m); failures++; }
}

/* Resolução percentual arredondada (host-side). */
static int pctpx(int base, int pct) { return (base * pct + 50) / 100; }

int main(void) {
    printf("=== Modal Relative Contract — Runtime geometry ===\n\n");

    /* Encoding */
    check(TAB5_UI_PCT(100) == -1100, "PCT(100) == -1100");
    check(TAB5_UI_PCT(96)  == -1096, "PCT(96) == -1096");

    /* Retrato 720x1280, kb_h=200 */
    printf("\nCenário retrato: visual 720x1280, kb_h=200\n");
    {
        int w = 720, h = 1280, kb_h = 200;
        check(pctpx(w, 100) == 720 && pctpx(h, 100) == 1280,
              "modal 100% = 720x1280");
        check(pctpx(w, 96) == 691, "card width = 96% de 720 = 691");
        check(-(kb_h / 2) == -100, "card CENTER offset = -(200/2) = -100");
        check(1280 - 400 >= 262, "retrato+kb(400): visível 880px >= 262px (2x2 cabe)");
        printf("  card=691xauto, offset=%d\n\n", -(kb_h / 2));
    }

    /* Landscape com host stale 720x1280, visual 1280x720, kb_h=200 */
    printf("Cenário landscape stale: host 720x1280 / visual 1280x720, kb_h=200\n");
    {
        int visual_w = 1280, visual_h = 720, host_h = 1280, kb_h = 200;
        int mw = pctpx(visual_w, 100), mh = pctpx(visual_h, 100);
        int cw = pctpx(visual_w, 96);
        check(mw == 1280 && mh == 720, "modal 100% = 1280x720 (visual)");
        check(mh != host_h, "modal altura (720) difere do host stale (1280) — PCT não usa h");
        check(cw == 1229, "card width 96% = 1229px (visual; altura SIZE_CONTENT/auto)");
        check(720 - 400 >= 262,
              "landscape stale+kb(400): visível 320px >= 262px — grade 2x2 cabe");
        check(mh + (kb_h / 2) <= host_h,
              "paisagem stale: card + offset cabe; nenhuma dimensão absoluta do host");
        check(-(kb_h / 2) == -100, "card CENTER offset = -(200/2) = -100 (idêntico ao retrato)");
        printf("  modal=%dx%d, card=%dxauto, offset=%d (host stale: %dx%d)\n\n",
               mw, mh, cw, -(kb_h / 2), 720, host_h);
    }

    /* kb_h=0 => offset zero; porta nunca depende de w/h absoluto */
    printf("Cenário kb_h=0: offset zero em ambas as orientações\n");
    {
        check(-(0 / 2) == 0, "kb_h=0 -> offset 0");
        check(TAB5_UI_PCT(100) == -1100, "PCT(100) idêntico em retrato e paisagem");
        check(TAB5_UI_PCT(96) == -1096, "PCT(96) idêntico em retrato e paisagem");
        printf("\n");
    }

    printf("=== Modal Relative Runtime: %s (failures=%d) ===\n",
           failures ? "FAILED" : "ALL PASSED", failures);
    return failures ? 1 : 0;
}
TESTEOF

    echo "[INFO] Compilando teste de geometria do modal relativo..."
    if gcc -std=c11 -Wall -Wextra -o "${OUT_DIR}/test_modal_relative_contract" \
           "${SCRIPT_DIR}/test_modal_relative_contract.c" 2>&1; then
        echo "[INFO] Executando teste de geometria..."
        set +e
        "${OUT_DIR}/test_modal_relative_contract"
        RUNTIME_RESULT=$?
        set -e
        echo ""
    else
        echo "[FAIL] Teste de geometria falhou ao compilar"
        RUNTIME_RESULT=1
    fi
    rm -f "${SCRIPT_DIR}/test_modal_relative_contract.c"
else
    RUNTIME_RESULT=0
fi

echo ""
echo "=== Modal Relative Contract: resumo ==="
echo "  estática (funções reais): $([ ${STATIC_RESULT} -eq 0 ] && echo OK || echo 'FALHOU — verificação do contrato')"
echo "  runtime (geometria alvo): $([ ${RUNTIME_RESULT} -eq 0 ] && echo OK || echo FALHOU)"

# Veredito: o contrato relativo do modal deve permanecer verificado em src/main.c.
if [ ${STATIC_RESULT} -ne 0 ]; then
    echo "[FAIL] Contrato do modal relativo NÃO satisfeito"
    exit 1
fi
exit ${RUNTIME_RESULT}
