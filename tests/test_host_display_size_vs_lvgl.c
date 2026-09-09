#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>

/* ══════════════════════════════════════════════════════════════════════
 *  SEMÂNTICA OBSERVADA no host Tab5 (diagnóstico; ver
 *  .opencode/memory/tab5-chat-display-size.md)
 * ══════════════════════════════════════════════════════════════════════
 *
 * Painel nativo (BSP): BSP_LCD_H_RES=720, BSP_LCD_V_RES=1280. O display
 * LVGL é criado com 720x1280 e NUNCA recebe lv_display_set_physical_resolution
 * (default -1).
 *
 * Observação de campo (bug 1280x720 capturado com layout em retrato):
 *   - Getters LÓGICOS (lv_display_get_horizontal/vertical_resolution):
 *       NÃO rotacionam. Retornam SEMPRE 720x1280, mesmo com o LCD em
 *       paisagem. A rotação é aplicada no caminho físico/panel.
 *   - Getters FÍSICOS (lv_display_get_physical_horizontal/vertical_resolution):
 *       rotacionam. ROT_0/180 -> 720x1280; ROT_90/270 -> 1280x720.
 *
 * CONTRATO:
 *   tab5_ui_host_get_display_size DEVE retornar a resolução FÍSICA
 *   orientada, lendo os getters físicos diretamente e SEM swap manual.
 *
 *   Este teste prova que o contrato aceita SOMENTE essa implementação:
 *     A) impl_physical_no_swap      → comportamento correto (PASS esperado)
 *     B) impl_logical_no_swap       → bug atual do host (FALHA em 90/270)
 *     C) impl_physical_double_swap  → bug histórico (FALHA em 90/270)
 *
 * Cobertura: getters lógico/físico × rotações 0/90/180/270, null-safety
 * (NULL total e parcial) e ausência de double swap.
 * ══════════════════════════════════════════════════════════════════════ */

#define PANEL_H_RES 720
#define PANEL_V_RES 1280

typedef enum {
    ROT_0   = 0,
    ROT_90  = 1,
    ROT_180 = 2,
    ROT_270 = 3,
} rotation_t;

/* ── Estado do mock (painel nativo) ── */
static int32_t s_hor_res = PANEL_H_RES;
static int32_t s_ver_res = PANEL_V_RES;
static rotation_t s_rotation = ROT_0;

static void mock_set_rotation(rotation_t rot) { s_rotation = rot; }

/* ── Semântica observada: LÓGICOS não rotacionam ── */
static int32_t lv_display_get_horizontal_resolution(void *d) {
    (void)d;
    return s_hor_res;
}
static int32_t lv_display_get_vertical_resolution(void *d) {
    (void)d;
    return s_ver_res;
}

/* ── Semântica observada: FÍSICOS rotacionam (caminho físico/panel) ── */
static int32_t lv_display_get_physical_horizontal_resolution(void *d) {
    (void)d;
    return (s_rotation == ROT_90 || s_rotation == ROT_270) ? s_ver_res : s_hor_res;
}
static int32_t lv_display_get_physical_vertical_resolution(void *d) {
    (void)d;
    return (s_rotation == ROT_90 || s_rotation == ROT_270) ? s_hor_res : s_ver_res;
}

/* ══════════════════════════════════════════════════════════════════════
 *  Implementações candidatas
 * ══════════════════════════════════════════════════════════════════════ */

/* A) Correção planejada: getters FÍSICOS, SEM swap manual. */
static void impl_physical_no_swap(int32_t *out_w, int32_t *out_h)
{
    if (out_w == NULL && out_h == NULL) {
        return;
    }
    int32_t w = lv_display_get_physical_horizontal_resolution(NULL);
    int32_t h = lv_display_get_physical_vertical_resolution(NULL);
    if (out_w != NULL) {
        *out_w = w;
    }
    if (out_h != NULL) {
        *out_h = h;
    }
}

/* B) Implementação ATUAL do host: getters LÓGICOS, sem swap.
 *    Na semântica observada, retorna 720x1280 para todas as rotações. */
