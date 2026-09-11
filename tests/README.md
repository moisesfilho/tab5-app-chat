# Testes do Tab5 Chat App

Suite de regressão para o **tab5-app-chat**. Valida os critérios de aceite
relacionados ao layout e scroll.

**Estado atual: 17 suítes — todas PASS, incluindo o contrato de scrollbar
(H1/H2 implementados em `src/main.c`).**

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
bash tests/test_build.sh
```

## Suítes

As 17 suítes cobrem:

- compilação com mock SDK e critérios estáticos de aceite;
- geometria de `apply_layout`, rotação/re-layout e input em largura total;
- modal com teclado, resolução física por rotação e estilo do action button;
- modal em paisagem, contrato host/LVGL e larguras `TAB5_UI_PCT(100)`;
- largura dos bubbles, chamadas reais de layout e modal relativo;
- captura de scroll, contrato de scrollbar e build/empacotamento.

Os contratos de modal e layout extraem e inspecionam as funções reais de
produção. Os testes geométricos complementam essa verificação com cenários
controlados.

A suíte 17 (`test_scrollbar_contract.sh`) cobre a regressão do scroll do input
(somente `s_messages_cont` e `s_modal_card` permanecem `set_scrollable(true)`;
`row`/`spacer(s)`/`bubble`/`s_input_cont`/`s_input_ta` são `false`) e o overflow
horizontal do system bubble (gap do row `is_system ? 0 : 4` no `build_bubble` e
altura do `s_input_ta` em `TAB5_UI_PCT(100)`). Seu runtime extrai o gap real de
`src/main.c`, confirmando o contrato H1/H2 implementado.

## Arquivos

- `tests/run_all_tests.sh` — orquestrador das 17 suítes
- `tests/tab5_sdk.h` — mock local do SDK Tab5
- `tests/test_*.sh` — suítes individuais
- `tests/test_host_display_size_vs_lvgl.c` — contrato host × semântica física
- `tests/.build/` — artefatos de compilação local (ignorados pelo git)

## Notas de escopo

- A validação visual do mapeamento real do SDK requer captura no dispositivo;
  os mocks comprovam compilação, contratos e geometria.
- O contrato do host inspeciona `tab5_ui_host.cpp` no repositório `tab5-os`
  quando esse repositório está acessível.

Semântica observada na plataforma M5Stack Tab5:

| Getter | 0 | 90 | 180 | 270 |
|--------|------|------|------|------|
| Lógico (`get_horizontal/vertical_resolution`) | 720×1280 | 720×1280 | 720×1280 | 720×1280 |
| Físico (`get_physical_horizontal/vertical_resolution`) | 720×1280 | 1280×720 | 720×1280 | 1280×720 |

Os getters físicos refletem a orientação real e o host deve lê-los sem swap
manual. O host real (`tab5-os`) satisfaz esse contrato.
