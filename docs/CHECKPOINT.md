# CHECKPOINT — 2026-08-19

**Maquina:** PC-Escritorio (`MIKE-PC`) | **Servidor das medicoes:** `Exness-MT5Trial5` (DEMO)

> **Nome fora da convencao `S-Doc-*.md`** — foi pedido assim explicitamente.

---

## 1. O que mudou no codigo

| Versao | Mudanca | Estado |
|---|---|---|
| **v2.03** | `[B16]` ticket da adicao via `ResultOrder()` com 2 fallbacks; `[B17]` contadores separados (`rejeitadas` / `sem_ticket`), cada um contando **uma vez por adicao** | commitada |
| **v2.04** | `InpPirEnabled` false -> **true** | commitada, **depois revertida** |
| **v2.05** | `InpPirEnabled` true -> **false** | commitada |

Nenhuma linha de logica de trading foi tocada em nenhuma das tres. Compilacao
sempre 0 erros / 0 warnings.

**Prova de que a v2.03 e' neutra:** a v2.02 recompilada do git e a v2.03 dao
numeros **identicos** nas duas configuracoes. O patch conserta a CONTAGEM e
adiciona robustez, nao muda uma ordem.

---

## 2. O diagnostico que motivou a v2.03 estava errado

As "234 falhas" da v2.02 **nao** eram o caso `[B15]`. O log da propria rodada tem
**zero** linhas de `NAO identificada`: a busca por `DEAL_POSITION_ID` acertou o
ticket nas 106 adicoes. As 234 eram **rejeicoes `10018 market closed`**, todas de
**2026.01.06**, contadas a cada tick porque `g_pirAbertas` nao avanca quando a
ordem falha. Depois da v2.03: `adicoes=106 rejeitadas=1 sem_ticket=0`.

**Corolario:** o `[B14]` nunca mudou numero nenhum. v2.01 = v2.02 = 12616.32 no log
de ontem; v2.02 = v2.03 = 12617.25 hoje.

---

## 3. O achado do dia: 2026-01 e' invalido, e nao pelo motivo obvio

### 3.1 O que eu mediu primeiro (fraco)

`spread_sig_pts` tem **um unico valor — 160,0** em 100% dos sinais de 2026-01, nos
25 dias de pregao, nos 5 arquivos. Outros meses: 3 a 20 valores.

**Mas esse criterio erra nos dois sentidos:** julho tem so' 3 valores distintos e
99,7% de aprovacao no filtro, e julho e' **bom**.

### 3.2 O que decide (forte)

**Passo do BID por tick** — `dist_pts/(n_ticks-1)` do `CMovConsistencySensor`, que
le `tk.bid` e **nunca toca no ask**. Pool dos 5 CSVs, 5.228 sinais:

| mes | 01 | 02 | 03 | 04 | 05 | 06 | 07 | 08 |
|---|---|---|---|---|---|---|---|---|
| pts/tick | **43,1** | 107,5 | 104,4 | 97,3 | 103,7 | 97,8 | 97,2 | 105,9 |

- Invariante a ATR (razao 0,405-0,437 nos 5 quintis) e a hora (0,387-0,445 nas 23).
- **AUC 0,985.** 96,6% das janelas de janeiro abaixo do p1 de todos os outros meses.
- **Densidade nao explica:** `spearman(ticks/s, passo)` = -0,020 (p=0,18); no decil
  mais denso do pool, janeiro 45,3 contra 104,3.
- **Confirmado no P&L, imune a spread** (so' COMPRAS): derrapagem na saida por BE
  tem **0 de 36** acima de 100 pts em janeiro contra **9 de 20 (45%)** no resto.
  Reescalando o limiar pela densidade: 8% contra 45%, Fisher **p=0,0024**.
- **Fronteira:** ultimo dia defeituoso **2026-01-29** (49,3); 01-30 ja' normal (79,7).

**Assinatura:** o mesmo movimento real partido em ~2x mais passos, ~2,4x menores.
E' tick **reconstruido a partir de barra M1** — preserva OHLC (por isso MFE/MAE e
ATR de barra ficam normais, `vol_eff` p=0,284) e **inventa o caminho intraminuto**,
que e' exatamente onde o BE e o stop vivem. 63% dos trades saem por BE.

**Janeiro NAO e' recuperavel re-precificando.** Modelo de spread conserta o ask;
nao reconstroi o caminho do BID. O item 3 da fila serve para **substituir** o tick.

### 3.3 O dano nao e' custo, e' selecao

Re-precificando exato, o mes inteiro muda **-$10,66 (1,7%)**. O que contamina e'
que `InpMaxSpread=260` aprovou **100,0%** dos sinais de janeiro contra 45,7 / 3,6 /
**0,0** / **0,0** / 43,8 / 100 / 95,1% em fev-ago: **em janeiro o filtro mais
valioso da estrategia estava inerte**, e 49% da referencia veio dali.

---

## 4. A referencia, re-medida (2026.02.01-08.18)

XAUUSDm M5 @ Trial5, 100% ticks reais, 0.01 lote, `C_HIST`, R2 on.

| Config | pir | Lucro | DD saldo | DD cap | PF | Negoc. | Recuperacao |
|---|---|---|---|---|---|---|---|
| A_TITULAR | off | $738,18 | $70,02 | $187,34 | 4,00 | 118 | 3,94 |
| **C_HIST** | **off** | **$777,23** | **$23,37** | $187,34 | **7,41** | 76 | **4,15** |
| C_HIST sem R2 | off | $751,58 | $21,57 | $187,34 | 9,96 | 58 | 4,01 |
| C_HIST | ON | $962,49 | $53,17 | $426,52 | 4,25 | 141 | 2,26 |
| B_CONFLU / D_COMBO | off | ~$157 | — | — | ~10 | 11-13 | ~2,3 |

