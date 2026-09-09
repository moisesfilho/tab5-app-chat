# Testes do Tab5 Chat App

Suite de regressão/TDD para o **tab5-app-chat**. Valida os critérios de
aceite relacionados ao layout e scroll.

## Execução

```bash
bash tests/run_all_tests.sh
```

Ou execução individual:

```bash
bash tests/test_compile.sh                      # compila src/main.c com mock SDK (gcc)
bash tests/test_static_ac.sh                    # verificação estática dos critérios de aceite
bash tests/test_apply_layout.sh                 # teste de geometria do apply_layout (gcc)
bash tests/test_rotation_relayout.sh            # detecção de rotação w/h no polling (gcc)
bash tests/test_full_width_input.sh             # input com largura total da orientação (gcc)
bash tests/test_modal_kb_layout.sh              # modal/backdrop/card com kb_h (gcc)
bash tests/test_display_size_rotation.sh        # contrato de resolução física × rotação 0/90/180/270
bash tests/test_action_button_style.sh          # equivalência de estilo: action btn × send/close
bash tests/test_modal_landscape_keyboard.sh     # modal em paisagem com teclado ativo
bash tests/test_host_display_size_vs_lvgl.sh     # contrato host vs semântica observada (getters físicos orientados)
bash tests/test_pct_width_contract.sh            # largura PCT(100) para messages/input/modal/backdrop (macro real -1100)
bash tests/test_bubbles_contract.sh              # bubbles: system 100%, user/assistant 80%
bash tests/test_modal_relative_contract.sh       # modal relativo: PCT(100)xPCT(100), card PCT(96)xPCT(60), CENTER -(kb_h/2) (TDD RED)
bash tests/test_build.sh                        # executa tools/build.sh e valida artefatos
```

## Suítes

| Suíte | Descrição | Cobertura |
|-------|-----------|-----------|
| `test_compile.sh` | Compila `src/main.c` com um mock de `tab5_sdk.h` usando `gcc -fsyntax-only`. Garante que o código-fonte C é sintaticamente válido sem o SDK real. | Compilação |
| `test_static_ac.sh` | Análise estática (grep) dos critérios de aceite via padrões no código-fonte: scroll, layout, rotação, modal com kb_h, guardas min/max. | AC-001…AC-007 |
| `test_apply_layout.sh` | Teste de unidade C que replica a matemática do `apply_layout` e valida que o `s_input_cont` permanece dentro da área útil (abaixo do teclado) para faixas realistas de altura do teclado (0–60% da tela). | AC-003 (geométrico) |
| `test_rotation_relayout.sh` | Teste C instrumentado que valida detecção de mudança w/h no `handle_poll` e re-layout após rotação: input_cont usa largura total da orientação atual. | AC-004, AC-005 |
| `test_full_width_input.sh` | Sweep parametrizado que valida `input_cont.width == display.w` para 6 orientações/teclados e sweep 0..60% kb. | AC-005 (regressão) |
| `test_modal_kb_layout.sh` | Teste C instrumentado que valida modal/backdrop/card com e sem kb_h: dimensões full-screen, card com kb_h, guardas min/max, campos dentro da área útil. | AC-006, AC-007 |
| `test_display_size_rotation.sh` | Contrato C que valida `tab5_ui_get_display_size` retorna resolução física correta para 4 ângulos de rotação (0°/90°/180°/270°), idempotência e detecção via `handle_poll`. | Resolução física × rotação |
| `test_action_button_style.sh` | Contrato C que valida equivalência visual: botão de ação (WASM) usa mesma paleta (accent), borda (nenhuma), raio (10) e tamanho quadrado do botão de envio/close. | Estilo do action button |
| `test_modal_landscape_kb.sh` | Contrato C que valida modal do Chat em paisagem com teclado: card dentro da área útil, offset `-(kb_h/2)`, guardas min/max, ciclo completo kb→hide. | Modal paisagem + teclado |
| `test_host_display_size_vs_lvgl.sh` | Contrato C++ que extrai e inspeciona a função REAL `tab5_ui_host_get_display_size` (`tab5_ui_host.cpp`) e valida a **semântica observada**: na plataforma Tab5, os getters físicos do LVGL 9 rotacionam (ROT_90/270 → 1280×720) e os lógicos NÃO (720×1280 fixo). O host deve ler os **físicos sem swap manual**. Cobre rotações 0/90/180/270, null-safety e ausência de *double swap*. | Host × semântica física observada |
| `test_pct_width_contract.sh` | Contrato de largura **PCT(100)** para `s_messages_cont`, `s_input_cont`, `s_modal` e `s_modal_backdrop`, usando a macro real do SDK `TAB5_UI_PCT(percent) = -1000 - percent` (⇒ `TAB5_UI_PCT(100) == -1100`). Parte estática (grep) valida a migração de largura absoluta `w` → PCT(100); parte runtime valida o layout-alvo com **alturas, teclado e alinhamentos preservados** (msg_h, INPUT_H, h, `-(kb_h+INPUT_GAP)`, TOP_LEFT/BOTTOM_LEFT). | Contrato PCT(100) |
| `test_bubbles_contract.sh` | Contrato de largura dos bubbles: **system = 100%** do máximo, **user/assistant = 80%** (`max*8/10`); row e label internos usam `TAB5_UI_PCT(100)` × `TAB5_UI_SIZE_CONTENT`; alturas sempre CONTENT. Validação estática + runtime para portrait/landscape e fallback. | Bubbles (100%/80%) |
| `test_modal_relative_contract.sh` | Contrato do **modal relativo**: extrai os corpos REAIS de `open_config_modal`/`apply_modal_layout` e exige modal/backdrop `PCT(100) × PCT(100)`, card `PCT(96) × PCT(60)`, card `CENTER` com offset `-(kb_h/2)` e **ausência** de `tab5_ui_get_display_size`/`h`/`usable_h`/`card_h` no caminho modal. Cenários: retrato (720×1280) e paisagem com host **stale 720×1280** (tela visual 1280×720). Parte runtime valida a geometria alvo. | Modal relativo (TDD RED) |
| `test_build.sh` | Executa `./tools/build.sh` e verifica geração de `app.wasm` e `dist/com.tab5.chat.tab5pkg`. | Build / empacotamento |

