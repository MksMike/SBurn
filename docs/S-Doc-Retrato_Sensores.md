# SBurn — Primeiro retrato das familias de sensores
**Versao:** 1.0 | **Atualizado:** 2026-08-19

Fecha o item da fila *"analisar os seis sensores ja' gravados"*, aberto desde
antes de 2026-08-17. **Isto e' triagem exploratoria, nao achado.** Nada aqui
promove hipotese.

---

## 1. O dado que existia nao servia

O CSV de referencia que todo mundo citava (712 sinais) e' inutil **duas vezes**:

| | arquivo antigo | arquivo novo |
|---|---|---|
| janela | 2026-01-01 a **2026-01-27** | 2026-02-01 a 2026-08-17 |
| mes valido? | **nao** — janeiro inteiro, reprovado pela armadilha 13 | sim |
| fonte do sinal | `InpSigSource=0` = **SIG_TMO1** | `InpSigSource=2` = **SIG_SP** |
| sinais | 712 | **568** |

`SIG_TMO1` e' o cruzamento do TMO — **hipotese morta** (secao 5.4: assimetria ~0
em 5 TFs). Aqueles 712 sinais mediam sensores em volta de um gatilho enterrado,
no mes condenado.

O arquivo limpo que ja' existia (`..._2026-06-01.csv`) tem so' 214 sinais de
2,5 meses. Por isso a coleta foi refeita em 2026-08-19 na janela valida inteira,
com `SIG_SP` (buffer 26), o mesmo sinal do EA operacional.

**Coleta nova:** 568 sinais, 7 meses, distribuicao **uniforme** — 81/83/93/89/89/
92/41. Sem a concentracao que afeta os 76 trades: o corte de spread e o
histograma nao atuam aqui, entao sinal nao vira trade e a amostra fica cheia.
`falhas CopyBuffer=0`. Duas colunas constantes, ambas explicadas (`status=PASS`
porque `InpMinConsist=0`, e `n_ticks=75` e' o proprio input) — nao e' armadilha 13.

---

## 2. Pre-registro (R2), escrito antes de rodar

**Hipotese:** os sinais que o sensor marca como favoraveis tem assimetria
(medMFE − medMAE, Entrada A) maior que os desfavoraveis.

**Criterio de ACHADO — as tres juntas:** (a) diferenca > custo; (b) mesmo sinal
nos tres horizontes 5/15/30 barras; (c) presente em >= 5 dos 7 meses.

**Sensores direcionais** (`st_local`, `st_regime`, `est_micro`, `est_macro`)
sao separados por **concordancia com `dir`**, nao pelo valor bruto: MFE/MAE ja'
sao relativos a' direcao, entao separar por `st_local=+1` agrupa compras com
vendas e o numero nao quer dizer nada.

---

## 3. A correcao que mudou o resultado

A primeira passagem mediu assimetria em **pontos** e produziu 8 "aprovados",
com a familia `vol` inteira entre eles. Isso e' artefato de unidade: grupo mais
volatil tem MFE maior **e** MAE maior, e a diferenca em pontos cresce so' por
escala. Normalizando por `atr_ent`:

| sensor | em pontos | em ATR | mudou? |
|---|---|---|---|
| `est_micro` concorda | +2.294 / 5 meses | +0,194 / **3 meses** | **caiu** |
| `st_local` concorda | −2.671 / 5 meses | −0,274 / **4 meses** | **caiu** |
| `liq_frac` | −1.890 / 5 meses | −0,323 / **4 meses** | **caiu** |
| `vol_medr` | +3.552 / 5 meses | +0,567 / 5 meses | caiu p/ 2 condicoes |
| `vol_eff` | +2.145 / 3 meses | +0,367 / **5 meses** | **entrou** |
| `liq_r50` | −1.328 / 4 meses | −0,237 / **5 meses** | **entrou** |

**Toda assimetria deste projeto deveria ser reportada em ATR, nunca em pontos.**

---

## 4. Resultado (568 sinais, ATR mediano na entrada = 5.395 pts)

Assimetria de todos os sinais: +0,054 ATR (5 barras), +0,051 (15), +0,002 (30).

**Passaram nas tres condicoes:**

| familia | sensor | dif 15b | meses |
|---|---|---|---|
| vol | **`vol_std` > mediana** | **+0,606 ATR** | **6/7** |
| vol | **`vol_eff` > mediana** (Efficiency Ratio) | **+0,367 ATR** | 5/7 |
| estrutura M5 | `est_macro` concorda com `dir` | −0,288 ATR | 6/7 |
| liquidez | `liq_r50` > mediana | −0,237 ATR | 5/7 |
| calendario | `cal_lon` > mediana | −0,227 ATR | 5/7 |

Sinal negativo nao e' inutil: um sensor que separa ao contrario e' usavel
invertido. Mas ai' vale o **teste do descartado** — o valor esta' no desempenho
do que ele REMOVE, nao no do que ele mantem.

**Passaram em duas** (hipotese, nao achado): `vol_medr` +0,567 (5/7),
`st_regime` +0,350 (3/7), `liq_frac` −0,323 (4/7), `st_local` −0,274 (4/7),
`bs_above` +0,204 (3/7), `est_micro` +0,194 (3/7), `cal_ny` −0,173 (5/7),
`liq_pdl` +0,112 (5/7), `liq_pdh` −0,069 (4/7), `cal_asia` +0,064 (4/7).

---

## 5. Ressalvas — ler antes de agir sobre qualquer linha acima

1. **~20 sensores testados, 5 passaram.** Nao ha' correcao para comparacoes
   multiplas. Com 20 testes e um crivo frouxo, alguns passam por acaso. Isto e'
   uma peneira para escolher o que pre-registrar, nao um resultado.
2. **A condicao (a) saiu mais fraca do que eu quis.** O custo de 260 pts vale
   **0,048 ATR** — quase tudo passa. Na pratica o crivo foi (b)+(c). Foi a lei 4
   em acao ("a volatilidade do ouro paga a conta") e eu nao tinha percebido ao
   escrever o criterio em pontos.
3. **Assimetria e' condicao NECESSARIA, nao suficiente** (secao 4). E MFE/MAE
   dizem O QUE aconteceu, nunca em QUE ORDEM.
4. **Corte pela mediana e' arbitrario.** Nenhum limiar aqui foi calibrado; sao
   cortes de triagem. Qualquer um que vire parametro tem de ser medido.
5. **Um servidor de demo, um simbolo, 6,5 meses.**

---

## 6. O que isto sugere fazer

O sinal mais forte e mais coerente vem da familia que a fila ja' apontava:
**regime de volatilidade que o ATR nao captura.** `vol_std` (6/7 meses) e
`vol_eff` (5/7) apontam na mesma direcao e sobrevivem justamente a'
normalizacao por ATR — ou seja, medem algo que o ATR nao mede.

O `vol_eff` e' o **Efficiency Ratio**, e a fila registra que ele nunca foi
testado como classificador de regime. Continua nao tendo sido: isto e' triagem.

**Proximo passo correto (R2, R7):** pre-registrar UMA hipotese — a mais forte —
com criterio escrito antes, e testa-la como coluna/filtro no EA de medicao,
incluindo o teste do descartado. Nao sair implementando cinco sensores.

Reproduzir: `python analise\S-Py-Retrato_Sensores.py`