**Tabela de referencia 5.1, re-medida:** sem filtros 477 / $853,32 / PF 1,54;
+histograma 301 / $719,23 / PF 1,80; **+histograma+spread 76 / $777,23 / PF 7,41**.

**Concentracao, que vai na manchete:** abril e maio com **ZERO** operacoes; marco
com 2; julho com 40 de 76 (**53%**) e o pior rendimento por trade ($3,42); **tres
dias fazem 61% do lucro**; um unico trade (2026.03.19) rende $267,14 = 34,7%.

**R2 isolado:** +$25,65 e +18 trades na janela valida (era +$153,31 com janeiro).
**Piramide:** +$185,26 por +$239,18 de DD = **0,77x** (era 5,14x).

---

## 5. Correcoes que o tribunal fez em mim (R3/R4)

Dois workflows adversariais, 13 agentes, ~1,5M tokens. O que eles derrubaram:

1. **"Fator de recuperacao 7,40 -> 4,15 e' degradacao"** — **falso, e o sinal esta
   invertido.** `1387,20/7,40 = $187,46` e `777,23/4,15 = $187,28`: **o mesmo
   drawdown**. Excluir janeiro tirou $609,97 de lucro e $0,06 de risco. Na curva de
   trades fechados: ret/DD 19,27 -> **32,92**, PF 4,62 -> **7,34**, media/trade
   $9,38 -> **$10,26**. A exclusao **melhorou** todo indicador de qualidade.
2. **"SIG_PBSHALLOW: 4 de 4 reprovados"** — **precisao falsa.** P2/P3/P4 sim,
   robustamente. **P1 e' indecidivel** (P(assim>custo) = 0,55 na janela cheia,
   0,44 sem janeiro — cara ou coroa nas duas), e o proprio criterio se moveu junto:
   o custo mediano sobe de 260 para 280 quando janeiro sai. **A trave andou com a
   medida.**
3. **"A assimetria decai com o horizonte no PBSHALLOW e cresce no controle"** —
   **ruido lido como estrutura.** Trocando mediana por media, as quatro curvas
   crescem.
4. **`sinais/dia` com denominador diferente em cada linha** (dias ativos do braco,
   nao dias de pregao). Com denominador comum de 182 dias o CTRL alinhado cai de
   3,15 para 2,13 — 48% de inflacao, **a favor da hipotese**.
5. **`be_a2l1` nao mede o titular** — e' degrau de +0,05xATR, hipotese que a 5.4
   ja' matou. A grade nao tem degrau ZERO. Briguei com a censura de uma coluna que
   nao descreve a estrategia.
6. **Bootstrap iid subestimava o IC em 1,6-2,0x nos bracos de alta frequencia** e
   so' 1,10x no controle — distorcia a COMPARACAO, nao so' o nivel. 92-96% dos
   sinais P tem outro sinal dentro do proprio horizonte.
7. **Montei a decisao inteira sobre o canal ASK** (valores distintos, derrapagem do
   BE, custo direto). Os tres estao certos e os tres sao pequenos. **O canal BID
   nunca foi testado, e e' ele que decide.** Cheguei na resposta certa por um
   caminho que nao a sustentava.

O que **sobreviveu**: a tabela de assimetria reproduziu digito a digito; o script
implementa o pre-registro fielmente; e a exclusao de janeiro esta **certa** — com
justificativa trocada.

**Um erro que me imputaram e nao era meu:** "76 trades / $777,23". O CSV tem 75 /
$769,33, mas o relatorio tem 76 e `1387,20 - 609,97 = 777,23` exato. **O gravador
e' que nao registra o fechamento forcado de fim de teste.**

---

## 6. Decisao do Mike: R8 — portabilidade por desenho

**O projeto inteiro deve operar em qualquer corretora e qualquer tipo de conta.**
Documentado em `CLAUDE.md` (secao 0, R8, secao 3, fila), `README.md`, e
especificado em **`docs\S-Doc-Portabilidade.md`**.

Inclui um script que identifica corretora/conta, varre o historico daquela conta,
mede **spread e comissao**, e calibra o que depende de conta — inclusive o degrau
do breakeven, para que sair no BE nao seja prejuizo.

**Conflito medido, documentado e nao resolvido:** na Standard, "BE sem prejuizo"
e' ~0,047xATR, praticamente o degrau que a lei 2 mediu como **-1.700 pts/trade**.
Por isso a auto-configuracao calibra por **grade medida na propria conta**, nunca
por formula: automatiza a calibracao, jamais a decisao (R1).

---

## 7. Estado e proximo passo

**Aberto e mais grave que janeiro:** na janela valida, **o filtro de spread nao tem
valor de selecao detectavel** (mantidos 1.428 contra descartados 1.710, p=0,431).
A linha da 5.3 foi medida numa janela em que janeiro dominava o lado MANTIDO com o
filtro inerte. **Isso poe em duvida a config de referencia.**

Proximos, em ordem (fila da CLAUDE.md): auto-configuracao por conta -> filtro de
spread relativo -> comissao -> re-medir o valor do filtro -> `S-Py-Perfil_Spread.py`
sobre os `.tkc` -> consertar o gravador -> base independente de corretora.

**Nada aqui e' validado.** 76 operacoes em 6,5 meses, dois meses zerados, tres dias
fazendo 61% do lucro, tudo num servidor de demo.