## Arquivos

- `tests/run_all_tests.sh` — orquestrador de todas as suítes
- `tests/tab5_sdk.h` — mock local do SDK Tab5
- `tests/test_compile.sh` — compilação com mock SDK
- `tests/test_static_ac.sh` — análise estática dos ACs
- `tests/test_apply_layout.sh` — geometria do apply_layout
- `tests/test_rotation_relayout.sh` — detecção de rotação w/h
- `tests/test_full_width_input.sh` — largura total do input
- `tests/test_modal_kb_layout.sh` — modal com kb_h
- `tests/test_display_size_rotation.sh` — contrato resolução × rotação
- `tests/test_action_button_style.sh` — equivalência de estilo action button
- `tests/test_modal_landscape_keyboard.sh` — modal paisagem + teclado
- `tests/test_host_display_size_vs_lvgl.c` — contrato host × semântica observada (físicos orientados)
- `tests/test_host_display_size_vs_lvgl.sh` — harness que extrai a função real do host
- `tests/test_pct_width_contract.sh` — contrato PCT(100) para messages/input/modal/backdrop
- `tests/test_bubbles_contract.sh` — contrato de largura dos bubbles (system 100%, user/assistant 80%)
- `tests/test_modal_relative_contract.sh` — contrato do modal relativo (extração das funções reais, TDD RED)
- `tests/test_build.sh` — build e empacotamento
- `tests/.build/` — artefatos de compilação local (ignorados pelo git)

## Resultados esperados (TDD)

As suítes **geométricas** (apply_layout, rotation, full_width, modal_kb, display_size,
action_button, modal_landscape) validam o _contrato_ matemático/visual da
implementação pretendida e passam com o código atual (pois testam a lógica isoladamente).

A suíte **`test_static_ac.sh`** falha para os padrões que ainda não existem no
código-fonte. As falhas **esperadas** antes da implementação são:

| AC | Padrão ausente | Correção esperada |
|----|---------------|-------------------|
| AC-004 | `s_last_w`/`s_last_h` e comparação `w != s_last_w` | Adicionar variáveis e `if` no `handle_poll` |
| AC-006 | `card_h` derivado de `h - kb_h` | Usar `usable_h = h - kb_h` no `open_config_modal` |
| AC-007 | Guardas `card_h < 200` / `card_h > 520` | Adicionar min/max no `open_config_modal` |

### Novas suítes de contrato/regressão

