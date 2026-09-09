#!/usr/bin/env bash
# test_host_display_size_vs_lvgl.sh
# Contrato: tab5_ui_host_get_display_size vs a SEMÂNTICA OBSERVADA no host Tab5.
#
# CONTEXTO / POR QUE NÃO-TAUTOLÓGICO:
#   A versão anterior deste teste assumia que os getters LÓGICOS do LVGL 9 eram
#   a fonte canônica (rotacionavam 0/90/180/270). O diagnóstico do host mostrou
#   que, na plataforma M5Stack Tab5, a semântica observada é OUTRA:
#
#     * getters LÓGICOS (lv_display_get_horizontal/vertical_resolution):
#       NÃO rotacionam — retornam sempre 720x1280 (resolução com que o display
#       foi criado, BSP_LCD_H_RES=720, BSP_LCD_V_RES=1280), mesmo em paisagem.
#     * getters FÍSICOS (lv_display_get_physical_horizontal/vertical_resolution):
#       ROTACIONAM — a rotação é aplicada no caminho físico/panel:
#         ROT_0/180  -> 720x1280
#         ROT_90/270 -> 1280x720
#
#   Contrato derivado da semântica observada:
#     tab5_ui_host_get_display_size DEVE retornar A RESOLUÇÃO FÍSICA
#     (orientada) diretamente, SEM swap manual adicional (double swap).
#
#   Implementação que usa getters lógicos (implementação ATUAL do host) devolve
#   720x1280 para TODAS as rotações -> layout em retrato num LCD em paisagem.
#   Implementação com double swap (físicos + swap manual) devolve 720x1280 nas
#   rotações 90/270 -> mesmo bug.
#
#   O teste aceita SOMENTE a implementação físico-sem-swap:
#     1. Estaticamente: lê os getters físicos direto na fonte real do host
#        (tab5-os/components/os/runtime/tab5_ui_host.cpp) e rejeita getters
#        lógicos e any branch de rotação/swap.
#     2. Comportamentalmente: extrai o corpo REAL da função e compila contra um
#        mock fiel da semântica observada (lógicos fixos 720x1280, físicos
#        rotacionados), validando as 4 rotações + null-safety + ausência de
#        double swap.
#     3. Validação do próprio espec: test_host_display_size_vs_lvgl.c prova que
#        a correção passa e que as duas implementações bugadas são rejeitadas.
#
# AC: Para cada rotação, o host REAL deve retornar a resolução física orientada
#     (720x1280 em 0/180; 1280x720 em 90/270), sem double swap, sem null crash.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/.build"
mkdir -p "${OUT_DIR}"

echo "=== Host Display Size vs Semântica Observada (LVGL físico/panel) ==="
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 1. Localizar a fonte REAL de produção.
#    Se não achar, falha alto — o teste PRECISA inspecionar o código real.
# ─────────────────────────────────────────────────────────────────────────────
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CANDIDATES=(
    "${TAB5_OS_ROOT:-}/components/os/runtime/tab5_ui_host.cpp"
    "${REPO_ROOT}/../tab5-os/components/os/runtime/tab5_ui_host.cpp"
    "${REPO_ROOT}/../../tab5-os/components/os/runtime/tab5_ui_host.cpp"
    "${REPO_ROOT}/tab5-os/components/os/runtime/tab5_ui_host.cpp"
    "${HOME}/Projetos/tab5/tab5-os/components/os/runtime/tab5_ui_host.cpp"
    "${TAB5_OS_SRC:-}/components/os/runtime/tab5_ui_host.cpp"
)

HOST_SRC=""
for cand in "${CANDIDATES[@]}"; do
    if [ -f "${cand}" ]; then
        HOST_SRC="${cand}"
        break
    fi
done

if [ -z "${HOST_SRC}" ]; then
    echo "[FAIL] Não foi possível localizar a fonte de produção tab5_ui_host.cpp."
    echo "       Defina TAB5_OS_ROOT ou TAB5_OS_SRC para o repositório tab5-os."
    echo "       Buscado em:"
    for cand in "${CANDIDATES[@]}"; do
        echo "         ${cand}"
    done
    echo "       Sem a fonte real o teste de contrato seria tautológico."
    exit 1
