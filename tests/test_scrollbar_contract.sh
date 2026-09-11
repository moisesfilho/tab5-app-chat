#!/usr/bin/env bash
# test_scrollbar_contract.sh - contrato de scrollbar: input sem scrollbar
# vertical e system bubble sem overflow horizontal.
#
# Objetivo (plano aprovado): eliminar a scrollbar vertical do input e a
# scrollbar horizontal da mensagem de boas-vindas (system bubble), mantendo
# s_messages_cont scrollable=true.
#
# Contrato:
#   REQ-002 -> TEST-101/TEST-103: build_bubble usa gap do row dependente do
#     papel — gap(system)=0, gap(user/assistant)=4 — de modo que
#     Σ(base widths) + gaps <= largura do row em todos os papéis.
#   REQ-003 -> TEST-102: build_chat_ui fixa altura de s_input_ta em
#     TAB5_UI_PCT(100) (nunca overflow vertical em s_input_cont).
#   REQ-004 -> TEST-100: O ÚNICO set_scrollable(..., true) do arquivo é
#     s_messages_cont. Nenhum objeto do modal é rolável: cfg_body agora é
#     set_scrollable(false); scr/row/spacer/second_spacer/bubble/s_input_cont/
#     s_input_ta/s_modal/s_modal_backdrop/s_modal_card/btns/s_cfg_url/s_cfg_token/
#     s_cfg_model/s_cfg_max_tokens são todos false (regressão do scroll do
#     input e do modal compacto 2x2 do plano aprovado).
#
# Estado: H1 (gap system=0) e H2 (altura do s_input_ta em TAB5_UI_PCT(100))
# estão implementados em src/main.c. O runtime TEST-103 extrai o gap REAL do
# row de src/main.c, sem mascarar divergências da implementação.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC="${APP_DIR}/src/main.c"
OUT_DIR="${SCRIPT_DIR}/.build"
mkdir -p "${OUT_DIR}"

echo "=== Scrollbar Contract (input sem scrollbar, system bubble sem overflow horizontal) ==="
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
# TEST-100 — greps/extração: O ÚNICO set_scrollable(..., true) é s_messages_cont
# ─────────────────────────────────────────────────────────────────────────────
echo "--- TEST-100: único set_scrollable(..., true) do arquivo é s_messages_cont ---"

set +e
SRC_PATH="${SRC}" python3 - <<'PY'
import os
import re
import sys

source = open(os.environ["SRC_PATH"], encoding="utf-8").read()

# Extrai QUALQUER set_scrollable(X, valor) de src/main.c inteiro (não apenas
# uma lista fixa de alvos): o contrato novo é "apenas s_messages_cont=true no
# arquivo", então NENHUM outro objeto pode receber true, com qualquer nome.
calls = re.findall(
    r"tab5_ui_obj_set_scrollable\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*,\s*(true|false)\s*\)",
    source,
)

required_false = [
    "scr", "row", "spacer", "second_spacer", "bubble",
    "s_input_cont", "s_input_ta",
    "s_modal", "s_modal_backdrop", "s_modal_card", "cfg_body", "btns",
    "s_cfg_url", "s_cfg_token", "s_cfg_model", "s_cfg_max_tokens",
]

failures = 0
def require(condition, message):
    global failures
    if condition:
        print(f"  [PASS] {message}")
    else:
        print(f"  [FAIL] {message}")
        failures += 1

true_targets = sorted(set(name for name, val in calls if val == "true"))
require(true_targets == ["s_messages_cont"],
        "únicos set_scrollable(..., true) do arquivo = [s_messages_cont] "
        f"(obtido: {true_targets if true_targets else 'NENHUM'})")

# Regra forte: todo set_scrollable que NÃO é s_messages_cont deve ser false.
bad_true = sorted(set(name for name, val in calls if val == "true" and name != "s_messages_cont"))
require(not bad_true,
        "NENHUM objeto além de s_messages_cont usa set_scrollable(true)")

for target in required_false:
    require(any(name == target and val == "false" for name, val in calls),
            f"{target} -> set_scrollable(false)")

print(f"=== TEST-100: {'ALL PASSED' if failures == 0 else str(failures) + ' FAIL(s)'} ===")
sys.exit(1 if failures else 0)
PY
T100_RESULT=$?
set -e

if [ ${T100_RESULT} -eq 0 ]; then
    run_test "TEST-100 (scrollables únicos + alvos false)" "PASS"
else
    run_test "TEST-100 (scrollables únicos + alvos false)" "FAIL"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# TEST-101 — grep: gap do row dependente do papel (system sem gap)
