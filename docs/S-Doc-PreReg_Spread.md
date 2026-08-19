# Pre-registro — grade de `InpMaxSpread` na janela valida

**Data:** 2026-08-19 | **Escrito ANTES de rodar** (R2) | **Maquina:** PC-Escritorio

---

## 1. Por que a pergunta existe agora

O filtro `InpMaxSpread = 260` foi calibrado como a **mediana absoluta** da distribuicao
de spread da conta Standard. Medido hoje, sobre os sinais crus do SP:

| mes | mediana do spread | % dos sinais que passam `<= 260` |
|---|---|---|
| 2026-01 | 160 | **100%** (mes INVALIDO — spread carimbado) |
| 2026-02 | 264 | 46% |
| 2026-03 | 308 | 4% |
| **2026-04** | 308 | **0%** |
| **2026-05** | 308 | **0%** |
| 2026-06 | 280 | 44% |
| 2026-07 | 240 | 100% |
| 2026-08 | 260 | 95% |

Dois fatos:

1. **O corte desliga o EA por dois meses inteiros.** Abril e maio nao produzem
   nenhum trade. O padrao de promocao (CLAUDE.md secao 4) exige estabilidade
   mensal, e zero trade em 2 de 7 meses nao e' estabilidade.
2. **O corte esta ancorado numa distribuicao que se moveu.** A mediana do spread
   foi de 160 (janeiro, carimbado) a 308 (abril/maio) e de volta a 240 (julho).
   Um limiar absoluto calibrado num periodo nao descreve os outros.

Isso e' o mesmo defeito que o item 6 da fila do CLAUDE.md ja' previa para a conta
Raw/Zero ("recalibrar para termos RELATIVOS, senao nunca dispara") — so' que ele
acontece **na mesma conta, ao longo do tempo**, nao so' entre contas.

---

## 2. Hipotese

**H1:** o corte em 260 esta apertado demais na janela valida. Afrouxa-lo adiciona
trades cujo resultado liquido e' positivo, e o filtro atual esta jogando lucro fora.

**H0 (a que ela precisa derrubar):** o corte esta certo. O CLAUDE.md 5.3 mediu que
os trades removidos rendiam **-$0,54/trade** e que **99% da diferenca NAO e' custo
e sim condicao de mercado** — spread alto marca um mercado pior, nao apenas mais
caro. Se H0 vale, ficar de fora em abril e maio e' comportamento CORRETO, nao bug.

> A medicao dos -$0,54 veio de uma janela que inclui 2026-01. Como janeiro passa
> 100% do filtro, ele nao entra no conjunto DESCARTADO — mas domina o conjunto
> MANTIDO (49% dos trades, 44% do lucro). O contraste mantido-x-descartado esta
> contaminado do lado mantido. Por isso a pergunta e' re-aberta.

---

## 3. Grade

Janela **2026.02.01 - 2026.08.18** (2026-01 excluido: spread carimbado, armadilha 13
confirmada no XAUUSDm). XAUUSDm M5, "Every tick based on real ticks", 0.01 lote,
`C_HIST`, `InpR2Enabled=true`, **`InpPirEnabled=false`** (a piramide fica fora para
nao misturar dois efeitos; ela esta sob revisao propria).

| Rodada | `InpMaxSpread` |
|---|---|
| S260 | 260 (atual — controle) |
| S280 | 280 |
| S300 | 300 |
| S320 | 320 |
| S360 | 360 (p90 medido) |
| SOFF | 0 (sem filtro) |

---

## 4. Criterio de decisao — escrito antes

O valor de um filtro e' **o desempenho do que ele REMOVE** (CLAUDE.md secao 4).
Aqui isso vira o incremento entre niveis vizinhos:

    trades_adicionados(N) = negociacoes(N) - negociacoes(260)
    lucro_adicionado(N)   = lucro(N) - lucro(260)
    rendimento_do_afrouxamento(N) = lucro_adicionado / trades_adicionados

| Resultado | Veredito |
|---|---|
| `rendimento_do_afrouxamento <= 0` em todos os niveis | **MANTER 260.** H0 confirmada: o que o filtro remove nao paga. Abril/maio de fora e' correto. |
| `rendimento > 0` **e** o fator de recuperacao NAO cai em algum nivel | **AFROUXAR e' HIPOTESE**, com o nivel indicado. Nao vira default sem OOS. |
| `rendimento > 0` mas o fator de recuperacao cai em todos os niveis | **TRADE-OFF**: mais lucro por menos eficiencia. Decisao do Mike, nao consequencia automatica. |

**Ressalvas que andam junto do numero, escritas antes de ve-lo:**

- **Isto e' grade de 6,5 meses com 76 trades no controle.** Varrer um limiar nesse
  tamanho de amostra e' exatamente como se produz sobreajuste. Nenhum resultado
  aqui promove nada a default: no maximo vira **hipotese** para OOS.
- **O nivel absoluto NAO e' a pergunta de fundo.** Mesmo que um corte maior meca
  melhor, ele herda o defeito de forma: continua ancorado numa distribuicao que se
  move. A correcao estrutural e' **relativizar** (percentil movel do proprio
  spread, ou multiplo do ATR) — o que exige codigo novo e, pela R7, so' entra
  depois de medido.
- **Um otimo no MEIO da grade, com queda dos dois lados, e' assinatura de
  estrutura; um otimo na BORDA e' assinatura de sobreajuste.** Registrar qual dos
  dois apareceu.
- Abril e maio tem mediana 308: **so' os niveis 320 e 360 e o SOFF podem
  reanimar esses meses.** Se o ganho vier so' de 260->280 e 280->300, os dois
  meses mortos continuam mortos e o problema de estabilidade mensal permanece
  aberto, independentemente do veredito.