fi

echo "[INFO] Fonte de produção: ${HOST_SRC}"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 2. Extrair o corpo REAL da função (verbatim).
# ─────────────────────────────────────────────────────────────────────────────
PYEXTRACT=$(cat << 'PYEOF'
import sys
path, fn = sys.argv[1], sys.argv[2]
with open(path, encoding='utf-8', errors='replace') as fh:
    lines = fh.read().split('\n')
out = []
capture = False
depth = 0
for ln in lines:
    s = ln.strip()
    if not capture and s.startswith(fn + '('):
        capture = True
    if capture:
        out.append(ln)
        depth += s.count('{') - s.count('}')
        if depth <= 0 and len(out) > 1:
            break
if not out:
    sys.stderr.write("FUNCTION_NOT_FOUND\n")
    sys.exit(1)
sys.stdout.write('\n'.join(out))
PYEOF
)

if ! FUNC_TEXT="$(python3 - "${HOST_SRC}" "void tab5_ui_host_get_display_size" <<< "${PYEXTRACT}")"; then
    echo "[FAIL] Não foi possível extrair tab5_ui_host_get_display_size de ${HOST_SRC}."
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# 3. Inspeção estática da função real (contrato da semântica observada).
# ─────────────────────────────────────────────────────────────────────────────
STATIC_OK=1
note() { echo "  $1"; }

echo "─── Inspeção estática da função REAL tab5_ui_host_get_display_size ───"

if grep -q "lv_display_get_physical_horizontal_resolution" <<< "${FUNC_TEXT}"; then
    note "[PASS] fonte chama lv_display_get_physical_horizontal_resolution"
else
    note "[FAIL] fonte NÃO chama lv_display_get_physical_horizontal_resolution"; STATIC_OK=0
fi

if grep -q "lv_display_get_physical_vertical_resolution" <<< "${FUNC_TEXT}"; then
    note "[PASS] fonte chama lv_display_get_physical_vertical_resolution"
else
    note "[FAIL] fonte NÃO chama lv_display_get_physical_vertical_resolution"; STATIC_OK=0
fi

# Semântica observada: getters LÓGICOS não rotacionam (720x1280 fixo). Usá-los
# como fonte do tamanho devolve retrato em todas as rotações (bug atual).
# Os nomes exatos não são substring dos físicos (get_physical_*),
# portanto o grep abaixo só pega o uso dos LÓGICOS.
if grep -qE "lv_display_get_horizontal_resolution|lv_display_get_vertical_resolution" <<< "${FUNC_TEXT}"; then
    note "[FAIL] fonte usa getters LÓGICOS (não rotacionam nesta plataforma) como fonte"; STATIC_OK=0
else
    note "[PASS] fonte NÃO usa getters lógicos como fonte"
fi

# Double swap: qualquer branch de rotação indicando swap manual das dimensões.
if grep -qE "LV_DISPLAY_ROTATION_(90|270)|LV_DISPLAY_ROTATION_" <<< "${FUNC_TEXT}"; then
    note "[FAIL] fonte contém branch de rotação/swap manual (double swap)"; STATIC_OK=0
else
    note "[PASS] fonte não contém swap manual de rotação"
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 4. Compilar a função REAL extraída contra mock fiel da semântica observada.
# ─────────────────────────────────────────────────────────────────────────────
# A fonte de produção é C++ (nullptr), então compilamos com g++.
CPP_FILE="${OUT_DIR}/test_host_display_size_vs_lvgl_real.cpp"
BIN_FILE="${OUT_DIR}/test_host_display_size_vs_lvgl_real"