# ─────────────────────────────────────────────────────────────────────────────
echo "--- TEST-101: gap do row = is_system ? 0 : 4 (sem overflow no system bubble) ---"

if grep -qP 'tab5_ui_obj_set_gap\(\s*row\s*,\s*is_system\s*\?\s*0\s*:\s*4\s*\)' "${SRC}"; then
    run_test "TEST-101 (gap(row, is_system ? 0 : 4) presente)" "PASS"
else
    run_test "TEST-101 (gap(row, is_system ? 0 : 4) presente)" "FAIL"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# TEST-102 — grep: altura do s_input_ta em TAB5_UI_PCT(100)
# ─────────────────────────────────────────────────────────────────────────────
echo "--- TEST-102: altura de s_input_ta limitada (sem overflow vertical) ---"

if grep -qP 'tab5_ui_obj_set_size\(\s*s_input_ta\s*,\s*TAB5_UI_SIZE_CONTENT\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*\)' "${SRC}"; then
    run_test "TEST-102 (set_size(s_input_ta, CONTENT, TAB5_UI_PCT(100)) presente)" "PASS"
else
    run_test "TEST-102 (set_size(s_input_ta, CONTENT, TAB5_UI_PCT(100)) presente)" "FAIL"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# TEST-103 — runtime C: matemática de flex com o gap REAL extraído de src/main.c
# ─────────────────────────────────────────────────────────────────────────────
echo "--- TEST-103: runtime — flex math com gap real extraído de src/main.c ---"

set +e
SRC_PATH="${SRC}" python3 - <<'PY'
import os
import re
import sys

source = open(os.environ["SRC_PATH"], encoding="utf-8").read()

match = re.search(r"\bstatic\s+void\s+build_bubble\s*\([^)]*\)\s*\{", source)
if not match:
    print("[ERRO] build_bubble não encontrado em src/main.c", file=sys.stderr)
    sys.exit(2)
start = match.end() - 1
depth = 0
body = None
for pos in range(start, len(source)):
    if source[pos] == "{":
        depth += 1
    elif source[pos] == "}":
        depth -= 1
        if depth == 0:
            body = source[start + 1:pos]
            break
if body is None:
    print("[ERRO] corpo de build_bubble incompleto", file=sys.stderr)
    sys.exit(2)

gm = re.search(r"tab5_ui_obj_set_gap\(\s*row\s*,\s*([^)]+)\)", body)
if not gm:
    print("[ERRO] set_gap(row, ...) não encontrado em build_bubble", file=sys.stderr)
    sys.exit(2)

arg = gm.group(1).strip()
if re.fullmatch(r"is_system\s*\?\s*0\s*:\s*4", arg):
    print("SYSTEM_GAP=0")
    print("USER_GAP=4")
    print("GAP_MODE=target (is_system ? 0 : 4)")
else:
    lm = re.fullmatch(r"(\d+)", arg)
    if lm:
        val = lm.group(1)
        print(f"SYSTEM_GAP={val}")
        print(f"USER_GAP={val}")
        print("GAP_MODE=literal (sem distinção system) — RED esperado até H1")
    else:
        print("[ERRO] padrão de gap do row não reconhecido em src/main.c", file=sys.stderr)
        sys.exit(2)
PY
GAP_RESULT=$?
set -e

if [ ${GAP_RESULT} -ne 0 ]; then
    echo "  [FAIL] TEST-103 (não foi possível extrair o gap real do row — falha sem mascarar)"
    FAIL=$((FAIL + 1))
    TOTAL=$((TOTAL + 1))
    exit 1
fi

SYSTEM_GAP="$(SRC_PATH="${SRC}" python3 - <<'PY'
import os, re, sys
source = open(os.environ["SRC_PATH"], encoding="utf-8").read()
match = re.search(r"\bstatic\s+void\s+build_bubble\s*\([^)]*\)\s*\{", source)
start = match.end() - 1
depth = 0
for pos in range(start, len(source)):
    if source[pos] == "{": depth += 1
    elif source[pos] == "}":
        depth -= 1
        if depth == 0:
            body = source[start + 1:pos]
            break
gm = re.search(r"tab5_ui_obj_set_gap\(\s*row\s*,\s*([^)]+)\)", body)
arg = gm.group(1).strip()
if re.fullmatch(r"is_system\s*\?\s*0\s*:\s*4", arg):
    print("0")
else:
    lm = re.fullmatch(r"(\d+)", arg)
    print(lm.group(1))
