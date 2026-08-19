# Pre-registro — `SIG_PBSHALLOW` (item 1 da fila)

**Data:** 2026-08-19 | **Escrito ANTES de rodar** (R2) | **Maquina:** PC-Escritorio

---

## 1. Hipotese

O titular fica no mercado 9% do tempo e participa de 31% do movimento direcional
que ele mesmo identifica (CLAUDE.md 5.2). O gatilho do SP exige o preco **voltar ao
canal PAC**, condicao rara: todos os 337 sinais medidos tem recuo de 1 a 3 barras, e
a maquina de estados nao gera nada alem disso.

Medido antes: **a profundidade do recuo nao se correlaciona com o resultado**
(rho = -0,03).

**Hipotese:** se a profundidade nao importa, afrouxar a definicao de recuo —
contar barras fechando contra a tendencia dentro do estado, sem exigir retorno ao
canal PAC — gera **mais sinais por dia sem perder assimetria por sinal**.

**Hipotese nula que ela precisa derrubar:** o canal PAC nao e' burocracia; ele e'
o que separa recuo de reversao. Afrouxar gera mais sinais, e os sinais a mais sao
piores, derrubando a assimetria mediana.

---

## 2. Regra medida

`SinalPullbackRaso()` ([S-EA-Test_ConsistencyGate.mq5:990](../MQL5/Experts/SBurn/S-EA-Test_ConsistencyGate.mq5#L990)):

1. Estado: `trendDir` do SP no TF do grafico (buffer 27) tem de concordar com o
   regime do SP no `InpSPTF` (M30). Sem estado, sem sinal.
2. A barra fechada mais recente tem de **retomar** a favor (fecho contra fecho).
3. As barras imediatamente anteriores a ela tem de somar entre `InpPbMin` e
   `InpPbMax` fechos **contra** a tendencia.
4. Cooldown de `InpPbCool` barras entre sinais.

Nao exige retorno ao canal PAC — essa e' a unica diferenca contra o titular.

---

## 3. Grade — 4 configuracoes + 1 controle

Janela unica: **XAUUSDm M5, 2026.01.01 - 2026.08.18**, "Every tick based on real
ticks". Todos os demais inputs nos defaults compilados; o `.set` de cada rodada
declara **so'** o que muda (evita a armadilha 5).

| Rodada | `InpSigSource` | `InpPbMin` | `InpPbMax` | `InpPbCool` | O que isola |
|---|---|---|---|---|---|
| **P1** | PBSHALLOW | 1 | 2 | 3 | recuo curto so' |
| **P2** | PBSHALLOW | 1 | 4 | 3 | faixa larga (default) |
| **P3** | PBSHALLOW | 2 | 4 | 3 | exclui a respirada de 1 barra |
| **P4** | PBSHALLOW | 1 | 4 | 6 | faixa larga, cooldown dobrado |
| **CTRL** | SP (buffer 26) | — | — | — | o gatilho do titular, mesma janela |

P1 vs P2 e P2 vs P3 isolam a **profundidade**. P2 vs P4 isola a **frequencia** com
a profundidade fixa. O controle da' o denominador de tudo.

---

## 4. Criterio de decisao — escrito antes, nao negociavel depois

Metricas do padrao do projeto (CLAUDE.md secao 4): entrada **A** (bid do 1o tick da
barra seguinte ao sinal), horizontes de **5/15/30 barras do TF do grafico**,
**assimetria = medMFE - medMAE**, em pontos.

**Custo** = spread mediano medido no proprio CSV, linha a linha (referencia
conhecida: 260 pts). Nao usar valor de fora do arquivo.

| Resultado | Veredito |
|---|---|
| assimetria(30) **<= custo** | **REJEITA**, qualquer que seja a frequencia. Sinal que nao paga o spread nao vira nada. |
| assimetria(30) **> custo** E sinais/dia **> CTRL** E assimetria **>= CTRL** | **PROMOVE a candidato** — vira grade no EA operacional. |
| assimetria(30) **> custo** E sinais/dia **> CTRL** mas assimetria **< CTRL** | **TRADE-OFF REGISTRADO**, nao promocao. Mais participacao por menos qualidade por sinal e' decisao do Mike, nao consequencia automatica. |
| sinais/dia **<= CTRL** | **REJEITA** — a hipotese inteira era frequencia. Sem ela, nao ha' o que discutir. |

**Ressalvas que ja' andam junto do numero (nao sao descobertas posteriores):**

- **MFE e' excursao maxima, nao lucro capturavel.** Assimetria positiva e'
  condicao necessaria, nunca suficiente (lei do projeto).
- **Ordem importa.** MFE/MAE dizem o QUE aconteceu, nunca em QUE ORDEM. Nada aqui
  autoriza dizer "alcanca X antes do stop".
- A janela inclui **2026.01**, que ainda nao passou pelo teste de trocas/1M no
  XAUUSDm (armadilha 13). Comparacao **entre** as 5 rodadas e' valida (o vies e'
  comum as cinco); nivel absoluto, nao.
- Promocao aqui significa **virar grade no EA operacional para medicao**, nunca
  "ligar". Meses nao sao anos.
