# SBurn — Portabilidade e auto-configuracao por conta
**Versao:** 1.0 | **Criado:** 2026-08-19 | **Status:** ESPECIFICACAO — nada implementado

Decisao do Mike em 2026-08-19: **o projeto inteiro deve ser desenhado para operar
em qualquer corretora e em qualquer tipo de conta** (Standard, Raw, Zero, Pro).
Este documento e' a especificacao dessa exigencia. A regra correspondente e' a
**R8** do `CLAUDE.md`.

---

## 1. Por que isso deixou de ser opcional

O EA hoje **nao** e' portavel. Dois parametros o prendem a uma conta:

| Parametro | Forma | Porta? |
|---|---|---|
| `InpArmATR` 0,73 · `InpStopATR` 3,67 | multiplo de ATR | **sim** |
| `InpPirInicioATR` · `InpPirPassoATR` | multiplo de ATR | **sim** |
| `InpR2Piso` / `InpR2Calma` / `InpR2Validade` | barras do TF | **sim** |
| **`InpMaxSpread` = 260** | **pontos absolutos** | **NAO** |
| **`InpHistMax` = 2,20** | unidades do TMO | **a verificar** |
| **degrau do breakeven = ZERO** | implicito, ignora custo | **NAO** |

### 1.1 O filtro de spread desaparece numa conta Raw — medido

| | p50 do spread | passa em `<= 260` |
|---|---|---|
| XAUUSDm Standard | 260 | ~50% |
| XAUUSD @ Raw (Real3) | **90** | **100%** |

Numa conta Raw o filtro nunca morde. O custo disso esta medido na janela valida
(2026.02.01-08.18, C_HIST, R2 on, piramide off):

| | Lucro | DD saldo | PF | Fator de recuperacao |
|---|---|---|---|---|
| com filtro (260) | $777,23 | **$23,37** | **7,41** | **4,15** |
| **sem filtro** (= o que acontece na Raw) | $719,23 | $196,06 | 1,80 | 1,75 |

**PF de 7,41 para 1,80 e drawdown 8x maior.** Nao e' perda de ajuste fino: e' a
protecao sumindo sem aviso. Um parametro absoluto nao falha com erro — falha em
silencio.

### 1.2 O breakeven no zero e' estruturalmente um prejuizo

O BE atual leva o stop para o **nivel BID da entrada**. Para uma COMPRA, a entrada
sai no ASK e a saida ocorre no BID: sair no BE perde **exatamente um spread**, mais
comissao e mais derrapagem. Como ~63% dos trades saem pelo BE, isso e' o custo
dominante do desenho.

Medido na janela valida: saidas por BE rendem **-$0,435/trade** (41 trades).

---

## 2. O que a auto-configuracao tem de fazer

Um script que, ao rodar numa maquina/conta nova:

1. **Identifica** corretora, servidor, numero e **tipo** de conta, simbolo e digitos.
2. **Varre o historico daquela conta** e mede, do proprio feed:
   - distribuicao do **spread** (p10/p25/p50/p75/p90/p99, media, max);
   - **autenticidade do feed** por periodo (armadilha 13 — ver secao 4);
   - **comissao** round-trip por lote.
3. **Deriva o custo total round-trip em pontos**, por periodo:
   `custo_pts = spread_pts + comissao_em_pontos`
4. **Calibra** os parametros dependentes de conta e grava um arquivo de
   configuracao por conta, que o EA le no `OnInit`.
5. **Recusa-se a rodar** se o periodo pedido nao passar no teste de autenticidade.

### 2.1 Comissao em pontos

A comissao NAO aparece em export de ticks e NAO aparece no spread. Ela vem das
propriedades do simbolo e do historico de deals:

    comissao_pts = (comissao_round_trip_moeda / valor_do_ponto_por_lote) / lote

Sem isso, uma conta Raw parece 2,9x mais barata do que e'. **Zero e' um valor a
MEDIR, nunca a assumir** — inclusive em Standard, onde costuma ser zero mas nao
necessariamente e'.

### 2.2 O nivel de breakeven que nao da' prejuizo

    BE_nivel_bid = bid_entrada + (custo_pts + folga_derrapagem_pts) * dir

E o SL enviado ao servidor continua passando pela conversao da armadilha 9
(`NivelBidParaSL`): SL de VENDA dispara no ASK, entao soma o spread corrente.

> ### CONFLITO MEDIDO — ler antes de implementar
>
> Isto **contradiz uma lei empirica do projeto** (`CLAUDE.md` 5.5, lei 2):
> *"Proteger ajuda; limitar destroi. BE no zero e' otimo global: degrau acima poda
> a cauda."* Medido na Standard: degrau de **+0,05xATR custa 1.700 pts/trade**.
>
> Na Standard, `custo_pts` ~ 260 = **0,047xATR** — praticamente o mesmo degrau que
> ja' foi medido e reprovado. Ou seja: **na Standard, "BE sem prejuizo" e'
> exatamente a configuracao que a medicao rejeitou.**
>
> O motivo e' a lei 2 combinada com a distribuicao de cauda: subir o BE salva
> ~260 pts em cada um dos 63% de scratches, mas poda parte dos 10% de ciclos que
> respondem por +15,4M pts. A conta nao fecha na Standard.
>
> **Por que a auto-configuracao continua sendo a resposta certa:** o tamanho desse
> trade-off **depende do custo da conta**. Numa Raw com `custo_pts` ~ 90 + comissao,
> o degrau exigido e' ~1/3 do da Standard e poda muito menos cauda — o otimo pode
> perfeitamente ser diferente de zero la'. Zero nao e' uma lei universal: e' o
> otimo **medido numa conta**.
>
> **Portanto a auto-configuracao NAO aplica a formula direto.** Ela:
> 1. calcula `custo_pts` da conta;
> 2. roda uma grade de degrau `{0, ½·custo, custo, 1½·custo}` no historico
>    **daquela conta**;
> 3. escolhe **por medicao**, e registra o numero ao lado da escolha.
>
> Formula sem medicao viola a R1. O que a auto-configuracao automatiza e' a
> **calibracao**, nunca a **decisao**.