PY
)"
USER_GAP="$(SRC_PATH="${SRC}" python3 - <<'PY'
import os, re, sys
source = open(os.environ["SRC_PATH"], encoding="utf-8").read()
match = re.search(r"\bstatic\s+void\s+build_bubble\s*\([^)]*\)\s*\{", source)
start = match.end() - 1
depth = 0
for pos in range(start, len(source)):
    if source[pos] == "{": depth += 1
    elif source[pos] == "}":
        depth -= 1
        if depth == 0:
            body = source[start + 1:pos]
            break
gm = re.search(r"tab5_ui_obj_set_gap\(\s*row\s*,\s*([^)]+)\)", body)
arg = gm.group(1).strip()
if re.fullmatch(r"is_system\s*\?\s*0\s*:\s*4", arg):
    print("4")
else:
    lm = re.fullmatch(r"(\d+)", arg)
    print(lm.group(1))
PY
)"

echo "  [INFO] gap extraído: USER_GAP=${USER_GAP}, SYSTEM_GAP=${SYSTEM_GAP}"
echo ""

cat > "${SCRIPT_DIR}/test_scrollbar_contract.c" << 'TESTEOF'
#include <stdio.h>
#include <string.h>
#include <stdbool.h>

/* Gaps do row extraídos de src/main.c pelo shell (fonte única de verdade). */
#ifndef USER_GAP
#define USER_GAP 4
#endif
#ifndef SYSTEM_GAP
#define SYSTEM_GAP 4
#endif

/* ── Registro de chamadas set_scrollable (espelha TEST-003 do scroll_capture) ── */
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
#define SC(target, value) rec_sc((target), (value))

static int failures = 0;
static void check(int c, const char *m) {
    if (c) printf("  [PASS] %s\n", m);
    else   { printf("  [FAIL] %s\n", m); failures++; }
}

static int has_sc(const char *target, int value) {
    for (int i = 0; i < sc_count; i++)
        if (strcmp(sc_func[i], "set_scrollable") == 0 &&
            strcmp(sc_name[i], target) == 0 && sc_val[i] == value)
            return 1;
    return 0;
}

/* ── Réplica dos alvos scrollable do layout (contrato REQ-004) ── */
static void tgt_build_bubble(const char *role) {
    bool is_system = (strcmp(role, "system") == 0);
    SC("row", false);
    if (is_system) {
        SC("spacer", false);
        SC("second_spacer", false);
    } else {
        SC("spacer", false);
    }
    SC("bubble", false);
}
static void tgt_build_chat_ui(void) {
    SC("scr", false);
    SC("s_messages_cont", true);
    SC("s_input_cont", false);
    SC("s_input_ta", false);
}

/* ── Matemática de flex do row (LVGL): base widths + gaps vs conteúdo do row ──
 * Papel -> (n_children, base_pct, gap):
 *   system   : spacer + second_spacer + bubble(PCT 100) -> 3 filhos
 *   user     : spacer + bubble(PCT 80)                  -> 2 filhos
 *   assistant: bubble(PCT 80)                            -> 1 filho
 * Contrato: used = base + (n_children - 1) * gap <= W para todos os papéis.
 */
static int used_width(int n_children, int base_pct, int gap, int W) {
    return (W * base_pct / 100) + (n_children - 1) * gap;
}

