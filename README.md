# SBurn

Pesquisa empirica de sistemas de trading para XAUUSDm (ouro) no MetaTrader 5.
Leia `CLAUDE.md` antes de qualquer coisa: regras, estado empirico e armadilhas.

## Instalacao

O repositorio espelha o caminho da pasta de dados do MT5, entao cada arquivo mora
no mesmo lugar dentro e fora do repo. A ligacao e' por junction (nunca copia):

    git clone https://github.com/MksMike/SBurn.git C:\dev\SBurn
    cd C:\dev\SBurn
    powershell -ExecutionPolicy Bypass -File setup\S-Ps-Setup_Maquina.ps1
    python -m pip install pandas scipy

O script acha a pasta de dados do terminal EXNESS, cria o alias `C:\MT5\Exness`
e os 3 junctions (`Indicators\SBurn`, `Experts\SBurn`, `Include\SBurn`), e
verifica. Idempotente; `mklink /J` nao exige administrador. Copiar em vez de ligar
cria duas versoes do mesmo arquivo - e' a armadilha que o desenho do repo existe
para evitar.

Compilar: `Ctrl+Shift+B` no VS Code, ou F7 no MetaEditor nesta ordem — indicadores
primeiro, EAs por ultimo.

Cada PC do projeto esta' descrito em `docs/S-Doc-Maquinas.md`, inclusive o que
falta nele para reproduzir o resultado de referencia.

## Principio de desenho: PORTABILIDADE (R8)

**O sistema tem de operar em qualquer corretora e em qualquer tipo de conta**
(Standard, Raw, Zero, Pro). Nenhum default pode ser um valor absoluto valido so'
numa conta: todo parametro e' adimensional (multiplo de ATR, barras, percentil) ou
**derivado por medicao do historico da conta em uso**.

Hoje o EA **nao** cumpre isso em dois pontos medidos:

- `InpMaxSpread = 260` e' absoluto. Numa conta Raw (spread mediano 90) ele deixa
  passar 100% dos sinais e o filtro desaparece **em silencio** — PF cai de 7,41
  para 1,80 e o drawdown de saldo vai de $23,37 para $196,06.
- O **degrau ZERO do breakeven** ignora o custo: sair no BE perde um spread mais
  comissao, e ~63% dos trades saem pelo BE.

A resposta e' **auto-configuracao por conta** — um script que identifica corretora,
servidor, conta e tipo, varre o historico daquela conta, mede **spread e comissao**
e calibra o que depende de conta, inclusive o degrau do BE para que sair no
breakeven nao seja prejuizo. Especificacao completa, com o conflito medido que ela
precisa resolver: **`docs/S-Doc-Portabilidade.md`**. **Nada disso esta implementado.**

## Arquivos