{
    cat > "${CPP_FILE}" << 'CPPEOF'
#include <cstdint>
#include <cstdio>
/* Painel nativo (BSP_LCD_H_RES x BSP_LCD_V_RES). */
static int32_t s_hor_res = 720;
static int32_t s_ver_res = 1280;
enum { ROT_0 = 0, ROT_90, ROT_180, ROT_270 };
static int s_rotation = ROT_0;
extern "C" void mock_set_rotation(int r) { s_rotation = r; }

/* Semântica observada: LÓGICOS não rotacionam (sempre resolução de criação). */
extern "C" int32_t lv_display_get_horizontal_resolution(void*) { return s_hor_res; }
extern "C" int32_t lv_display_get_vertical_resolution(void*) { return s_ver_res; }

/* Semântica observada: FÍSICOS rotacionam (rotação no caminho físico/panel). */
extern "C" int32_t lv_display_get_physical_horizontal_resolution(void*) {
    return (s_rotation == ROT_90 || s_rotation == ROT_270) ? s_ver_res : s_hor_res;
}
extern "C" int32_t lv_display_get_physical_vertical_resolution(void*) {
    return (s_rotation == ROT_90 || s_rotation == ROT_270) ? s_hor_res : s_ver_res;
}
#define HAVE_LVGL 1
/* Função REAL de produção, extraída verbatim pelo harness: */
CPPEOF
    printf '%s\n' "${FUNC_TEXT}" >> "${CPP_FILE}"
    cat >> "${CPP_FILE}" << 'CPPEOF'
static int failures = 0;
static int passes = 0;
static void check(int cond, const char *msg) {
    if (cond) { printf("  [PASS] %s\n", msg); passes++; }
    else      { printf("  [FAIL] %s\n", msg); failures++; }
}
int main(void) {
    struct Case { int rot; const char *name; int ew; int eh; };
    const struct Case rot_cases[4] = {
        { ROT_0,   "0",   720, 1280 },
        { ROT_90,  "90",  1280, 720 },
        { ROT_180, "180", 720, 1280 },
        { ROT_270, "270", 1280, 720 },
    };

    /* Cobertura da semântica observada dos 4 getters × 4 rotações. */
    printf("─── Semântica observada dos getters (mock) ───\n");
    for (int i = 0; i < 4; i++) {
        mock_set_rotation(rot_cases[i].rot);
        char msg[128];
        snprintf(msg, sizeof(msg), "rot%s: LOGICAL (%dx%d) == 720x1280 (não rotaciona)",
                 rot_cases[i].name, (int)lv_display_get_horizontal_resolution(nullptr),
                 (int)lv_display_get_vertical_resolution(nullptr));
        check(lv_display_get_horizontal_resolution(nullptr) == 720 &&
              lv_display_get_vertical_resolution(nullptr) == 1280, msg);
        snprintf(msg, sizeof(msg), "rot%s: PHYSICAL (%dx%d) == esperado %dx%d",
                 rot_cases[i].name, (int)lv_display_get_physical_horizontal_resolution(nullptr),
                 (int)lv_display_get_physical_vertical_resolution(nullptr),
                 rot_cases[i].ew, rot_cases[i].eh);
        check(lv_display_get_physical_horizontal_resolution(nullptr) == rot_cases[i].ew &&
              lv_display_get_physical_vertical_resolution(nullptr) == rot_cases[i].eh, msg);
    }
    printf("\n");

    /* Contrato comportamental: host == getters físicos (sem double swap). */
    printf("─── Comportamento da função REAL × contrato físico ───\n");
    for (int i = 0; i < 4; i++) {
        mock_set_rotation(rot_cases[i].rot);
        int32_t w = 0, h = 0;
        tab5_ui_host_get_display_size(&w, &h);
        char msg[128];
        printf("Rotação %s\n", rot_cases[i].name);
        snprintf(msg, sizeof(msg), "%s: host.w (%d) == esperado (%d) [físico orientado]",
                 rot_cases[i].name, (int)w, rot_cases[i].ew);
        check(w == rot_cases[i].ew, msg);
        snprintf(msg, sizeof(msg), "%s: host.h (%d) == esperado (%d) [físico orientado]",
                 rot_cases[i].name, (int)h, rot_cases[i].eh);
        check(h == rot_cases[i].eh, msg);
        /* Ausência de double swap: host == getter físico direto. */
        snprintf(msg, sizeof(msg), "%s: host == getters físicos sem swap adicional",
                 rot_cases[i].name);
        check(w == lv_display_get_physical_horizontal_resolution(nullptr) &&
              h == lv_display_get_physical_vertical_resolution(nullptr), msg);
        printf("\n");
    }

    /* Null-safety e null parcial. */
    printf("─── Null-safety ───\n");
    printf("Rotação 90 para null parcial\n");
    mock_set_rotation(ROT_90);
    tab5_ui_host_get_display_size(nullptr, nullptr);
    check(1, "ambos NULL: retorna sem crash");
    int32_t only_w = -1;
    tab5_ui_host_get_display_size(&only_w, nullptr);
    check(only_w == 1280, "null parcial (só largura) ROT90: w == 1280");
    int32_t only_h = -1;
    tab5_ui_host_get_display_size(nullptr, &only_h);
    check(only_h == 720, "null parcial (só altura) ROT90: h == 720");
    printf("\n");

    printf("═══════════════════════════════════════════════════════════════\n");
    printf("  Resultados: %s  (pass=%d, fail=%d)\n",
           failures ? "FAILED" : "ALL PASSED", passes, failures);
    printf("═══════════════════════════════════════════════════════════════\n");
    return failures ? 1 : 0;
}
CPPEOF
}

