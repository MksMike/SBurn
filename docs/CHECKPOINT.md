# CHECKPOINT — sessao de 2026-08-19

**PROVISORIO — documento de RETOMADA.** Serve para reentrar no contexto sem
reler a sessao. Nao substitui a `CLAUDE.md`, que continua sendo a fonte de
verdade em conflito.

**Maquina:** PC-Escritorio (`MIKE-PC`) | **Servidor das medicoes:**
`Exness-MT5Trial5` — **DEMO**, nao a conta real.

---

## 0. Leia isto primeiro (30 segundos)

1. **A referencia do projeto mudou.** Nao e' mais *137 trades / +$1.308,59 /
   ret-DD 26,6x*. E' **76 operacoes / +$777,23 / DD de saldo $23,37 / PF 7,41**,
   janela **2026.02.01-08.18**. Metade do numero antigo era um mes de tick
   reconstruido.
2. **A piramide voltou a ficar desligada** (v2.05). Foi ligada e revertida no
   mesmo dia — o numero que a ligou era de janeiro.
3. **Regra nova: R8 — portabilidade por desenho.** O projeto tem de rodar em
   qualquer corretora e qualquer conta. Isso reordenou a fila inteira.
4. **Nada esta validado.** 76 operacoes, dois meses com zero trade, tres dias
   fazendo 61% do lucro, tudo em servidor de demo.

---

## 1. Codigo — o que mudou

| Versao | Mudanca | Estado |
|---|---|---|
| **v2.03** | `[B16]` ticket da adicao via `ResultOrder()` + 2 fallbacks; `[B17]` contadores separados (`rejeitadas` / `sem_ticket`), cada um contando uma vez por adicao | commitada |
| **v2.04** | `InpPirEnabled` false -> **true** | commitada e **revertida** |
| **v2.05** | `InpPirEnabled` true -> **false** | **atual** |
| `S-Py-Perfil_Spread.py` **v1.05** | secao nova "caminho do BID"; alerta corrigido duas vezes | atual |
| `S-Py-Compara_PBShallow.py` | novo — compara rodadas do EA de medicao | criado |

Nenhuma linha de logica de trading foi tocada em nenhuma versao do EA.
Compilacao sempre 0 erros / 0 warnings. `sem_ticket=0` em todas as rodadas.

**Verificacao da v2.05:** rodada com `.set` VAZIO (forca os defaults compilados)
imprime `piramide=off` e reproduz **$777,23** exato na janela valida.

---

## 2. O achado central: 2026-01 e' invalido

### 2.1 O que decide (medido na fonte, 64,4M ticks)

**Passo do BID por tick** — `S-Py-Perfil_Spread.py` secao 4, XAUUSD @ Real3
(unico export que alcanca janeiro):

| mes | passo p50 | **passo p90** | ticks/min | pts/min |
|---|---|---|---|---|
| **2026.01** | **40** | **82** | **467,5** | 18.699 |
| 2026.02 | 87 | 209 | 292,5 | 25.450 |
| 2026.03 | 79 | 241 | 404,9 | 31.984 |
| 2026.04-08 | 60-68 | 200-238 | 198-265 | 12.891-16.168 |

Janeiro tem o **mesmo caminho total por minuto** partido em **1,86x mais ticks,
sem salto** (p90 82 contra 200-241). E' **tick reconstruido de barra M1**:
preserva OHLC — por isso MFE/MAE e ATR de barra ficam normais — e **inventa o
caminho intraminuto**, que e' onde o BE e o stop vivem. 63% dos trades saem por BE.

**Janeiro NAO e' recuperavel re-precificando.** Modelo de spread conserta o ask;
nao reconstroi o caminho do bid.

### 2.2 O dano nao e' custo, e' selecao

Re-precificando exato, o mes inteiro muda **-$10,66 (1,7%)**. O que contamina e'
que `InpMaxSpread=260` aprovou **100% dos sinais de janeiro** contra 0% de abril
e maio: **em janeiro o filtro mais valioso da estrategia estava inerte**, e 49%
da referencia veio dali.

### 2.3 A janela valida esta LIMPA — medida no simbolo certo

XAUUSDm 2026.02.17-08.19, os dois canais:

| mes | trocas/1M | passo p90 | veredito |
|---|---|---|---|
| 02 (17-28) | 26.697 | 275 | ok |
| 03 | 9.431 | 249 | ok (denso, mas com salto) |
| 04 | 18.278 | 247 | ok |
| 05 | 6.457 | 238 | ok |
| 06 | 40.703 | 218 | ok |
| 07 | **1.750** | 202 | **ok — e e' 53% da referencia** |
| 08 | 6.216 | 230 | ok |

