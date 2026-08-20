# Pre-registro — coluna de DESFECHO TITULAR no EA de medicao
**Versao:** 2.0 | **Atualizado:** 2026-08-20 | **Estado: IMPLEMENTADO (v1.29), VALIDADO, DESTRAVOU**

---

## 0. Enquadramento — ler antes do resultado

**Isto NAO e' "a solucao que destrava a frente do spread e a 5c".** E' o
**TESTE que decide se essas frentes sao decidiveis.**

A Etapa 0 da 5c mostrou que `n=9.088` (104 meses) da' 57% de poder: o problema
nao e' volume, e' a razao entre **dispersao do desfecho** e **efeito procurado**
(`MFE15/ATR` tem ~2,8 ATR entre quartis contra um efeito de ~0,3).

Um desfecho truncado pelo stop reduz a dispersao **por construcao** — e' por
isso que ele PODE destravar. Mas se a dispersao continuar grande contra 0,3
ATR, **a 5c segue bloqueada mesmo com a coluna pronta**, e a frente do spread
junto.

**Se nao destravar, e' resultado legitimo, nao fracasso da instrumentacao.**
Registrado aqui, antes de medir, para nao ser lido como fracasso depois.

---

## 1. A regra titular, extraida do EA operacional

Lida de `MQL5\Experts\SBurn\S-EA-Pullback_Live.mq5` v2.07. Cada valor com o
input de origem. **Nenhuma lacuna preenchida com valor plausivel** — foi assim
que o `tr_1` entrou.

### 1.1 ATR de referencia

| item | valor | origem |
|---|---|---|
| indicador | `iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod)` | linha 1004 |
| periodo | **14** | `InpATRPeriod` |
| timeframe | **o do grafico (M5)**, nao o de regime | `PERIOD_CURRENT` |
| shift lido | **1** (barra FECHADA) | `LeBuffer(g_hATR, 0, 1, ok)`, linha 633 |
| handle | proprio do EA, nao o do TMO | `g_hATR` |

**Confere com o EA de medicao?** SIM. O `S-EA-Test_ConsistencyGate` cria o TMO
em `PERIOD_CURRENT` repassando `InpATRPeriod` (linha 660-671), e o buffer 16 do
TMO e' `iATR(_Symbol, _Period, InpATRPeriod)`. `ReadCtxD` le no **shift 1**
(linha 1034). Com `InpATRPeriod=14` nos dois `.ini`, e' o mesmo ATR.

### 1.2 Stop inicial

    stopPts     = InpStopATR * atr            // InpStopATR = 3.67
    nivelBidStop = bid_entrada -/+ stopPts     // em termos de BID
    sl           = NivelBidParaSL(nivelBidStop, dir)

`NivelBidParaSL` implementa a **armadilha 9**: SL de VENDA dispara no ASK,
entao o nivel de venda **soma o spread corrente**. A simulacao tem de fazer o
mesmo, senao a venda para cedo demais.

### 1.3 Breakeven — o gatilho, medido no BID

    exc = (Bid() - g_bidEnt) / point * dir     // a cada tick, OnTick
    if(exc > g_mfe) g_mfe = exc
    ...
    if(g_mfe < g_armPts) return                // g_armPts = InpArmATR * atr
    PositionModify(t, NivelBidParaSL(g_bidEnt, dir), 0)

| item | valor | origem |
|---|---|---|
| gatilho | excursao favoravel **sobre o BID**, desde o **BID de entrada** | linha 1218 |
| limiar | **0,73 x ATR** | `InpArmATR` |
| destino do stop | **nivel BID da entrada** (degrau ZERO) | `g_bidEnt` |
| atualizacao | **a cada tick**, nao por barra | `OnTick`, linha 1216-1221 |

**Nao e' excursao sobre o preco de entrada.** Entrada de compra sai no ASK; o
gatilho e o destino sao ambos sobre o BID. Confundir os dois desloca tudo em um
spread.

### 1.4 Terceira saida — e o detalhe que quase me pegou

**Nao existe TP. Nao existe cap de tempo.** (`grep` por `InpTP|TakeProfit|tp =|
maxBarras` retorna vazio.) O trade que nao toca stop nem BE so' termina de uma
forma: **sinal novo do ScalpPullback**.

    double sinal = LeBuffer(g_hSPsig, 26, 1, okSig);   // linha 1277
    if(sinal == 0.0) return;
    if(g_temPos && !Fecha("SINAL")) return;            // linha 1284  <<<
    ...
    if(regime * dir <= 0) { g_vetoRegime++; return; }  // linha 1294
    if(!ContextoTMOaprova(dir)) return;                // linha 1299