| Arquivo | v | Papel |
|---|---|---|
| `MQL5/Indicators/SBurn/S-Ind-ScalpPullback.mq5` | 2.02 | Gatilho (buf 26) e regime (buf 27). Coracao da estrategia. |
| `MQL5/Indicators/SBurn/S-Ind-TMO_Scalper.mq5` | 4.02 | Sensores de contexto: zona (14), confluencia (15), ATR (16), histograma (0-2). |
| `MQL5/Experts/SBurn/S-EA-Pullback_Live.mq5` | 2.04 | EA operacional. Principal (com reentrada R2) + piramide, magics separados. Desde a v2.04 a piramide vem **LIGADA** por padrao. |
| `MQL5/Experts/SBurn/S-EA-Test_ConsistencyGate.mq5` | 1.28 | EA de MEDICAO (nao opera). 99 colunas por sinal. |
| `MQL5/Include/SBurn/S-Include-ConsistencyGate.mqh` | 1.02 | Gate tick-based (relogio de mercado). |
| `MQL5/Include/SBurn/S-Include-MovConsistency.mqh` | — | Sensor do MKS-Engine (copia fiel). |
| `analise/S-Py-Analise_ConsistGate.py` | — | Analisa um CSV de medicao. |
| `analise/S-Py-Compara_TFs.py` | — | Compara CSVs entre timeframes. |
| `analise/S-Py-Perfil_Spread.py` | 1.02 | Perfila um export de ticks: spread e **autenticidade do feed** (trocas/1M). |
| `setup/S-Ps-Setup_Maquina.ps1` | 1.00 | Parametriza um PC: alias, junctions, verificacao. |
| `docs/S-Doc-Maquinas.md` | 1.0 | Registro das maquinas e do estado de cada uma. |
| `docs/S-Doc-Spread_Contas.md` | 1.1 | Standard x Raw: medicao, decisao e a armadilha do spread carimbado. |
| `docs/S-Doc-Checkpoint_2026-08-18.md` | 1.0 | Checkpoint do dia: o que foi feito, o que ficou invalido e a fila. |
| `docs/AUDITORIA_SINCRONIA.md` | — | Auditoria repo x PC x GitHub de 2026-08-18 (secoes 4.2 e 4.3 ja resolvidas). |
| `docs/S-Doc-Portabilidade.md` | 1.0 | **R8**: rodar em qualquer corretora/conta + spec da auto-configuracao (spread, comissao, degrau do BE). |
| `docs/S-Doc-PreReg_PBSHALLOW.md` | — | Pre-registro do gatilho de pullback raso. Rodado e **reprovado**. |
| `docs/S-Doc-PreReg_Spread.md` | — | Pre-registro da grade de `InpMaxSpread` na janela valida. |
| `docs/CHECKPOINT.md` | — | Checkpoint corrente. |
| `analise/S-Py-Compara_PBShallow.py` | — | Compara rodadas do EA de medicao lado a lado. |
| `setup/S-Ps-Perfil_Conta.ps1` | — | **NAO EXISTE** — auto-configuracao por conta (ver S-Doc-Portabilidade). |
| `analise/S-Py-Perfil_Conta.py` | — | **NAO EXISTE** — consolida spread + comissao em custo, calibra o BE. |
| `MQL5/Include/SBurn/S-Include-ContaConfig.mqh` | — | **NAO EXISTE** — o EA le a config da conta; sem ela, recusa operar. |

## Reproduzir o resultado de referencia

`S-EA-Pullback_Live`, XAUUSDm M5 @ `Exness-MT5Trial5`, **2026.02.01-08.18**, "Every
tick based on real ticks", 0.01 lote, candidato `C_HIST`.

> **A janela comeca em fevereiro de proposito.** 2026-01 esta reprovado: o spread do
> tick e' constante em 160,0 pts nos 25 dias do mes (armadilha 13). Como 63% dos
> trades saem pelo breakeven e o BE nao derrapa com spread constante, janeiro nao e'
> impreciso — e' invalido para este desenho.

| Configuracao | Lucro | DD saldo | PF | Negociacoes | Recuperacao |
|---|---|---|---|---|---|
| **`InpPirEnabled=false` (so' a principal)** | **+$777,23** | **$23,37** | **7,41** | 76 | **4,15** |
| defaults da v2.04 (piramide ON) | +$962,49 | $53,17 | 4,25 | 141 | 2,26 |

Na janela valida a piramide rende **0,77x** sobre o drawdown que adiciona — ela
adiciona mais risco do que lucro. O default `InpPirEnabled=true` da v2.04 foi
decidido sobre a janela contaminada; **a recomendacao e' reverter para `false`**.

Numeros anteriores (137 trades / +$1.308,59 / 26,6x, e o par 2.617,25 / 1.387,20)
sao da janela que inclui 2026-01 e estao **aposentados**. Ver `docs/CHECKPOINT.md`.

Trocar `InpCandidato` (A_TITULAR / B_CONFLU / C_HIST / D_COMBO) para comparar
variantes. E' o unico input a mudar entre rodadas.

## Medir uma ideia nova

Use `S-EA-Test_ConsistencyGate` — ele grava, nao opera. Fontes de sinal:
`SIG_TMO1`, `SIG_TMO2`, `SIG_SP`, `SIG_MACROSS`, `SIG_PBSHALLOW`.
So' o que passar no tribunal (positivo em OOS e IS, com estabilidade mensal) vira
codigo operacional. Ver R7 no CLAUDE.md.