echo "─── Compilando snippet REAL extraído (g++) ───"

if g++ -std=c++11 -Wall -Wextra -o "${BIN_FILE}" "${CPP_FILE}" 2>&1; then
    echo "[INFO] Executando teste comportamental do snippet REAL..."
    set +e
    "${BIN_FILE}"
    BEHAVIOR_RESULT=$?
    set -e
    echo ""
else
    echo "[FAIL] Snippet real falhou ao compilar"
    BEHAVIOR_RESULT=1
fi

# ─────────────────────────────────────────────────────────────────────────────
# 5. Validação do espec: test_host_display_size_vs_lvgl.c
#    Prova que a correção (físico-sem-swap) passa e que as duas implementações
#    bugadas (lógicos; físico+double swap) são rejeitadas. Self-contained.
# ─────────────────────────────────────────────────────────────────────────────
SPEC_BIN="${OUT_DIR}/test_host_display_size_vs_lvgl_spec"
echo "─── Espec de discriminação (test_host_display_size_vs_lvgl.c) ───"
if gcc -std=c11 -Wall -Wextra -o "${SPEC_BIN}" "${SCRIPT_DIR}/test_host_display_size_vs_lvgl.c" 2>&1; then
    set +e
    "${SPEC_BIN}"
    SPEC_RESULT=$?
    set -e
    echo ""
else
    echo "[FAIL] Espec de discriminação falhou ao compilar"
    SPEC_RESULT=1
fi

# ─────────────────────────────────────────────────────────────────────────────
# 6. Veredito final: estática + comportamento + espec precisam passar.
# ─────────────────────────────────────────────────────────────────────────────
echo "─── Resumo ───"
if [ "${STATIC_OK}" -eq 0 ]; then
    echo "[FAIL] Inspeção estática da fonte real encontrou violações de contrato."
fi
if [ "${BEHAVIOR_RESULT}" -ne 0 ]; then
    echo "[FAIL] Teste comportamental do snippet real encontrou violações (ver acima)."
fi
if [ "${SPEC_RESULT}" -ne 0 ]; then
    echo "[FAIL] Espec de discriminação não validou (ver acima)."
fi

rm -f "${CPP_FILE}"

if [ "${STATIC_OK}" -eq 0 ] || [ "${BEHAVIOR_RESULT}" -ne 0 ] || [ "${SPEC_RESULT}" -ne 0 ]; then
    echo ""
    echo "[FAIL] O contrato da semântica observada NÃO é satisfeito pela implementação real."
    echo "       Contrato esperado: lv_display_get_physical_horizontal/vertical_resolution SEM swap manual."
    echo "       Implementação atual (getters lógicos) devolve 720x1280 em todas as rotações."
    exit 1
fi

echo ""
echo "[PASS] O contrato da semântica observada valida contra a implementação REAL."
exit 0