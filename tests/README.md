# Testes do Tab5 Chat App

Suite de regressão para o **tab5-app-chat**. Valida os critérios de aceite
relacionados ao layout e scroll.

**Estado atual: implementação concluída — 20/20 PASS.**

## Registro técnico da correção aprovada

O scroll está desabilitado em **todos** os objetos do modal:
`s_modal`, `s_modal_backdrop`, `s_modal_card`, `cfg_body`, `btns` e nos
quatro campos `s_cfg_url`, `s_cfg_token`, `s_cfg_model` e
`s_cfg_max_tokens` (`cfg_body` agora é `set_scrollable(false)`). O único
objeto do arquivo com `set_scrollable(..., true)` é `s_messages_cont`. Em
vez de rolar, o card do modal usa altura automática
(`card = TAB5_UI_PCT(96) x TAB5_UI_SIZE_CONTENT`) e a grade compacta 2x2
dos campos garante que o conteúdo caiba com o teclado aberto em retrato e
paisagem, mantendo campos e botões acessíveis. Referências anteriores a
containers roláveis no modal pertencem ao histórico arquivado e não
descrevem o contrato atual.

## Execução

```bash
bash tests/run_all_tests.sh
```

Ou execução individual:

```bash
bash tests/test_compile.sh
bash tests/test_static_ac.sh
bash tests/test_apply_layout.sh
bash tests/test_rotation_relayout.sh
bash tests/test_full_width_input.sh
bash tests/test_modal_kb_layout.sh
bash tests/test_display_size_rotation.sh
bash tests/test_action_button_style.sh
bash tests/test_modal_landscape_keyboard.sh
bash tests/test_host_display_size_vs_lvgl.sh
bash tests/test_pct_width_contract.sh
bash tests/test_bubbles_contract.sh
bash tests/test_layout_call_contract.sh
bash tests/test_modal_relative_contract.sh
bash tests/test_scroll_capture_contract.sh
bash tests/test_scrollbar_contract.sh
bash tests/test_modal_interior_contract.sh
bash tests/test_modal_compact_contract.sh
bash tests/test_modal_lifecycle.sh
bash tests/test_build.sh
```

## Suítes

As 20 suítes cobrem:

- compilação com mock SDK e critérios estáticos de aceite;
- geometria de `apply_layout`, rotação/re-layout e input em largura total;
- modal com teclado, resolução física por rotação e estilo do action button;
- modal em paisagem, contrato host/LVGL e larguras `TAB5_UI_PCT(100)`;
- largura dos bubbles, chamadas reais de layout e modal relativo;
- captura de scroll, contrato de scrollbar, contrato do interior do modal e
  build/empacotamento;
- limpeza completa dos handles do modal no callback de destroy.

Os contratos de modal e layout extraem e inspecionam as funções reais de
produção. Os testes geométricos complementam essa verificação com cenários
controlados.

A suíte 17 (`test_scrollbar_contract.sh`) cobre a regressão do scroll do input
(`s_messages_cont` é o **único** `set_scrollable(true)` do arquivo;
`row`/`spacer(s)`/`bubble`/`s_input_cont`/
`s_input_ta`/`s_modal`/`s_modal_backdrop`/`s_modal_card`/`cfg_body`/`btns`/
`s_cfg_url`/`s_cfg_token`/`s_cfg_model`/
`s_cfg_max_tokens` são `false`) e o overflow
horizontal do system bubble (gap do row `is_system ? 0 : 4` no `build_bubble` e
altura do `s_input_ta` em `TAB5_UI_PCT(100)`). Seu runtime extrai o gap real de
`src/main.c`, confirmando o contrato H1/H2 implementado.

A suíte 18 (`test_modal_interior_contract.sh`) verifica os contratos dos
elementos internos do modal (container de botões, backdrop, campos de
configuração e botões de ação), a limpeza/invalidação dos handles e, pela
extração do corpo real de `open_config_modal`/`build_chat_ui`, os scrollables
do modal: `s_modal`, `s_modal_backdrop`, `s_modal_card` e `cfg_body` com
`set_scrollable(false)` (nada no modal é rolável) e os 4 campos `s_cfg_*`
também `false` (altura fixa 42 dentro da grade 2x2).