Zero alertas. Junho, julho e agosto aparecem em **dois exports independentes** e
dao numeros **identicos** — checagem de que a medida e' do dado, nao do pipeline.

### 2.4 O criterio passou por quatro versoes

| # | teste | por que caiu |
|---|---|---|
| 1 | valores distintos de spread | erra nos DOIS sentidos: 2026.01 tem 343 valores (o maior dos 8 meses) e e' podre; julho tem 11 e e' bom |
| 2 | trocas/1M | correto, mas so' enxerga o canal do ASK |
| 3 | passo **p50** do BID | quase deixa janeiro passar (0,61x contra corte de 0,6) |
| **4** | **passo p90 do BID** | **separa limpo: 0,38x contra 0,93-1,16x** |

E o alerta da v1.04 usava OR com densidade e condenou **marco** (falso positivo).
Corrigido na v1.05: **densidade alta sozinha e' mes movimentado, nao defeito.**
Registrado como armadilha 15 na `CLAUDE.md`.

---

## 3. Numeros correntes (janela valida, XAUUSDm M5 @ Trial5, 0.01 lote)

| Config | pir | Lucro | DD saldo | DD cap | PF | Negoc. | Recuperacao |
|---|---|---|---|---|---|---|---|
| A_TITULAR | off | $738,18 | $70,02 | $187,34 | 4,00 | 118 | 3,94 |
| **C_HIST (default)** | **off** | **$777,23** | **$23,37** | $187,34 | **7,41** | 76 | **4,15** |
| C_HIST sem R2 | off | $751,58 | $21,57 | $187,34 | 9,96 | 58 | 4,01 |
| C_HIST | ON | $962,49 | $53,17 | $426,52 | 4,25 | 141 | 2,26 |
| B_CONFLU / D_COMBO | off | ~$157 | — | — | ~10 | 11-13 | ~2,3 |

**Tabela 5.1 re-medida:** sem filtros 477 / $853,32 / PF 1,54; +histograma 301 /
$719,23 / PF 1,80; **+histograma+spread 76 / $777,23 / PF 7,41**.

**Concentracao — vai junto do numero, sempre:** abril e maio com **ZERO**
operacoes (o corte absoluto de 260 barra 100% dos sinais); marco com 2; julho
com 40 de 76 (**53%**) e o pior rendimento por trade ($3,42); **tres dias fazem
61% do lucro**; um unico trade (2026.03.19) rende $267,14 = 34,7%.

**Contribuicoes marginais:** R2 = +$25,65 em 18 trades. Piramide = +$185,26 por
+$239,18 de DD = **0,77x** (era 5,14x com janeiro; janeiro sozinho e' **84,9%**
do lucro marginal dela).

**Grade de `InpMaxSpread`** (pre-registro em `docs/S-Doc-PreReg_Spread.md`):
260 -> 280 rende +$1,00/trade; 280 -> 300 **+$9,82**; 300 -> 320 **-$0,22**;
depois piora. Veredito: **manter 260, registrar 300 como hipotese** para OOS.

---

## 4. Erros meus que o tribunal corrigiu

Dois workflows adversariais, 13 agentes. O que caiu:

1. **"Recuperacao 7,40 -> 4,15 e' degradacao"** — falso, e com o sinal invertido.
   `1387,20/7,40 = 187,46` e `777,23/4,15 = 187,28`: **o mesmo drawdown**.
   Excluir janeiro tirou $609,97 de lucro e $0,06 de risco. Na curva de trades
   fechados a exclusao **melhora** tudo: ret/DD 19,27 -> 32,92, PF 4,62 -> 7,34.
2. **"SIG_PBSHALLOW: 4 de 4 reprovados"** — precisao falsa. P2/P3/P4 sim,
   robustamente. **P1 e' INDECIDIVEL** (P(assim>custo) = 0,55 -> 0,44), e o
   proprio criterio se moveu: o custo mediano sobe de 260 para 280 quando janeiro
   sai. **A trave andou com a medida.**
3. **"A assimetria decai com o horizonte"** — ruido lido como estrutura. Trocando
   mediana por media, as quatro curvas crescem.
4. **`sinais/dia` com denominador diferente em cada linha.** Com denominador
   comum de 182 dias o CTRL alinhado cai de 3,15 para 2,13.