> **O fechamento acontece ANTES de qualquer veto.** Um sinal **BRUTO** do SP
> (buffer 26, barra fechada, qualquer direcao) encerra a posicao — mesmo que
> esse sinal jamais fosse aceito como entrada por regime, histograma ou spread.
> **Os filtros governam a ABERTURA, nunca o FECHAMENTO.**

Se a simulacao usasse o sinal FILTRADO para fechar, os trades durariam mais do
que duram e o desfecho sairia sistematicamente otimista, sem erro nenhum no
log. E' a mesma classe de falha silenciosa da armadilha 13.

---

## 2. Calculo: caminhamento de tick, DENTRO do EA

**MFE/MAE nao dizem ORDEM.** Um desfecho simulado exige ordem: precisa saber se
o stop veio antes ou depois do BE. Portanto o calculo e' **tick a tick dentro
do EA de medicao**, que tem ticks reais — **nunca** offline reconstruindo de
barras M1.

Reconstrucao offline exige suposicao intrabarra, e e' exatamente ai' que o
otimismo silencioso entra: quando a barra contem stop E gatilho de BE, a ordem
escolhida muda o resultado e nao gera erro.

**Se o caminhamento de tick se mostrar inviavel, REPORTAR — nao cair para
barras.**

### 2.1 Convencoes pre-registradas

| convencao | escolha | por que |
|---|---|---|
| entrada | **convencao A do projeto**: bid do 1o tick da barra seguinte ao sinal | padrao da secao 4 do `CLAUDE.md` |
| custo | spread pago na **entrada E na saida**, lido do **tick real** | nao usar constante; o spread varia e e' o que a frente do spread investiga |
| empate intrabarra | resolver **sempre contra o trade** (pessimista) | e contar quantas vezes ocorreu, em coluna propria |

O empate deve ser raro no caminhamento de tick (dois eventos no mesmo tick),
mas se ocorrer nao pode ser resolvido a favor em silencio.

---

## 3. Sem sentinela — flag separada

As colunas `be_a*`, `tr_4` e `ct_*` gravam `-999999` = "nao saiu". Somar isso
como P&L deu media de **-56.726 pts** e quase virou armadilha 13 na analise do
descartado.

A coluna nova:

| coluna | conteudo |
|---|---|
| `tit_pnl` | P&L em pontos, **sempre numerico e valido** |
| `tit_saiu` | **1/0** — o trade encerrou dentro da janela de medicao? |
| `tit_motivo` | `STOP` / `BE` / `SINAL` / `ABERTO` |
| `tit_barras` | duracao ate' a saida |
| `tit_empate` | 1 se houve empate intrabarra resolvido contra o trade |

**Nunca sentinela dentro da coluna de valor.** Documentar no cabecalho do CSV.
Quando `tit_saiu=0`, `tit_pnl` carrega o P&L **em aberto no fim da janela**, que
e' um numero valido — e quem analisa decide se usa ou filtra, com a informacao
na mao.

---

## 4. QUALITY GATE — teste contra resposta conhecida

Mesmo espirito do controle com os dailies UTC no script de fuso: **nao aceitar
o instrumento so' porque ele roda.**

O EA operacional produziu, na janela de referencia (2026.02.01-08.18, Trial5,
ticks reais, principal sem piramide): **76 trades**, saidas **BE=41 STOP=6
SINAL=28**, lucro **$777,23**, DD de saldo **$23,37**, PF **7,41**.

Restringir a coluna simulada aos **MESMOS sinais que o operacional tomou**
(regime M30 concordando, histograma TMO < 2,20, spread <= 260) e comparar:

- n de trades
- P&L total
- **distribuicao de saidas** (quantos por STOP, quantos por BE, quantos por
  SINAL) — este e' o mais informativo: e' a assinatura da ordem dos eventos,
  que e' justamente o que MFE/MAE nao capturam

| resultado | acao |
|---|---|
| reproduz aproximadamente | instrumento validado, segue |
| **diverge materialmente** | **PARAR e diagnosticar.** Tudo construido sobre ele estaria errado |

Divergencia pequena e' esperada e aceitavel: ticket, slippage, ordem de
execucao, e o fato de o operacional pagar spread de execucao real enquanto a
simulacao paga o spread do tick. **Divergencia de sinal ou de ordem de
grandeza nao e'.**

Criterio numerico declarado antes: n dentro de +-10%, P&L dentro de +-20%, e a
proporcao BE/STOP/SINAL na mesma ordem (BE dominante, STOP minoritario).

### 4.1 CORRECAO do comparador (feita antes de rodar)

Escrevi acima "76 trades / $777,23". **Errado:** a coluna simulada nao tem R2, e
18 dos 76 sao reentradas. O comparavel e' o subconjunto `seq=0` do CSV do
operacional: **58 trades, 765.817 pts, saidas BE 32 / SINAL 21 / STOP 4 /
FIMTESTE 1**. Bate com o "C_HIST sem R2 = $751,58 / 58" da tabela 5.1.