static void impl_logical_no_swap(int32_t *out_w, int32_t *out_h)
{
    if (out_w == NULL && out_h == NULL) {
        return;
    }
    int32_t w = lv_display_get_horizontal_resolution(NULL);
    int32_t h = lv_display_get_vertical_resolution(NULL);
    if (out_w != NULL) {
        *out_w = w;
    }
    if (out_h != NULL) {
        *out_h = h;
    }
}

/* C) Bug histórico: getters FÍSICOS + swap manual (double swap). */
static void impl_physical_double_swap(int32_t *out_w, int32_t *out_h)
{
    if (out_w == NULL && out_h == NULL) {
        return;
    }
    int32_t w = lv_display_get_physical_horizontal_resolution(NULL);
    int32_t h = lv_display_get_physical_vertical_resolution(NULL);
    if (s_rotation == ROT_90 || s_rotation == ROT_270) {
        int32_t tmp = w;
        w = h;
        h = tmp;
    }
    if (out_w != NULL) {
        *out_w = w;
    }
    if (out_h != NULL) {
        *out_h = h;
    }
}

/* ══════════════════════════════════════════════════════════════════════
 *  Assertions
 * ══════════════════════════════════════════════════════════════════════ */
static int failures = 0;
static int passes = 0;

static void check(int cond, const char *msg) {
    if (cond) {
        printf("  [PASS] %s\n", msg);
        passes++;
    } else {
        printf("  [FAIL] %s\n", msg);
        failures++;
    }
}

typedef void (*impl_fn)(int32_t *, int32_t *);

static int expected_w(rotation_t rot) {
    return (rot == ROT_90 || rot == ROT_270) ? PANEL_V_RES : PANEL_H_RES;
}
static int expected_h(rotation_t rot) {
    return (rot == ROT_90 || rot == ROT_270) ? PANEL_H_RES : PANEL_V_RES;
}

/* ══════════════════════════════════════════════════════════════════════
 *  Cenários
 * ══════════════════════════════════════════════════════════════════════ */

/* Cobertura da semântica observada dos 4 getters × 4 rotações. */
static void validate_mock_semantics(void) {
    printf("Scenario: Semântica observada dos getters (lógico × físico)\n");
    static const rotation_t rots[4] = { ROT_0, ROT_90, ROT_180, ROT_270 };
    static const char *names[4] = { "0", "90", "180", "270" };
    for (int i = 0; i < 4; i++) {
        mock_set_rotation(rots[i]);
        char msg[128];
        snprintf(msg, sizeof(msg), "rot%s: LOGICAL == 720x1280 (não rotaciona)",
                 names[i]);
        check(lv_display_get_horizontal_resolution(NULL) == PANEL_H_RES &&
              lv_display_get_vertical_resolution(NULL) == PANEL_V_RES, msg);
        snprintf(msg, sizeof(msg), "rot%s: PHYSICAL == %dx%d (orientado)",
                 names[i], expected_w(rots[i]), expected_h(rots[i]));
        check(lv_display_get_physical_horizontal_resolution(NULL) == expected_w(rots[i]) &&
              lv_display_get_physical_vertical_resolution(NULL) == expected_h(rots[i]), msg);
    }
    printf("\n");
}

/* Contrato da implementação correta: 4 rotações + ausência de double swap. */
static void validate_correct_impl(void) {
    printf("Scenario: impl_physical_no_swap (correção) × 4 rotações\n");
    static const rotation_t rots[4] = { ROT_0, ROT_90, ROT_180, ROT_270 };
    static const char *names[4] = { "0", "90", "180", "270" };
    for (int i = 0; i < 4; i++) {
        mock_set_rotation(rots[i]);
        int32_t w = 0, h = 0;
        impl_physical_no_swap(&w, &h);
        char msg[128];
        snprintf(msg, sizeof(msg), "rot%s: host(%d,%d) == físico(%d,%d)",
                 names[i], (int)w, (int)h, expected_w(rots[i]), expected_h(rots[i]));
        check(w == expected_w(rots[i]) && h == expected_h(rots[i]), msg);
        snprintf(msg, sizeof(msg), "rot%s: SEM double swap (host == getter físico)",
                 names[i]);
        check(w == lv_display_get_physical_horizontal_resolution(NULL) &&
              h == lv_display_get_physical_vertical_resolution(NULL), msg);
    }
    printf("\n");
}