5. **`be_a2l1` nao mede o titular** — e' degrau de +0,05xATR, hipotese ja' morta
   na 5.4. A grade nao tem degrau ZERO.
6. **Montei o caso inteiro sobre o canal ASK.** Os tres testes que usei estao
   certos e sao pequenos. **O canal BID nunca tinha sido testado, e e' ele que
   decide.** Cheguei na resposta certa por um caminho que nao a sustentava.

**Piramide: o status correto e' INDECIDIVEL, nao "reprovada"** — 65 adicoes em 5
meses efetivos. O default OFF fica; o veredito, nao.

---

## 5. Onde estao os dados

**Exports de tick — FORA do git** (3 arquivos, ~5,9 GB), em `C:\dev\Historico\`:

| arquivo | simbolo | periodo |
|---|---|---|
| `XAUUSD_202601012305_202608180514.csv` | XAUUSD @ Real3 | 2026.01.01 - 08.18 |
| `XAUUSDm_202602170000_202608190914.csv` | XAUUSDm @ Trial5 | 2026.02.17 - 08.19 |
| `XAUUSDm_202605140000_202608190833.csv` | XAUUSDm @ Trial5 | 2026.05.14 - 08.19 |

**Relatorios do MT5 — tambem fora do git**, em `C:\MT5\Exness\rel_*.htm`.
Isso e' um problema conhecido: nenhum numero de piramide e' auditavel a partir
do repositorio (ver item 1 da secao 6).

**CSVs de operacao:** `dados\ops_v203_pir{ON,OFF}.csv` — byte-identicos, porque o
gravador filtra por `InpMagic` e nao escreve as pernas da piramide.

---

## 6. O que fazer quando voltar, em ordem

1. **Consertar o gravador de CSV do EA.** Nao escreve (a) as pernas da piramide
   nem (b) o fechamento forcado de fim de teste — por isso `ops_pirON.csv` e
   `pirOFF.csv` sao byte-identicos e o CSV (75 / $769,33) nunca reconcilia com o
   relatorio (76 / $777,23). **Sem isso nada da piramide e' auditavel.**
   ~30 min, sem risco de comportamento.
2. **Instrumentar o EA de medicao para a R8:** colunas de custo (spread +
   comissao do simbolo) e as tres formas de filtro de spread lado a lado. E' o
   passo R7 obrigatorio antes de qualquer auto-configuracao.
3. **Comissao.** Nunca foi medida. Zero e' suposicao. Numa Raw/Zero e' o custo
   dominante e entra direto no degrau do BE.
4. **Re-medir o valor do filtro de spread** (5.3). Na janela valida o teste do
   descartado por assimetria30 nao acha valor de selecao (p=0,431) — mas essa
   metrica tem IC de 13-21x o limiar, entao o resultado nulo e' falta de
   potencia, nao ausencia de efeito. Refazer em P&L, nao em assimetria.
5. **Auto-configuracao por conta** (`docs\S-Doc-Portabilidade.md`).
6. **Base historica independente de corretora.** Sob a R8 e' o unico caminho para
   validar. A base atual nao sustenta validacao de nada.

**Nao fazer:** mais nenhuma grade sobre esses 76 trades. Ja' produziu numero
bonito e sem valor duas vezes hoje.

---

## 7. Bloqueado em voce

1. **Exportar XAUUSDm de 2026.01.01 a 2026.02.17.** Fecha a condenacao de janeiro
   **no simbolo da referencia** — hoje ela e' inferencia a partir do XAUUSD@Real3
   (inferencia forte: nos meses sobrepostos os dois feeds sao praticamente o
   mesmo, mas nao e' medicao). Nao muda nenhum numero, so' a justificativa.
2. **Login no `Exness-MT5Real41`** para baixar o historico da conta real — hoje
   so' tem `202608`. Todas as medicoes do projeto sairam de servidor de DEMO
   enquanto a doc afirmava conta real (armadilha 14).

---

## 8. Reproduzir

    # backtest de referencia (defaults compilados, janela valida)
    terminal64.exe /config:<ini com FromDate=2026.02.01 ToDate=2026.08.18>
    # esperado: piramide=off, final balance 10777.23, 76 negociacoes

    # autenticidade de um export de ticks (os dois canais)
    python analise\S-Py-Perfil_Spread.py <export.csv> --rotulo "<conta>"

Commits da sessao: `5579f57` (v2.03) -> `cf3260e`. Dez no total.