### 4.2 RESULTADO — reprovou por proxy, passou no teste direto

**Proxy (re-derivar os filtros): REPROVOU.** Aplicando regime + histograma +
spread<=260 aos 568 sinais dao **84**, contra 58: **+44,8%**, fora do +-10%.

Diagnostico, por veto e em sequencia:

| veto | medicao | operacional |
|---|---|---|
| regime | 254 | **254** |
| histograma | 111 | **111** |
| spread | 119 | **152** |

Regime e histograma replicam **exatamente**. A divergencia esta' toda no
spread, e a causa e' de INSTANTE, nao de regra: o operacional testa o spread
**dentro de `Abre()`** (linha 640), que roda **depois** de `Fecha("SINAL")` ter
enviado ordem de mercado — e no tester executar ordem **avanca o tick**. Ele
filtra sobre um instante posterior ao que a medicao grava em `spread_sig_pts`.

**Teste direto (a leitura literal do que foi pre-registrado — "os MESMOS sinais
que o operacional efetivamente tomou"): PASSOU.** Casando os 58 trades reais
com os sinais por horario (tolerancia de 1 barra), 57 casaram:

| | n | P&L (pts) | saidas |
|---|---|---|---|
| operacional (real) | 57 | 757.653 | BE 32 · SINAL 21 · STOP 4 |
| simulado (`tit_*`) | 57 | 742.294 | BE 33 · SINAL 20 · STOP 4 |

- **motivo de saida IDENTICO em 56 de 57 (98%)** — e' a assinatura da ORDEM dos
  eventos, o teste mais informativo do gate
- P&L **-2,0%**, dentro do +-20%
- erro por trade: mediana **-225 pts**, ~1 spread, na direcao **PESSIMISTA**
- 1 discordancia: real saiu por SINAL, simulado por BE
- **0 empates intrabarra** em 568 sinais — resolucao de tick torna o caso raro
- confirmacao independente que eu nao tinha procurado: **366 de 568 saem por BE
  = 64,4%**, contra os **~63% de scratch** que o projeto mede desde sempre

**Veredito: instrumento validado.** A reprovacao do proxy e' propriedade do
INSTANTE do filtro, nao do desfecho simulado.

---

## 5. Recalcular o poder imediatamente

Assim que a coluna passar a secao 4, refazer a Etapa 0 da 5c com a dispersao do
**novo** desfecho:

- IQR do desfecho truncado (comparar com os ~2,8 ATR do `MFE15/ATR`)
- MDE por bloco
- poder em 0,2 / 0,3 / 0,5 ATR, ou no equivalente em pontos

**Manter o controle calibrado:** `delta=0` tem de cair para ~alfa. Embaralhar
os rotulos ANTES de injetar o efeito — a primeira versao injetava no dado real
e media efeito existente + delta.

### 5.1 RESULTADO — destravou

**Dispersao, que era o gargalo:**

| desfecho | p25 | mediana | p75 | **IQR** |
|---|---|---|---|---|
| `(MFE15−MAE15)/ATR` (antigo) | −2,13 | +0,02 | +2,24 | **4,37 ATR** |
| `tit_pnl/ATR` (truncado) | −0,10 | −0,06 | −0,04 | **0,06 ATR** |

**Reducao de 69x.** O truncamento faz o que devia: 366 dos 568 saem por BE, que
e' scratch, e a distribuicao colapsa perto de zero.

**A escala do efeito de referencia muda junto, e isso e' obrigatorio dizer:**
com IQR de 0,06 ATR, procurar "0,2-0,3 ATR" seria procurar efeito 5x maior que a
dispersao inteira. O efeito plausivel agora e' da ordem do **custo**
(260 pts = **0,048 ATR**).

**Poder do omnibus** (nulo sintetico, rotulos embaralhados antes de injetar):

| efeito | pts | poder |
|---|---|---|
| 0,000 ATR | 0 | **4%** — controle, calibrado em alfa=5% |
| 0,010 ATR | 54 | 24% |
| 0,025 ATR | 135 | **98%** |
| 0,048 ATR (~1 custo) | 259 | **100%** |
| 0,100 ATR | 540 | 100% |

Contra **4% em 0,3 ATR** no desfecho antigo. **Ambas as frentes desbloqueiam.**

| resultado | acao |
|---|---|
| poder adequado | 5c e frente do spread **desbloqueiam** <- **foi este** |
| poder ainda baixo | ambas seguem bloqueadas, com razao MEDIDA |

---

## 6. Nao fazer

- **Nao tocar no `S-EA-Pullback_Live`.** R7: coluna no EA de medicao, ponto.
- Nao trocar particao, horizonte ou ancora da 5c enquanto isto nao fechar.
- Nao usar a coluna para decisao nenhuma antes da secao 4 passar.