### 2.3 O filtro de spread em termos relativos

Tres formas candidatas. **Nenhuma esta calibrada** — a escolha e' medicao, R1.

| Forma | Porta entre contas? | Evidencia atual |
|---|---|---|
| absoluto `spread <= K` | **nao** | e' o de hoje; some na Raw |
| `spread / ATR <= k` | sim | **nao escolhe melhor** que o absoluto: teste do descartado a taxa igualada da mantido +462 / descartado -455, contra +527 / -491 do absoluto. Os dois IC95 cruzam zero. E e' **menos estavel** entre meses (CV 18,0% contra 9,8%). |
| `spread <= percentil movel do proprio spread` | sim | forma que a evidencia favorece por construcao (adapta ao regime da conta), **ainda nao medida** — o teste offline nao igualou a taxa de aprovacao por causa da quantizacao do spread. |

**Achado que atrapalha as tres:** o spread da Exness e' **quantizado** em degraus
(240, 260, 264, 280, 308). Qualquer limiar entre dois degraus da' o mesmo
resultado — nao e' um dial continuo, sao ~5 regimes discretos. Um limiar por
percentil cai em cima de platos e nao entrega a taxa de aprovacao pedida.

---

## 3. Onde isso entra no codigo

| Peca | Papel | Estado |
|---|---|---|
| `setup\S-Ps-Perfil_Conta.ps1` | identifica corretora/servidor/conta/tipo, dispara o export de ticks e a leitura de comissao | **nao existe** |
| `analise\S-Py-Perfil_Spread.py` | ja' perfila spread e autenticidade (trocas/1M) de um export de ticks | **existe, v1.02** |
| `analise\S-Py-Perfil_Conta.py` | consolida spread + comissao -> `custo_pts` por periodo; roda a grade de degrau; emite a config | **nao existe** |
| `MQL5\Include\SBurn\S-Include-ContaConfig.mqh` | o EA le a config da conta no `OnInit`; sem config valida, **recusa operar** | **nao existe** |
| `S-EA-Test_ConsistencyGate` | colunas das 3 formas de filtro de spread, para medir antes de construir (R7) | **nao existe** |

**Ordem obrigatoria (R7):** as colunas no EA de medicao vem PRIMEIRO. So' o que
passar no tribunal vira `S-Include-ContaConfig.mqh`.

---

## 4. Portao de autenticidade — o script tem de recusar dado ruim

A auto-configuracao le o historico da corretora. Se o historico for sintetico, ela
se auto-configura errado com confianca. Dois testes, do mais barato ao mais caro:

1. **Valores distintos de spread por mes** (barato, roda no CSV do EA de medicao).
   **Um unico valor num mes inteiro e' veredito, nao suspeita.** Medido em
   2026-08-19: XAUUSDm @ Exness-MT5Trial5, 2026-01, spread = exatamente **160,0**
   em 100% dos sinais, nos 25 dias de pregao, em 5 arquivos independentes; contra
   3 a 20 valores distintos em cada um dos outros 7 meses.
2. **Trocas por milhao de ticks** (`S-Py-Perfil_Spread.py`, exige export de ticks).
   Mais sensivel: pega spread que varia pouco mas varia.

O teste 1 nao substitui o 2 — spread quantizado real tambem da' poucos valores.
Mas um valor unico em 25 dias nenhum feed real produz.

**O periodo reprovado nao e' impreciso: e' invalido para desenho path-dependent.**
Com spread constante o custo intrabar nao varia e o **breakeven nunca derrapa** —
e 63% dos trades saem pelo BE. Medido: `pnl_pts` mediano das saidas por BE e'
**-20 em 2026-01 contra -47 no resto**.

---

## 5. Ressalvas honestas desta especificacao

- **Auto-configuracao amplia o espaco de busca.** Cada parametro que passa a ser
  derivado da conta e' um grau de liberdade a mais. Sem OOS por conta, isso e'
  sobreajuste automatizado. A calibracao tem de ter janela IS/OOS **dentro da
  conta**, e o resultado sai como *promissor*, nunca *validado*.
- **A base de validacao continua sendo de uma corretora so'.** Enquanto a
  referencia vier do historico de um broker, "portavel" e' desenho, nao medicao.
  Quem fecha isso e' o item da base historica independente (Dukascopy) — que sob a
  R8 deixa de ser desejavel e vira **caminho critico**.
- **Nada aqui foi implementado.** Este documento e' especificacao. Todo numero
  citado tem procedencia declarada; nenhum parametro novo tem valor default.
