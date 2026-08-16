# SBurn

Pesquisa empirica de sistemas de trading para XAUUSDm (ouro) no MetaTrader 5.
Leia `CLAUDE.md` antes de qualquer coisa: regras, estado empirico e armadilhas.

## Instalacao

O repositorio espelha o caminho da pasta de dados do MT5, entao cada arquivo mora
no mesmo lugar dentro e fora do repo. Ligar por junction (nao copiar):

    mklink /J "<PastaDeDados>\MQL5\Indicators\SBurn" "C:\dev\SBurn\MQL5\Indicators\SBurn"
    mklink /J "<PastaDeDados>\MQL5\Experts\SBurn"    "C:\dev\SBurn\MQL5\Experts\SBurn"
    mklink /J "<PastaDeDados>\MQL5\Include\SBurn"    "C:\dev\SBurn\MQL5\Include\SBurn"

`mklink /J` nao exige administrador. Copiar em vez de ligar cria duas versoes do
mesmo arquivo - e' a armadilha que o desenho do repo existe para evitar.

Compilar (F7) nesta ordem: indicadores primeiro, EAs por ultimo.

## Arquivos

| Arquivo | v | Papel |
|---|---|---|
| `MQL5/Indicators/SBurn/S-Ind-ScalpPullback.mq5` | 2.02 | Gatilho (buf 26) e regime (buf 27). Coracao da estrategia. |
| `MQL5/Indicators/SBurn/S-Ind-TMO_Scalper.mq5` | 4.02 | Sensores de contexto: zona (14), confluencia (15), ATR (16), histograma (0-2). |
| `MQL5/Experts/SBurn/S-EA-Pullback_Live.mq5` | 1.07 | EA operacional. Defaults = melhor config medida. |
| `MQL5/Experts/SBurn/S-EA-Test_ConsistencyGate.mq5` | 1.20 | EA de MEDICAO (nao opera). 99 colunas por sinal. |
| `MQL5/Include/SBurn/S-Include-ConsistencyGate.mqh` | 1.02 | Gate tick-based (relogio de mercado). |
| `MQL5/Include/SBurn/S-Include-MovConsistency.mqh` | — | Sensor do MKS-Engine (copia fiel). |
| `analise/S-Py-Analise_ConsistGate.py` | — | Analisa um CSV de medicao. |
| `analise/S-Py-Compara_TFs.py` | — | Compara CSVs entre timeframes. |

## Reproduzir o resultado de referencia

`S-EA-Pullback_Live` com os defaults, XAUUSDm M5, 2026.01.01-08.12, "Every tick based
on real ticks", 0.01 lote. Esperado: **137 trades, +$1.308,59, DD $49,25, PF 5,83**.

Trocar `InpCandidato` (A_TITULAR / B_CONFLU / C_HIST / D_COMBO) para comparar
variantes. E' o unico input a mudar entre rodadas.

## Medir uma ideia nova

Use `S-EA-Test_ConsistencyGate` — ele grava, nao opera. Fontes de sinal:
`SIG_TMO1`, `SIG_TMO2`, `SIG_SP`, `SIG_MACROSS`, `SIG_PBSHALLOW`.
So' o que passar no tribunal (positivo em OOS e IS, com estabilidade mensal) vira
codigo operacional. Ver R7 no CLAUDE.md.