A suíte 19 (`test_modal_compact_contract.sh`) verifica o contrato do plano
aprovado para o modal de configuração: **nenhum objeto do modal é rolável**
(`cfg_body` agora é `set_scrollable(false)`); `card = TAB5_UI_PCT(96) x
TAB5_UI_SIZE_CONTENT` (altura automática, sem `PCT(60)`); os 4 campos usam uma
**grade compacta 2x2** (duas linhas de células `PCT(50)`), de modo que o
conteúdo caiba com o teclado aberto em retrato e paisagem — sem depender de
scroll. A suíte valida ainda a acessibilidade (rótulo + textarea por campo e os
dois botões de ação) e a preservação do layout relativo
(`modal/backdrop PCT(100)xPCT(100)`, `card CENTER -(kb_h/2)`, ausência de
dimensões absolutas). Portanto, os únicos objetos do arquivo com
`set_scrollable(..., true)` é `s_messages_cont`.

## Arquivos

- `tests/run_all_tests.sh` — orquestrador das 20 suítes
- `tests/tab5_sdk.h` — mock local do SDK Tab5
- `tests/test_*.sh` — suítes individuais
- `tests/test_host_display_size_vs_lvgl.c` — contrato host × semântica física
- `tests/.build/` — artefatos de compilação local (ignorados pelo git)

## Notas de escopo

- A validação visual do mapeamento real do SDK requer captura no dispositivo;
  os mocks comprovam compilação, contratos e geometria.
- O contrato do host inspeciona `tab5_ui_host.cpp` no repositório `tab5-os`
  quando esse repositório está acessível.

## Histórico arquivado de uma execução anterior (não é o estado atual)

O bloco abaixo registra somente a execução anterior, quando a implementação
ainda estava pendente: naquela execução de 2026-09-11 (20
suítes), **13 passaram e 7 falharam**. Os REDs descritos na tabela são
históricos e não representam o estado atual; a implementação foi concluída e a
execução vigente está em **20/20 PASS**.

| Suíte | Contrato exigido | RED histórico (src/main.c anterior) |
|-------|------------------|---------------------|
| 2 `test_static_ac.sh` | `card = PCT(96) x SIZE_CONTENT`; `cfg_body=false` | card usa `PCT(60)` e `cfg_body=true` |
| 11 `test_pct_width_contract.sh` | `card = PCT(96) x SIZE_CONTENT` (A8b) | `PCT(60)` ainda no card |
| 14 `test_modal_relative_contract.sh` | card auto-height; nada rolável no modal real | corpos reais mantêm `PCT(60)`/`cfg_body=true` |
| 16 `test_scroll_capture_contract.sh` | `cfg_body=false`; sem `set_scrollable(..., true)` em `open_config_modal` | `cfg_body=true` no corpo real |
| 17 `test_scrollbar_contract.sh` | único `set_scrollable(..., true)` = `s_messages_cont` | extração real encontra `cfg_body=true` também |
| 18 `test_modal_interior_contract.sh` | grade 2x2 (`row1`/`row2`, `cell_*` filhos de `cfg_body`), campos dentro das células | `src/main.c` usa coluna única, campos filhos de `cfg_body` |
| 19 `test_modal_compact_contract.sh` | plano 2x2 (cfg_body=false, card auto-height, grade, fit, acessibilidade) | partes B/D falham contra o modelo antigo |

Nota histórica: as suítes 5/9/15 (geometria runtime do modal) **passavam** mesmo
antes da implementação, pois replicavam o layout-alvo aprovado (target), não
`src/main.c`.
O teste de geometria da suíte 19 (parte C) passa integralmente e prova a
regra do plano: conteúdo compacto 2x2 (~262px) cabe com teclado em retrato
(880px visíveis) e paisagem (320px ≥ 262px); a coluna única (~414px) **não**
cabe em paisagem — a grade 2x2 é obrigatória; extremo kb=550 (170px visíveis)
é clipping documentado, sem scroll.

Semântica observada na plataforma M5Stack Tab5:

| Getter | 0 | 90 | 180 | 270 |
|--------|------|------|------|------|
| Lógico (`get_horizontal/vertical_resolution`) | 720×1280 | 720×1280 | 720×1280 | 720×1280 |
| Físico (`get_physical_horizontal/vertical_resolution`) | 720×1280 | 1280×720 | 720×1280 | 1280×720 |

Os getters físicos refletem a orientação real e o host deve lê-los sem swap
manual. O host real (`tab5-os`) satisfaz esse contrato.

**Estado final após a correção de overflow:** os gaps horizontais de `row1`,
`row2` e `btns` são zero. Assim, `PCT(50) + PCT(50) + gap(0) <= 100%` é
verificado pela suíte 19. O texto histórico acima não indica falha ou
implementação pendente.