/* As implementações bugadas DEVEM ser rejeitadas em 90/270 (falso 720x1280). */
static void validate_buggy_impls_rejected(void) {
    printf("Scenario: Implementações bugadas são rejeitadas (90/270)\n");
    static const rotation_t rots[4] = { ROT_0, ROT_90, ROT_180, ROT_270 };
    static const char *names[4] = { "0", "90", "180", "270" };

    printf("  Verifica que impl_logical_no_swap NÃO satisfaz o contrato:\n");
    for (int i = 0; i < 4; i++) {
        mock_set_rotation(rots[i]);
        int32_t w = 0, h = 0;
        impl_logical_no_swap(&w, &h);
        bool violates = (w != expected_w(rots[i]) || h != expected_h(rots[i]));
        char msg[128];
        if (rots[i] == ROT_90 || rots[i] == ROT_270) {
            snprintf(msg, sizeof(msg), "rot%s: impl lógica devolve %dx%d e é REJEITADA",
                     names[i], (int)w, (int)h);
            check(violates, msg);
        } else {
            snprintf(msg, sizeof(msg), "rot%s: impl lógica devolve %dx%d (acidentalmente correto)",
                     names[i], (int)w, (int)h);
            check(!violates, msg);
        }
    }

    printf("  Verifica que impl_physical_double_swap NÃO satisfaz o contrato:\n");
    for (int i = 0; i < 4; i++) {
        mock_set_rotation(rots[i]);
        int32_t w = 0, h = 0;
        impl_physical_double_swap(&w, &h);
        bool violates = (w != expected_w(rots[i]) || h != expected_h(rots[i]));
        char msg[128];
        if (rots[i] == ROT_90 || rots[i] == ROT_270) {
            snprintf(msg, sizeof(msg), "rot%s: double swap devolve %dx%d e é REJEITADA",
                     names[i], (int)w, (int)h);
            check(violates, msg);
        } else {
            snprintf(msg, sizeof(msg), "rot%s: double swap devolve %dx%d (acidentalmente correto)",
                     names[i], (int)w, (int)h);
            check(!violates, msg);
        }
    }
    printf("\n");
}

/* Null-safety total e parcial na implementação correta. */
static void validate_null_safety(void) {
    printf("Scenario: Null-safety\n");
    impl_physical_no_swap(NULL, NULL);
    check(1, "ambos NULL: sem crash");

    mock_set_rotation(ROT_90);
    int32_t w = -1, h = -1;

    impl_physical_no_swap(&w, NULL);
    check(w == 1280, "null parcial (só largura) ROT90: w == 1280");
    check(h == -1,   "null parcial (só largura): altura NÃO é escrita");

    impl_physical_no_swap(NULL, &h);
    check(h == 720,  "null parcial (só altura) ROT90: h == 720");
    check(w == 1280, "null parcial (só altura): largura NÃO é alterada");
    printf("\n");
}

int main(void) {
    printf("═══════════════════════════════════════════════════════════════\n");
    printf("  Contrato tab5_ui_host_get_display_size — semântica observada\n");
    printf("  Painel: %dx%d (retrato) | Físicos rotacionam | Lógicos fixos\n",
           PANEL_H_RES, PANEL_V_RES);
    printf("═══════════════════════════════════════════════════════════════\n\n");

    validate_mock_semantics();
    validate_correct_impl();
    validate_buggy_impls_rejected();
    validate_null_safety();

    printf("═══════════════════════════════════════════════════════════════\n");
    printf("  Resultados: %s  (pass=%d, fail=%d)\n",
           failures ? "FAILED" : "ALL PASSED", passes, failures);
    printf("═══════════════════════════════════════════════════════════════\n");

    if (failures > 0) {
        printf("\n  O ESPEC falhou: a implementação correta (físico-sem-swap)\n");
        printf("  deve passar em todas as rotações; as bugadas devem ser\n");
        printf("  rejeitadas em 90/270. Revise o teste antes de tocar no host.\n\n");
    }

    return failures ? 1 : 0;
}