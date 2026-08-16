# CLAUDE.md — Projeto SBurn
**Versao:** 3.0 | **Atualizado:** 2026-08-16
Leia por completo antes da primeira acao. Em conflito, este arquivo vence.

---

## 0. O que e' o projeto

Pesquisa empirica de sistemas de trading para **XAUUSDm** (ouro) no MetaTrader 5.
O objetivo NAO e' "fazer um EA que lucre no backtest". E' **descobrir, com medicao
honesta, onde existe e onde nao existe vantagem estatistica** — e so' entao construir.

Interlocutor: Mike, dev MQL5, PT-BR, no Japao.
**Responder em portugues do Brasil. Comentarios de codigo em portugues SEM acentos.**

---

## 1. Regras de conduta (R1-R7)

**R1 — Nenhum parametro sem medicao.** Todo valor ou vem de medicao documentada, ou
e' input marcado `NAO CALIBRADO`. Chutar parametro e' a falha mais grave aqui.

**R2 — Hipotese antes do teste.** Escrever o que se espera e qual criterio decide,
ANTES de rodar. Sem pre-registro, padrao encontrado e' pesca.

**R3 — Zero distorcao silenciosa.** Nunca arredondar a favor, omitir limitacao de
metodo ou apresentar numero sem ressalva. Erro do assistente: assumir explicitamente.

**R4 — Critica direta.** Contraditorio, nao validacao. Resultado negativo
documentado vale tanto quanto achado positivo.

**R5 — Checkpoint.** Etapas verificaveis; ao fim de cada uma dizer o que foi feito,
o que ficou pendente e o proximo passo.

**R6 — Anti-scope-creep.** Antes de criar algo novo: isso mede o que os sensores
atuais NAO medem? Ferramenta nova so' entra depois que o existente foi medido.

**R7 — Medir antes de construir.** Toda ideia vira primeiro coluna no EA de medicao
e passa pelo tribunal. So' o que passa vira codigo operacional. Ja' evitou dois EAs
perdedores (contra-trade pos-BE e cruzamento de medias).

---

## 2. Ambiente de desenvolvimento

### Estrutura do repositorio

    C:\dev\SBurn\                     <- raiz do repositorio git
      CLAUDE.md
      README.md
      .gitignore
      indicators\   S-Ind-*.mq5       -> junction para MQL5\Indicators\SBurn\
      experts\      S-EA-*.mq5        -> junction para MQL5\Experts\SBurn\
      include\      S-Include-*.mqh   -> junction para MQL5\Include\SBurn\
      analise\      S-Py-*.py
      docs\         S-Doc-*.md
      dados\        CSVs (nao versionados)

Junctions (uma vez, cmd como administrador):

    mklink /J "<PastaDeDados>\MQL5\Indicators\SBurn" "C:\dev\SBurn\indicators"
    mklink /J "<PastaDeDados>\MQL5\Experts\SBurn"    "C:\dev\SBurn\experts"
    mklink /J "<PastaDeDados>\MQL5\Include\SBurn"    "C:\dev\SBurn\include"

### Convencao de nomes (o nome diz onde instalar)