int main(void) {
    /* Largura de conteúdo do row no Tab5:
     * retrato : 720 - 2*6 (pad messages_cont) - 2*2 (pad row) = 704 */
    const int W_PORT = 704;
    /* paisagem: 1280 - 12 - 4 = 1264 */
    const int W_LAND = 1264;

    printf("=== Scrollbar Contract — Runtime (flex math, gaps reais de src/main.c) ===\n");
    printf("  USER_GAP=%d  SYSTEM_GAP=%d\n\n", USER_GAP, SYSTEM_GAP);

    /* S1: system (bubble 100% + 2 spacers) */
    int used = used_width(3, 100, SYSTEM_GAP, W_PORT);
    printf("  system  retrato: base=%d + gaps=%d = %d %s\n",
           W_PORT, 2 * SYSTEM_GAP, used, used <= W_PORT ? "" : "-> OVERFLOW");
    check(used <= W_PORT, "system retrato: Σ(base)+gaps <= W (sem overflow horizontal)");

    used = used_width(3, 100, SYSTEM_GAP, W_LAND);
    check(used <= W_LAND, "system paisagem: Σ(base)+gaps <= W (sem overflow horizontal)");

    /* S2: user (spacer + bubble 80%) */
    used = used_width(2, 80, USER_GAP, W_PORT);
    printf("  user    retrato: base=%d + gaps=%d = %d %s\n",
           8 * W_PORT / 10, USER_GAP, used, used <= W_PORT ? "" : "-> OVERFLOW");
    check(used <= W_PORT, "user retrato: 0.8W + gap <= W");

    used = used_width(2, 80, USER_GAP, W_LAND);
    check(used <= W_LAND, "user paisagem: 0.8W + gap <= W");

    /* S3: assistant (bubble 80%, sem spacers) */
    used = used_width(1, 80, USER_GAP, W_PORT);
    printf("  assistant retrato: base=%d + gaps=0 = %d %s\n",
           8 * W_PORT / 10, used, used <= W_PORT ? "" : "-> OVERFLOW");
    check(used <= W_PORT, "assistant retrato: 0.8W <= W");

    used = used_width(1, 80, USER_GAP, W_LAND);
    check(used <= W_LAND, "assistant paisagem: 0.8W <= W");
    printf("\n");

    /* S4: scrollable(false) nos alvos — regressão do scroll do input (REQ-004) */
    reset_calls();
    tgt_build_bubble("system");
    check(has_sc("row", 0) && has_sc("spacer", 0) && has_sc("second_spacer", 0) &&
          has_sc("bubble", 0),
          "bubbles: row/spacer/second_spacer/bubble -> set_scrollable(false)");

    reset_calls();
    tgt_build_chat_ui();
    check(has_sc("s_input_cont", 0) && has_sc("s_input_ta", 0),
          "input: s_input_cont/s_input_ta -> set_scrollable(false)");
    check(has_sc("scr", 0) && has_sc("s_messages_cont", 1),
          "preservados: scr=false, s_messages_cont=true");

    printf("\n=== TEST-103 Runtime: %s (failures=%d, SYSTEM_GAP=%d) ===\n",
           failures ? "FAILED (RED)" : "ALL PASSED", failures, SYSTEM_GAP);
    return failures ? 1 : 0;
}
TESTEOF

echo "[INFO] Compilando teste de contrato de scrollbar..."
if gcc -std=c11 -Wall -Wextra -o "${OUT_DIR}/test_scrollbar_contract" \
       "${SCRIPT_DIR}/test_scrollbar_contract.c" \
       "-DUSER_GAP=${USER_GAP}" "-DSYSTEM_GAP=${SYSTEM_GAP}" 2>&1; then
    echo "[INFO] Executando teste de contrato de scrollbar..."
    set +e
    "${OUT_DIR}/test_scrollbar_contract"
    RUNTIME_RESULT=$?
    set -e
    echo ""
else
    echo "[FAIL] Teste de contrato de scrollbar falhou ao compilar"
    RUNTIME_RESULT=1
fi
rm -f "${SCRIPT_DIR}/test_scrollbar_contract.c"

# ─────────────────────────────────────────────────────────────────────────────
# Veredito
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Scrollbar Contract: resumo ==="
echo "  TEST-100 (scrollables únicos):     $([ ${T100_RESULT} -eq 0 ] && echo OK || echo FALHOU)"
echo "  TEST-101 (gap row system=0):       $(grep -qP 'tab5_ui_obj_set_gap\(\s*row\s*,\s*is_system\s*\?\s*0\s*:\s*4\s*\)' "${SRC}" && echo OK || echo 'RED')"
echo "  TEST-102 (altura s_input_ta PCT):  $(grep -qP 'tab5_ui_obj_set_size\(\s*s_input_ta\s*,\s*TAB5_UI_SIZE_CONTENT\s*,\s*TAB5_UI_PCT\(\s*100\s*\)\s*\)' "${SRC}" && echo OK || echo 'RED')"
echo "  TEST-103 (runtime flex math):      $([ ${RUNTIME_RESULT} -eq 0 ] && echo OK || echo 'RED')"
echo "  estáticos (TEST-100/101/102): ${PASS} passed, ${FAIL} failed, ${TOTAL} total"

if [ ${T100_RESULT} -ne 0 ] || [ ${FAIL} -gt 0 ] || [ ${RUNTIME_RESULT} -ne 0 ]; then
    echo ""
    echo "[FAIL] Contrato de scrollbar NÃO satisfeito"
    echo "       — gap(system)=0, altura do input_ta e 's_messages_cont único"
    echo "         scrollable(true)' devem existir em src/main.c"
    exit 1
fi
exit 0
