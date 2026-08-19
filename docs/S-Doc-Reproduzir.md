# SBurn — Reproduzir a referencia
**Versao:** 1.0 | **Atualizado:** 2026-08-19

Config exata da rodada de referencia e como dispara-la pela linha de comando, sem
tocar na GUI. Existe porque o checkpoint de 2026-08-19 registra que **nenhum
numero da piramide e' auditavel a partir do repositorio**: os `.ini` do tester
ficavam so' na pasta de dados do MT5, e os relatorios `.htm`, fora do git.

---

## 1. Resultado verificado

Reproduzido no **PC-Casa** em 2026-08-19 20:25, conta 277812882 @
`Exness-MT5Trial5` (demo, hedging), a partir dos defaults COMPILADOS da v2.05.

| Metrica | Esperado | Medido | |
|---|---|---|---|
| Lucro liquido | $777,23 | 777.23 | ok |
| Rebaixamento maximo do saldo | $23,37 | 23.37 (0,22%) | ok |
| Rebaixamento maximo do capital | $187,34 | 187.34 (1,83%) | ok |
| Fator de lucro | 7,41 | 7.41 | ok |
| Total de negociacoes | 76 | 76 | ok |
| Fator de recuperacao | 4,15 | 4.15 | ok |
| Maior negociacao | $267,14 | 267.14 | ok |

Qualidade do historico: **100% de ticks reais**, 49.906.490 ticks, 38.502 barras.
Saidas: BE=41 STOP=6 SINAL=28. R2: 18 reentradas, 2 expiradas. Piramide: 0 adicoes.

**A base de ticks e' por SERVIDOR, nao por conta.** A referencia do escritorio foi
medida em outra conta do mesmo `Exness-MT5Trial5` e deu os mesmos sete numeros —
o que confirma que trocar de conta dentro do servidor nao move a medicao.

---

## 2. Como rodar

O MT5 e' instancia unica por pasta de dados: **o terminal precisa estar fechado**,
senao `terminal64.exe /config:` so' devolve foco para a janela aberta e sai sem
rodar nada — e sem erro.

    taskkill /PID <pid do terminal64>
    "C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe" /config:<caminho>\ref_v205.ini

Compilar antes, indicadores primeiro:

    set ME="C:\Program Files\MetaTrader 5 EXNESS\metaeditor64.exe"
    %ME% /compile:<repo>\MQL5\Indicators\SBurn\S-Ind-TMO_Scalper.mq5 /inc:<dados>\MQL5 /log:<log>

**O `metaeditor64.exe` retorna exit=1 mesmo compilando limpo.** Ignorar o exit
code; ler a linha `Result: N errors, N warnings` do log, que sai em **UTF-16LE**.

Onde olhar depois: `Tester\logs\<data>.log` (log do tester),
`Tester\<hash>\Agent-127.0.0.1-3001\logs\` (log do EA, com os Prints) e o `.htm`
na **raiz da pasta de dados** — ver armadilha 17 antes de procurar em outro lugar.

---

## 3. O `.ini` (defaults compilados, transcritos do fonte)

Os 32 inputs abaixo sao os defaults da v2.05, lidos das linhas 276-321 de
`S-EA-Pullback_Live.mq5`. **Nao usar `.set` salvo** — foi assim que 2026-08-18
rodou com `InpPirMaxPos=1` achando que era 2, e sem `InpPirInicioATR` (armadilha 5).
Gravar em **UTF-16LE com BOM**, quebra de linha CRLF.

    [Tester]
    Expert=SBurn\S-EA-Pullback_Live.ex5
    Symbol=XAUUSDm
    Period=M5
    Optimization=0
    Model=4
    FromDate=2026.02.01
    ToDate=2026.08.18
    ForwardMode=0
    Deposit=10000
    Currency=USD
    ProfitInPips=0
    Leverage=100
    ExecutionMode=0
    OptimizationCriterion=0
    Visual=0
    ShutdownTerminal=1
    Report=rel_v205_trial5_ref
    ReplaceReport=1
    [TesterInputs]
    InpCandidato=2
    InpSPName=SBurn\S-Ind-ScalpPullback
    InpSPTF=30
    InpTMOName=SBurn\S-Ind-TMO_Scalper
    InpTMOTF2=15
    InpTMOTF3=30
    InpHistMax=2.20
    InpATRPeriod=14
    InpArmATR=0.73
    InpStopATR=3.67
    InpR2Enabled=true
    InpR2Piso=5
    InpR2Calma=3
    InpR2Validade=120
    InpR2MaxPorSeq=1
    InpPirEnabled=false
    InpPirLots=0.01
    InpPirMagic=20260901
    InpPirInicioATR=2.00
    InpPirPassoATR=1.00
    InpPirMaxPos=2
    InpPirArmATR=0.73
    InpPirStopATR=3.67
    InpLots=0.01
    InpMagic=20260814
    InpSlippage=30
    InpMaxSpread=260
    InpLogCSV=true
    InpDraw=true
    InpMaxObj=400
    InpMaxTentBE=5
    InpRoot=SBurn

`Model=4` e' "every tick based on real ticks" — o unico modelo valido para este
desenho (secao 3 da `CLAUDE.md`). `Report=` sem caminho e sem extensao.

---

## 4. Ressalvas que acompanham este numero

1. **76 operacoes nao validam nada.** Dois meses com ZERO trade, tres dias fazendo
   61% do lucro, um trade sozinho rendendo 34,7%. Reproduzir e' condicao
   necessaria para a maquina ser base valida, nao evidencia a favor da estrategia.
2. **Servidor de DEMO.** `Exness-MT5Trial5`. A doc do projeto ja' afirmou conta
   real quando era demo (armadilha 14) — nao repetir.
3. **A rodada emite `ATENCAO: houve falhas`.** Uma entrada perdida por
   `10018 market closed` (2026.02.02 21:05) e duas posicoes que nunca armaram o
   breakeven (2026.02.11 21:19). As de BE **nao aparecem em contador nenhum** —
   ver armadilha 18.
4. **O CSV de operacoes nao reconcilia com o relatorio**: nao grava o fechamento
   forcado de fim de teste. Item aberto da fila.
