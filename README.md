# Tab5 Chat IA App (`tab5-app-chat`)

Aplicativo isolado de Chat e Assistente de IA para o **Tab5 OS**.

## Compilação e Empacotamento

```bash
chmod +x tools/build.sh
./tools/build.sh
```

O pacote `.tab5pkg` será gerado em `dist/com.tab5.chat.tab5pkg`.

## Estado final do layout

- A grade do modal é 2x2: cada linha usa duas colunas `PCT(50)` com gap
  horizontal zero, portanto a soma das larguras não excede 100%.
- O rodapé usa dois botões `PCT(50)` também com gap zero; ambos permanecem
  acessíveis e clicáveis.
- O card é `PCT(96) x SIZE_CONTENT`; os quatro campos têm rótulo próprio e
  altura fixa. O modal não é rolável; somente a lista de mensagens é.
- O contrato geométrico cobre fit horizontal, dimensões e alinhamento. Foco e
  hitbox não são afirmados porque o SDK mock disponível não expõe essa API.

### Histórico

Registros anteriores que descrevem `PCT(50) + gap` ou um modal rolável são
históricos da implementação anterior. O estado vigente é o contrato acima;
as 20 suítes, compilação e build devem ser executados com
`tests/run_all_tests.sh`.