| Prefixo | Destino | Compila? |
|---|---|---|
| `S-Ind-*.mq5` | `MQL5\Indicators\SBurn\` | Sim (F7), primeiro |
| `S-EA-*.mq5` | `MQL5\Experts\SBurn\` | Sim (F7), por ultimo |
| `S-Include-*.mqh` | `MQL5\Include\SBurn\` | Nao |
| `S-Py-*.py` | `analise\` | — |
| `S-Doc-*.md` | `docs\` | — |

Todo arquivo leva no cabecalho: pasta de instalacao, se compila, e a assinatura que
imprime no log.

### Git

- Nao versionar: `*.ex5`, `*.log`, `dados/*`.
- Commit por unidade logica; mensagem `tipo(escopo): descricao`.
- Toda mudanca de comportamento sobe o `#property version` e ganha entrada no
  CHANGELOG do cabecalho do proprio arquivo.

---

## 3. Contexto operacional (nao re-descobrir)

| Item | Valor |
|---|---|
| Simbolo | XAUUSDm, Exness Standard, servidor Exness-MT5Real41 |
| Digitos | **3** (point = 0.001); 1 ponto com 0.01 lote = **$0.001** |
| Spread real | mediana **260 pts**, p25 240, p75 280, p90 360 |
| Conta | JPY, hedging |
| Pasta de dados MT5 | `...\MetaQuotes\Terminal\53785E099C927DB68A545C249CDBCE06\MQL5` |
| CSV de saida | `...\MetaQuotes\Terminal\`**`Common`**`\Files\SBurn\` (pasta IRMA) |
| **Tick real Exness** | **so' a partir de 2026.01** |

**Backtest so' com "Every tick based on real ticks".** O desenho e' path-dependent
(63% dos trades saem pelo breakeven, que depende do caminho intrabar): qualquer teste
antes de 2026.01 e' **invalido**, nao apenas impreciso. Assinaturas de tick simulado:
spread com poucos valores distintos (3 vs 8), derrapagem no BE proxima de zero, P&L
repetido em muitos trades.

---

## 4. Padroes de medicao

- **Entrada A** = bid do 1o tick da barra seguinte ao sinal.
- **Horizontes** = 5/15/30 **barras do TF do grafico**.
- **Assimetria** = medMFE − medMAE. Condicao necessaria, nao suficiente.
- **MFE e' excursao maxima, nao lucro.**
- **Promocao:** positivo em OOS **e** IS, com estabilidade mensal. Meses, nao anos
  = "promissor", nunca "validado".
- **Teste do descartado:** o valor de um filtro e' o desempenho dos trades que ele
  REMOVE. Se o descartado rende bem, o filtro so' joga lucro fora.
- **Vies de selecao:** filtro que "olha" uma barra paga essa barra no preco de
  entrada. Simular sempre com preco exato de saida.
- **Ordem importa:** MFE/MAE dizem o QUE aconteceu, nunca em QUE ORDEM. "88% dos
  casos alcancam 1 ATR" nao e' "chegam la antes do stop" (foram 36%).

---

## 5. Estado empirico

### 5.1 A estrategia validada (titular)

**Entrada:** pullback do ScalpPullback no M5 (buffer 26, barra fechada) COM o regime
do SP no M30 (buffer 27) concordando.
**Saida:** stop 3,67xATR(14); ao lucro atingir 0,73xATR o stop vai para o **nivel BID
da entrada** (degrau ZERO); qualquer sinal novo do SP fecha.
**Filtros:** histograma do TMO |main-signal| < 2,20 e spread <= 260.

Backtest real, ticks reais, 2026.01.01-08.12, 0.01 lote:

| Config | n | media$ | total$ | DD$ | ret/DD | PF |
|---|---|---|---|---|---|---|
| sem filtros | 370 | +3.15 | +1163.82 | 206.33 | 5.6x | 2.06 |
| + histograma | 247 | +4.75 | +1173.88 | 157.57 | 7.5x | 2.69 |
| **+ histograma + spread** | **137** | **+9.55** | **+1308.59** | **49.25** | **26.6x** | **5.83** |

Perfil: ~63% scratch (-$0.50), ~25% ganho (+$32), ~12% stop (-$20). Duracao mediana
35 min. Stop mediano 20.077 pts ($20); BE arma em 3.993 pts ($4).
**Status: promissor, NAO validado.** 137 trades em 8 meses.

### 5.2 O problema aberto: participacao

A estrategia fica no mercado **9% do tempo** e participa de **31%** do movimento
direcional que ela mesma identifica (captura 1,24M pts; perde 2,79M enquanto fora).
Apos um scratch o preco retoma a direcao original em **71%** dos casos (~10.000 pts);
apos um stop, **83%** (~17.000 pts). Nada no momento do scratch prediz isso (MFE,
duracao, ATR: 66-77%, rho ~0,1).

Reprovado: reentrada por rompimento do extremo (stop sobe de 8% para 20%; ret/DD cai
de 26,6x para 21,4x), com ou sem filtro de expansao de ATR, com 1 ou 3 reentradas.

**Em aberto:** `SIG_PBSHALLOW` (pullback raso dentro do regime, sem exigir retorno ao
canal PAC) — implementado no EA de medicao v1.20, **ainda nao rodado**.

### 5.3 Filtros — o que agrega

| Filtro | Descartados rendem | t | Veredito |
|---|---|---|---|
| Histograma TMO nao-profundo | -$0.08 | +2.06 | **usar** |
| Spread <= 260 | -$0.54 | — | **usar** (99% e' condicao de mercado, nao custo) |
| Confluencia MTF do TMO | **+$2.86** | +0.62 | nao usar — joga lucro fora |
| Veto de zona (OB/OS) | — | — | validado, mas redundante (sinais do SP nascem 100% fora de zona) |

### 5.4 Hipoteses MORTAS (nao re-testar)

TMO-cruzamento como gatilho (assimetria ~0 em 5 TFs) · SAR cruzamento-a-cruzamento
(-2,34M pts em 8 meses) · MovConsistency como filtro de entrada (rho +0,042) ·
SP trendDir como regime para o TMO (OOS -154 / IS -306) · prove-it barra 5 ·
barra-1 como regra (-$422/trade; o calculo ingenuo dava +2.880 — vies de selecao) ·
TP por quantil e parcial · trailing (4 distancias + modulacao ATR; familia dominada) ·
degrau de BE acima de zero (+0,05xATR custa 1.700 pts/trade) · folga de BE abaixo de
zero (grade 4x5: o zero e' o maximo) · contra-trade pos-breakeven (0 de 12
combinacoes) · MACROSS/cruzamento PAC x EMAs (-2.972/trade, 8/8 meses negativos) ·
osciladores primos (MACD/RSI/TrendWave) · USDJPY (assimetria -0,251 ATR).

### 5.5 Leis empiricas

1. **Evento de mudanca nao tem direcao; ESTADO tem.** Cinco confirmacoes.
2. **Proteger ajuda; limitar destroi.** BE no zero e' otimo global: degrau acima poda
   a cauda, folga abaixo aumenta a perda. 10% dos ciclos somam +15,4M pts; os outros
   90% somam -16,1M.
3. **Filtro e' bom ou ruim PARA UM EVENTO**, nunca em abstrato.
4. **A volatilidade do ouro paga a conta.** Custo/ATR: XAUUSD 4,8% vs USDJPY 23,1%.
5. **O olho amostra a cauda; o CSV conta tudo.**

---

## 6. Armadilhas conhecidas (custaram caro)

1. **`input group` + `iCustom` = desalinhamento posicional.** Indicador consumido por
   EA NAO pode ter `input group`. Sintomas: erro `M7`, `TMOLen=2`, zero sinais.
2. **Assinatura obrigatoria:** todo programa imprime versao + eco dos parametros no
   `OnInit`.
3. **`#property tester_indicator`** quando o nome do indicador vier de input.
4. **`BarsCalculated` NAO forca o calculo** de indicador de outro timeframe — quem
   forca e' `CopyBuffer`. Usar como portao antes de qualquer CopyBuffer = DEADLOCK
   silencioso (zero trades, nenhum erro no log).
5. **O tester GUARDA os inputs da rodada anterior.** Ja' causou 3 rodadas erradas.
   Mitigacao: um unico enum seletor por EA.
6. **Ao aplicar patch, verificar que o GRAVADOR mudou.** Cabecalho de CSV declarando
   colunas que o `WriteRec` nao grava = 3 rodadas perdidas.
7. **CSV nomeado pela data de inicio** -> re-rodar o mesmo periodo sobrescreve.
8. **`FILE_COMMON` grava em `Terminal\Common\Files`.**
9. **SL de VENDA dispara no ASK; de COMPRA no BID.** A medicao define tudo sobre o
   BID: niveis de venda somam o spread.
10. **Filtro de conveniencia na analise e' selecao disfarcada.** `gap<=3000` e
    `cyc_bars>0` inflaram a medicao em 26% vs o backtest real.
11. **Refatorar codigo validado e' a atividade de maior risco.** Sempre reproduzir o
    resultado anterior apos refatorar.
12. **Buffer de sensor acoplado a input visual.** Corrigido no TMO (B8) e no
    ScalpPullback v2.02 (B4): buffers sempre calculados, visibilidade por
    `PLOT_DRAW_TYPE`.

---

## 7. Fila

1. **Rodar `SIG_PBSHALLOW`** (EA de medicao v1.20) — 4 configuracoes + 1 controle.
   Objetivo: mais trades/dia sem perder qualidade.
2. **Estrutura de mercado** (`est_micro`/`est_macro`/`est_acordo`, ja' gravadas pelo
   v1.20) — medir cada componente ISOLADO. Voto ponderado so' depois: peso e'
   parametro, e parametro sem medicao viola a R1.
3. **Modulo de dados historicos (Dukascopy)** — 4 anos, base universal reutilizavel,
   custom symbol no MT5, coluna de **proveniencia** por periodo e modelo de spread da
   Exness por cima. Unica forma de validar em anos.
4. **StressLab** — slippage, spread elevado e latencia sobre a base historica.
5. **Antes de conta real:** trava de simbolo/TF, limite de perda diaria, CSV em modo
   append (`FILE_WRITE` trunca e perde historico se o terminal reiniciar), sizing em
   JPY (o stop escala com ATR: p90 = 2x a mediana).
6. **Conta Raw/Zero:** ganho direto ~5%; recalibrar o filtro de spread para termos
   RELATIVOS (percentil ou multiplo de ATR), senao nunca dispara.

**Nao fazer:** varrer timeframes antes de ter desenho validado; testar osciladores da
mesma familia; re-testar a lista de mortos; OOP antes de existir uma segunda
estrategia que compartilhe codigo.
