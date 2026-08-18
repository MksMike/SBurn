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
| `analise/S-Py-Perfil_Spread.py` | 1.02 | Perfila um export de ticks: spread e **autenticidade do feed** (trocas/1M). |
| `setup/S-Ps-Setup_Maquina.ps1` | 1.00 | Parametriza um PC: alias, junctions, verificacao. |
| `docs/S-Doc-Maquinas.md` | 1.0 | Registro das maquinas e do estado de cada uma. |
| `docs/S-Doc-Spread_Contas.md` | 1.1 | Standard x Raw: medicao, decisao e a armadilha do spread carimbado. |

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