| Suíte | O que valida | TDD status |
|-------|-------------|------------|
| `test_display_size_rotation` | `tab5_ui_get_display_size` retorna w×h correto para rotação 0/90/180/270, `handle_poll` detecta mudança, bubble width = 90% do display | PASS (contrato isolado) |
| `test_action_button_style` | Botão de ação WASM usa paleta accent, borda 0, raio 10, tamanho 48×48 — equivalente ao send/close | PASS (contrato isolado) |
| `test_modal_landscape_kb` | Modal em paisagem (1280×720) com kb 0/200/400/550: card dentro de usable, offset `-(kb_h/2)`, ciclo kb→hide restaura | PASS (contrato isolado) |
| `test_host_display_size_vs_lvgl` | `tab5_ui_host_get_display_size` devolve a resolução **física orientada** (getters físicos, sem swap manual) para rotações 0/90/180/270; null-safety; lógicos não rotacionam (720×1280 fixo) | PASS (host real já corrigido) |
| `test_pct_width_contract` | `s_messages_cont`, `s_input_cont`, `s_modal` e `s_modal_backdrop` com largura `TAB5_UI_PCT(100)` (**-1100**) em vez de `w` absoluto; alturas (msg_h/INPUT_H/h), teclado (`-(kb_h+INPUT_GAP)`) e alinhamentos preservados | **FAIL estático esperado** (antes da implementação) / runtime PASS (contrato isolado) |
| `test_bubbles_contract` | bubbles **system 100%** / **user+assistant 80%**, row/label `TAB5_UI_PCT(100)` × CONTENT | PASS (já implementado) |
| `test_modal_relative_contract` | modal/backdrop `PCT(100) × PCT(100)`, card `PCT(96) × PCT(60)`, card `CENTER` offset `-(kb_h/2)`, sem `get_display_size`/`h`/`usable_h`/`card_h` no caminho modal; cenários retrato e **landscape stale 720×1280** | **FAIL (TDD RED esperado)** — produção ainda usa `PCT(100) × h`, `card_h`/`520` e `TOP_LEFT card_top` |
| `test_layout_call_contract` | chamadas reais de `apply_layout`/`build_bubble`/`apply_modal_layout` | **FAIL (TDD RED)** — asserções modais atualizadas para o contrato relativo |

### Falha esperada: `test_pct_width_contract.sh` (estática) e `test_static_ac.sh` (AC-005/AC-006/AC-008)

> **Nota de escopo:** as checagens **estáticas** de `PCT(100)` em `src/main.c` falham
> hoje porque a implementação atual usa largura absoluta `w`; a parte **runtime**
> valida o layout-alvo e passa. O veredito da suíte é dado pelo runtime.

Antes da implementação do contrato PCT(100) em `src/main.c`:

| Item | Estado atual (`w` absoluto) | Contrato (`TAB5_UI_PCT(100)` = -1100) |
|------|-----------------------------|---------------------------------------|
| `s_messages_cont` | `set_size(cont, w, msg_h…)` | `set_size(cont, PCT(100)≈-1100, msg_h…)` |
| `s_input_cont` | `set_size(cont, w, INPUT_H)` | `set_size(cont, PCT(100), INPUT_H)` |
| `s_modal` | `set_size(modal, w, h)` | `set_size(modal, PCT(100), h)` |
| `s_modal_backdrop` | `set_size(backdrop, w, h)` | `set_size(backdrop, PCT(100), h)` |
| Bubbles | system 100% / user+assistant 80% | já conforme |
| Alturas/teclado/alinhamento | msg_h, INPUT_H, h, `-(kb_h+INPUT_GAP)`, TOP_LEFT/BOTTOM_LEFT | preservar |

**Correção esperada (só em `src/main.c`, sem tocar no host/SDK):** trocar a largura `w`
por `TAB5_UI_PCT(100)` nesses 4 objetos, mantendo alturas, offsets de teclado e
alinhamentos. O mock `tests/tab5_sdk.h` já espelha a macro real
`(-1000 - (percent))` para que `test_compile.sh` valide o código sob o contrato real.

Todas as demais suítes (compile, geometry, build, rotation, full_width, modal_kb,
host, bubbles) devem passar a qualquer momento.

> **Nota de escopo — teste host (`test_host_display_size_vs_lvgl.sh`):** o contrato
> do host vive no repositório `tab5-os` (`tab5_ui_host.cpp`), fora deste repo.
> Este teste extrai e inspeciona a função REAL quando o repo `tab5-os` está
> acessível. Se o host estiver fora do repositório ou ausente, isso **não** é
> tratado como falha deste escopo.

Semântica observada na plataforma M5Stack Tab5 (ver
`.opencode/memory/tab5-chat-display-size.md`):

| Getter | 0 | 90 | 180 | 270 |
|--------|------|------|------|------|
| Lógico (`get_horizontal/vertical_resolution`) | 720×1280 | 720×1280 | 720×1280 | 720×1280 |
| Físico (`get_physical_horizontal/vertical_resolution`) | 720×1280 | **1280×720** | 720×1280 | **1280×720** |

O display é criado com a resolução do painel (720×1280) e a rotação é aplicada no
caminho físico/panel. Por isso os getters **físicos** são os que refletem a
orientação real e o host deve lê-los **sem swap manual**.
Estado atual: o host real (`tab5_os`) já satisfaz o contrato — **PASS**.
