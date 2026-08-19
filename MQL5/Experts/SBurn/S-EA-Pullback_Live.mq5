//+------------------------------------------------------------------+
//| >>> INSTALACAO (LEIA PRIMEIRO) <<<                                |
//| PASTA:    <PastaDeDados>\MQL5\Experts\SBurn\                      |
//| ARQUIVO:  S-EA-Pullback_Live.mq5                                  |
//| COMPILAR: SIM (F7). Requer em Indicators\SBurn\:                  |
//|             S-Ind-ScalpPullback.ex5  (sempre)                     |
//|             S-Ind-TMO_Scalper.ex5    (se usar candidato B/C/D)    |
//| ASSINATURA no log ao iniciar (prova de identidade):               |
//|   "S-EA-Pullback_Live v2.05 | cand=... TF=... SPTF=..."           |
//+------------------------------------------------------------------+
//| S-EA-Pullback_Live.mq5 — EA OPERACIONAL DO PROJETO SBURN          |
//|                                                                    |
//| Nenhum parametro foi inventado. Cada um veio de medicao:           |
//|  ENTRADA: sinal do ScalpPullback (buffer 26, barra fechada) com o  |
//|           regime do SP no TF maior (buffer 27) concordando.        |
//|  SAIDA 1: stop inicial InpStopATR x ATR(14) da entrada (3.67).     |
//|  SAIDA 2: ao lucro atingir InpArmATR x ATR (0.73), o stop vai      |
//|           para o NIVEL BID DA ENTRADA (degrau ZERO — medido:       |
//|           degrau zero +4.237/trade, degrau +0.05xATR +2.541).      |
//|  SAIDA 3: proximo sinal do SP (qualquer direcao) fecha a posicao.  |
//|                                                                    |
//| DEFAULTS: a ESTRATEGIA PRINCIPAL abaixo, e desde a v2.04 tambem    |
//| a PIRAMIDE LIGADA. A tabela seguinte e a da PRINCIPAL SOZINHA —    |
//| ela NAO descreve mais o default. O numero do default esta na       |
//| entrada v2.04 do CHANGELOG. Para reproduzir a tabela, rodar com    |
//| InpPirEnabled=false.                                               |
//|                                                                    |
//| Principal sozinha (backtest real, ticks reais, XAUUSDm M5,         |
//| 2026.01.01-08.12, 0.01 lote):                                      |
//|                                                                    |
//|   config                     n   media$   total$    DD$   ret/DD   |
//|   A sem filtros            370    +3.15  +1163.82  206.33   5.6x   |
//|   C_HIST                   247    +4.75  +1173.88  157.57   7.5x   |
//|   >>> C_HIST + spread<=260 137    +9.55  +1308.59   49.25  26.6x   |
//|                                                                    |
//| Por que estes dois filtros e nao os outros — teste do DESCARTADO   |
//| (o valor de um filtro e' o desempenho do que ele remove):          |
//|   histograma  : os 123 trades removidos rendiam -0,08/trade (zero) |
//|                 -> corta a parte inutil da amostra. t=+2,06.       |
//|   spread >260 : os removidos rendiam -0,54/trade, e 99% da         |
//|                 diferenca NAO e' custo e sim condicao de mercado.  |
//|   confluencia : os removidos rendiam +2,86/trade (lucro jogado     |
//|                 fora). t=+0,62 -> SEM evidencia. Nao usar.         |
//|                                                                    |
//| LIMITES DO QUE FOI VALIDADO — ler antes de operar dinheiro real:   |
//|  - 8 meses e 137 trades nesta configuracao. Nao e' validacao longa.|
//|  - so' existe tick real da Exness a partir de 2026.01. O teste de  |
//|    2025 rodou com ticks SIMULADOS e nao vale para este desenho,    |
//|    que e' path-dependent (63% dos trades saem pelo breakeven).     |
//|  - a confirmacao em anos exige base Dukascopy com o modelo de      |
//|    spread da Exness por cima e coluna de proveniencia.             |
//|  - o corte de spread em 260 e' o valor ABSOLUTO da conta Standard  |
//|    (mediana da distribuicao). Em conta Raw/Zero ele nunca          |
//|    dispararia: recalibrar para a mediana daquela conta.            |
//|                                                                    |
//| CHANGELOG                                                          |
//|  v2.05 - PIRAMIDE DE VOLTA A DESLIGADA POR PADRAO.                 |
//|   InpPirEnabled: true -> false. Reverte o default da v2.04. Unico  |
//|   default alterado; nenhuma linha de logica tocada.                |
//|   MOTIVO: o numero que justificou ligar (marginal 5,14x) veio de   |
//|   uma janela que comeca em 2026.01, mes reprovado. Re-medido em    |
//|   2026.02.01-08.18:                                                |
//|                                                                    |
//|     config          lucro    DD capital   negoc.                   |
//|     principal so  $777,23      $187,34      76                     |
//|     + piramide    $962,49      $426,52     141                     |
//|                                                                    |
//|   +$185,26 de lucro por +$239,18 de DD = 0,77x: a piramide adiciona|
//|   MAIS drawdown do que lucro. Por adicao sao $2,85 contra $10,23 do|
//|   trade da principal, com o MESMO stop de 3,67xATR e o MESMO lote. |
//|                                                                    |
//|   E ha causa medida, nao so correlacao. Em 2026.01 o caminho do BID|
//|   e anomalamente LISO: 42,5 pts por tick contra 96-106 nos outros  |
//|   sete meses, 1,86x mais ticks/s, e consistencia                   |
//|   (|deslocamento|/caminho em 75 ticks) 0,149 contra 0,074-0,113    |
//|   (p=1,7e-85).                                                     |
//|                                                                    |
//|   Cada adicao morre quando o preco encosta de volta no nivel de    |
//|   entrada dela. Caminho liso = nao encosta = a adicao vira         |
//|   corredor. Medido na simulacao BID-pura do EA de medicao (colunas |
//|   pir_b*, sem spread): adicao a 2,0xATR sobrevive 26,9% em janeiro |
//|   contra 21,5% no resto (p=0,010); a 3,0xATR, 31,6% contra 19,8%   |
//|   (p=6,8e-05). Sobrevive ao controle por tamanho da perna e a      |
//|   retirada da semana parabolica de 26-30/01.                       |
//|                                                                    |
//|   Ou seja: 84,9% do lucro marginal da piramide veio de um mes cujo |
//|   defeito de dado premia exatamente o mecanismo que ela monetiza.  |
//|   Janeiro nao e amostra a favor dela: e ANTI-evidencia.            |
//|                                                                    |
//|   LIMITE DESTE NUMERO (R3): o CSV do EA filtra por InpMagic e NAO  |
//|   grava as pernas da piramide, entao 5,14x -> 0,77x vem do         |
//|   relatorio do MT5, sem trades de piramide auditaveis no           |
//|   repositorio. Efeito colateral util: como ops_pirON.csv e         |
//|   ops_pirOFF.csv sao byte-identicos, esta provado que ligar a      |
//|   piramide nao altera UM UNICO trade da principal.                 |
//|  v2.04 - A PIRAMIDE PASSA A VIR LIGADA POR PADRAO.                 |
//|   InpPirEnabled: false -> true. E o UNICO default alterado; nenhum |
//|   outro input mudou e nenhuma linha de logica foi tocada.          |
//|   DECISAO DO MIKE em 2026-08-19, com o trade-off na mesa. O que a  |
//|   medicao diz (XAUUSDm M5, 2026.01.01-08.18, ticks reais 100%,     |
//|   0.01 lote, C_HIST, mesma janela para as duas):                   |
//|                                                                    |
//|     config          lucro    DD capital   PF    negociacoes        |
//|     principal so  $1387.20     $187.34   4.64      148             |
//|     + piramide    $2617.25     $426.52   4.63      254             |
//|                                                                    |
//|   Ou seja: +$1230.05 de lucro por +$239.18 de drawdown de capital. |
//|   Na margem a piramide rende ~5,1x sobre o DD que ela adiciona,    |
//|   contra 7,4x da principal — e o fator de recuperacao do conjunto  |
//|   cai de 7,40 para 6,14. E TROCA CONSCIENTE: mais participacao na  |
//|   tendencia por menos eficiencia. Nao e melhora em toda dimensao.  |
//|   (Os DDs nao somam linearmente — os picos podem nao ser           |
//|   simultaneos, entao os 5,1x na margem sao aproximacao.)           |
//|                                                                    |
//|   SIZING — agora vale por padrao, nao mais so se alguem ligar:     |
//|   podem existir ate InpPirMaxPos posicoes simultaneas ALEM da      |
//|   principal, cada uma com stop proprio de InpPirStopATR x ATR.     |
//|   O risco agregado NAO e o de uma posicao. Dimensionar sobre o     |
//|   total, e lembrar que o stop escala com o ATR (p90 = 2x a         |
//|   mediana).                                                        |
//|                                                                    |
//|   STATUS: hipotese medida, NAO validada. 8 meses de janela, e a    |
//|   janela inclui 2026.01, que ainda nao passou pelo teste de        |
//|   trocas/1M no XAUUSDm (armadilha 13). Comparacao entre as duas    |
//|   configuracoes e valida (o vies e comum as duas); o nivel         |
//|   absoluto de ambas, nao.                                          |
//|  v2.03 - CORRECAO da identificacao do ticket da adicao da piramide |
//|   introduzida na v2.02 (a piramide segue DESLIGADA por padrao).    |
//|   [B16] a busca pelo DEAL desta ordem (ResultDeal -> HistorySelect |
//|    -> DEAL_POSITION_ID) FALHAVA no tester: logo apos o envio da    |
//|    ordem o deal ainda nao esta disponivel para HistorySelect,      |
//|    entao posId ficava 0 e o ticket nao era achado. Medido no       |
//|    backtest da v2.02: adicoes=106 contra falhas=234 — a maior      |
//|    parte das adicoes rodou SEM breakeven, so' com o stop inicial.  |
//|    A varredura antiga, fragil em teoria, achava o ticket na        |
//|    pratica. Agora o ticket vem de ResultOrder(): em conta HEDGING  |
//|    o ticket da POSICAO e' igual ao ticket da ORDEM de abertura, e  |
//|    ele existe na hora, sem depender do historico estar             |
//|    sincronizado. Dois fallbacks: (2) ResultDeal +                  |
//|    DEAL_POSITION_ID, o metodo da v2.02; (3) varredura por          |
//|    POSITION_MAGIC pegando a posicao MAIS RECENTE (maior            |
//|    POSITION_TIME) e ignorando ticket ja' atribuido a outra adicao  |
//|    — pegar "a primeira encontrada" era o defeito do [B14].         |
//|   [B17] g_pirFalhas somava dois casos de implicacao OPOSTA: ordem  |
//|    REJEITADA (a adicao nao existe) e adicao ABERTA mas nao         |
//|    identificada (existe e fica sem BE). Agora sao dois contadores  |
//|    no log: rejeitadas= e sem_ticket=. Alem disso a rejeicao era    |
//|    contada e impressa A CADA TICK enquanto o alvo do passo         |
//|    continuasse valido (g_pirAbertas nao avanca quando a ordem      |
//|    falha) — por isso 234 podia passar de 106. Agora conta uma      |
//|    unica vez por adicao, via g_pirRejCont[].                       |
//|   NAO muda nenhum default nem toca na estrategia principal.        |
//|  v2.02 - AUDITORIA da piramide (que segue DESLIGADA por padrao).   |
//|   [B14] o ticket da adicao era achado por varredura, e a varredura |
//|    aceitava qualquer posicao do magic da piramide aberta depois da |
//|    principal — o que TODAS as adicoes satisfazem. Como a lista de  |
//|    posicoes do MT5 nao e' garantidamente cronologica, o BE de uma  |
//|    adicao podia mover o stop de OUTRA, e a adicao certa ficava sem |
//|    BE. Agora o ticket vem do DEAL da propria ordem, por            |
//|    DEAL_POSITION_ID, que e' unico.                                 |
//|   [B15] a falha de identificacao era SILENCIOSA: a adicao seguia   |
//|    so' com o stop inicial e nao aparecia em lugar nenhum. Agora    |
//|    conta em g_pirFalhas e vai para o log.                          |
//|   DOCUMENTADO SEM MUDAR COMPORTAMENTO — sao decisao a MEDIR, nao   |
//|    bug: (a) a piramide SOBREVIVE ao BE e ao STOP da principal, so' |
//|    sai em sinal novo do SP; (b) o sentinela g_r2Topo==0 impede a R2|
//|    de disparar quando o recuo nao teve excursao favoravel nenhuma. |
//|  v2.01 - InpPirInicioATR: separa ONDE a piramide COMECA de QUAL o  |
//|   espacamento. Antes a 1a adicao entrava em 1x o passo; agora o    |
//|   inicio e' proprio.                                               |
//|   Medido: a adicao em 1.0xATR abre em 75% dos sinais e rende quase |
//|   nada — e' ela que arruina a eficiencia (ret/DD 5,4x). Comecar em |
//|   2.0xATR reduz a abertura para 49%: a metade eliminada sao os     |
//|   movimentos que morrem cedo, exatamente os que nao valia          |
//|   acompanhar. Elimina as adicoes ruins sem perder as boas.         |
//|     inicio 1.0 (2 adicoes): $2.279  DD $360  ret/DD  6,3x          |
//|     inicio 2.0 (2 adicoes): $2.333  DD $226  ret/DD 10,3x  <-      |
//|     inicio 3.0 (2 adicoes): $1.864  DD $230  ret/DD  8,1x          |
//|   Otimo NO MEIO da grade, com queda dos dois lados: assinatura de  |
//|   estrutura, nao de pico de sobreajuste. Ainda assim e' HIPOTESE — |
//|   a medicao vem sendo otimista vs o backtest real (com inicio 1.0  |
//|   ela projetou DD de $360 e a execucao deu $509).                  |
//|  v2.00 - DUAS ESTRATEGIAS NO MESMO EA, independentes:              |
//|                                                                    |
//|   [PRINCIPAL] pullback do SP + regime + BE no zero + stop 3.67xATR |
//|     + REENTRADA R2 (nova, medida). Magic = InpMagic.               |
//|     R2 = "range congelado no esgotamento": apos o scratch, o EA    |
//|     acompanha o recuo; quando o preco para de fazer extremo        |
//|     adverso novo por InpR2Calma barras, CONGELA o topo do range    |
//|     formado desde o scratch; a reentrada dispara quando o preco    |
//|     rompe esse topo. E' confirmacao de ESTADO (o recuo se          |
//|     esgotou), nao relogio — coerente com a lei do projeto.         |
//|     Medido: +19% de lucro e retorno/DD de 8,8x para 9,1x.          |
//|     Substitui a reentrada por rompimento do extremo da v1.06,      |
//|     que media pior (stop de 20% contra 8%).                        |
//|                                                                    |
//|   [SECUNDARIA] PIRAMIDE simultanea. Magic PROPRIO (InpPirMagic),   |
//|     lote proprio, passo e numero de posicoes proprios. Adiciona    |
//|     posicao a cada InpPirPassoATR de lucro do movimento, cada uma  |
//|     com BE e stop PROPRIOS. Ligavel por InpPirEnabled.             |
//|     Medido (passo 1.0xATR, 3 posicoes, junto com o principal):     |
//|     +64% de lucro total, mas retorno/DD cai de 9,1x para 6,3x.     |
//|     E' troca consciente: mais participacao na tendencia por mais   |
//|     drawdown. Por isso vive separada, com risco proprio.           |
//|                                                                    |
//|   ATENCAO AO SIZING: com a piramide ligada podem existir ate       |
//|   InpPirMaxPos posicoes simultaneas alem da principal. O risco     |
//|   agregado NAO e' o de uma posicao — dimensionar sobre o total.    |
//|  v1.07 - auditoria pre-backup: o contador de reentradas era        |
//|   incrementado ANTES de a ordem ser confirmada; se a abertura      |
//|   falhasse, a cota da piramide era consumida sem trade. Agora so'  |
//|   incrementa apos a posicao existir.                               |
//|  v1.06 - primeira tentativa de reentrada (por rompimento do        |
//|   extremo anterior). MEDIDA E REPROVADA: stop subia de 8% para 20%,|
//|   retorno/DD caia de 26,6x para 21,4x. Substituida pelo R2 na v2.  |
//|  v1.04 - CORRECAO DE BUG INTRODUZIDO NA v1.03: o aquecimento       |
//|   usava BarsCalculated() ANTES de qualquer CopyBuffer. Em MQL5,    |
//|   BarsCalculated NAO forca o calculo de um indicador de OUTRO      |
//|   timeframe — quem forca e' o CopyBuffer. Como o portao vinha      |
//|   antes, o indicador do TF de regime nunca era calculado e         |
//|   BarsCalculated ficava em 0 para sempre: DEADLOCK, zero trades.   |
//|   Agora o aquecimento SONDA com CopyBuffer (que forca o calculo)   |
//|   e informa no log quando fica pronto.                             |
//|  v1.03 - REFATORACAO + AUDITORIA:                                  |
//|   [B8] MinhaPosicao() usava o ticket como id de posicao. Agora usa |
//|        POSITION_IDENTIFIER explicitamente (netting x hedging).     |
//|   [B9] GRAVE: se o fechamento por SINAL falhasse, o EA abria outra |
//|        posicao mesmo assim -> duas posicoes simultaneas. Agora so' |
//|        abre se o fechamento foi confirmado.                        |
//|   [B10] Na adocao de posicao orfa, ATR indisponivel deixava        |
//|        g_armPts=0 e o breakeven armava IMEDIATAMENTE. Agora a      |
//|        adocao exige ATR valido; sem ele o BE fica desarmado.       |
//|   [B11] Sem aquecimento: nos primeiros ticks os indicadores ainda  |
//|        nao calcularam e as falhas poluiam o diagnostico. Agora ha  |
//|        checagem de BarsCalculated antes de operar.                 |
//|   [B12] Os 4 candidatos viravam 2 toggles soltos que o tester      |
//|        lembrava entre rodadas (armadilha que ja causou 2 rodadas   |
//|        erradas). Agora e' UM enum: impossivel misturar.            |
//|   [B13] Contadores de veto e de motivo de saida no resumo final.   |
//|  v1.02 - filtros do TMO como contexto (confluencia e histograma).  |
//|  v1.01 - [B1] stop/BE das VENDAS disparavam ~1 spread cedo (SL de  |
//|        venda dispara no ASK, e a medicao define tudo sobre o BID). |
//|        [B2] falha de CopyBuffer era indistinguivel de "sem sinal". |
//|        [B3] saidas pelo servidor gravavam pnl_moeda=0.             |
//|        [B4] objetos sem limite. [B5] posicao orfa. [B6] volume.    |
//|        [B7] PositionModify repetindo a cada tick.                  |
//|                                                                    |
//| DIFERENCAS CONHECIDAS vs a medicao (esperadas, nao sao bugs):      |
//|   - a medicao descartava ciclos > 3000 min; aqui a posicao         |
//|     atravessa o fim de semana (gap e swap entram).                 |
//|   - slippage e rejeicao de ordem nao existiam na medicao.          |
//|   Medir essa divergencia e' o proposito deste EA.                  |
//+------------------------------------------------------------------+
#property copyright "SBurn"
#property version   "2.05"
#property strict

#property tester_indicator "SBurn\\S-Ind-ScalpPullback.ex5"
#property tester_indicator "SBurn\\S-Ind-TMO_Scalper.ex5"

#include <Trade\Trade.mqh>

//--- candidatos medidos (troque SO este input entre as rodadas)
enum ENUM_CANDIDATO
{
   A_TITULAR = 0,   // sem filtro do TMO
   B_CONFLU  = 1,   // + confluencia MTF do TMO alinhada
   C_HIST    = 2,   // + histograma nao-profundo
   D_COMBO   = 3    // + confluencia E histograma
};

//+------------------------------------------------------------------+
//| Inputs                                                            |
//+------------------------------------------------------------------+
input group "=== CANDIDATO (unico input a trocar entre rodadas) ==="
input ENUM_CANDIDATO  InpCandidato = C_HIST;      // Candidato (C = melhor medido)

input group "=== Sinal (nao alterar sem nova medicao) ==="
input string          InpSPName    = "SBurn\\S-Ind-ScalpPullback"; // Indicador SP
input ENUM_TIMEFRAMES InpSPTF      = PERIOD_M30;   // TF de regime (concordancia)

input group "=== Filtros do TMO (ligados pelo candidato) ==="
input string          InpTMOName   = "SBurn\\S-Ind-TMO_Scalper"; // Indicador TMO
input ENUM_TIMEFRAMES InpTMOTF2    = PERIOD_M15;   // TMO: TF2 da cascata
input ENUM_TIMEFRAMES InpTMOTF3    = PERIOD_M30;   // TMO: TF3 da cascata
input double          InpHistMax   = 2.20;         // Corte |main-signal| (p67 medido)

input group "=== Saida (multiplos de ATR - MEDIDOS) ==="
input int             InpATRPeriod = 14;     // Periodo do ATR
input double          InpArmATR    = 0.73;   // Armar breakeven em, x ATR
input double          InpStopATR   = 3.67;   // Stop inicial, x ATR

input group "=== Reentrada R2 (parte da estrategia PRINCIPAL) ==="
input bool            InpR2Enabled   = true;  // Ligar reentrada por esgotamento
input int             InpR2Piso      = 5;     // Piso: barras minimas apos o scratch
input int             InpR2Calma     = 3;     // Barras sem novo extremo adverso = esgotou
input int             InpR2Validade  = 120;   // Validade do monitoramento, barras
input int             InpR2MaxPorSeq = 1;     // Maximo de reentradas por sequencia

input group "=== ESTRATEGIA SECUNDARIA: piramide (independente) ==="
input bool            InpPirEnabled  = false; // Ligar a piramide (v2.05: OFF)
input double          InpPirLots     = 0.01;  // Volume POR ADICAO
input ulong           InpPirMagic    = 20260901; // Magic proprio da piramide
input double          InpPirInicioATR = 2.00; // 1a adicao em, x ATR (medido: 2.0)
input double          InpPirPassoATR = 1.00;  // Espacamento entre adicoes, x ATR
input int             InpPirMaxPos   = 2;     // Maximo de ADICOES (alem da principal)
input double          InpPirArmATR   = 0.73;  // Armar BE da adicao em, x ATR
input double          InpPirStopATR  = 3.67;  // Stop da adicao, x ATR

input group "=== Execucao ==="
input double          InpLots      = 0.01;   // Volume por operacao
input ulong           InpMagic     = 20260814; // Magic number
input ulong           InpSlippage  = 30;     // Desvio maximo, pontos
input double          InpMaxSpread = 260;    // Spread max p/ entrar, pts (0 = sem filtro)

input group "=== Diagnostico ==="
input bool            InpLogCSV    = true;   // Gravar CSV de operacoes
input bool            InpDraw      = true;   // Marcar entradas/saidas no grafico
input int             InpMaxObj    = 400;    // Maximo de objetos no grafico
input int             InpMaxTentBE = 5;      // Tentativas de mover o BE por posicao
input string          InpRoot      = "SBurn"; // Pasta do CSV (Common\Files)

//+------------------------------------------------------------------+
//| Globais                                                           |
//+------------------------------------------------------------------+
CTrade   g_trade;
int      g_hSPsig = INVALID_HANDLE;   // SP no TF do grafico (sinal, buffer 26)
int      g_hSPreg = INVALID_HANDLE;   // SP no TF de regime (trend, buffer 27)
int      g_hATR   = INVALID_HANDLE;
int      g_hTMO   = INVALID_HANDLE;   // so criado se o candidato usar filtro
bool     g_usaConflu = false;
bool     g_usaHist   = false;
double   g_point;
datetime g_lastBar = 0;
int      g_csv = INVALID_HANDLE;
string   g_csvPath;
long     g_objId = 0;
bool     g_pronto = false;            // aquecimento dos indicadores concluido [B11]

//--- estado da posicao corrente (UMA posicao por vez)
bool     g_temPos    = false;
ulong    g_posId     = 0;             // POSITION_IDENTIFIER [B8]
int      g_dir       = 0;
datetime g_tEntrada  = 0;
double   g_pEntrada  = 0.0;
double   g_bidEnt    = 0.0;           // BID na entrada = nivel do breakeven
double   g_spreadEnt = 0.0;
double   g_atrEnt    = 0.0;
double   g_armPts    = 0.0;
bool     g_beArmado  = false;
int      g_tentBE    = 0;
double   g_mfe = 0.0, g_mae = 0.0;

//--- REENTRADA R2 [v2.00] — monitoramento do esgotamento do recuo
bool     g_r2Ativo   = false;  // monitorando um scratch?
int      g_r2Dir     = 0;      // direcao do trade que scratchou
double   g_r2BidBE   = 0.0;    // BID no momento do scratch (referencia)
double   g_r2Atr     = 0.0;    // ATR daquele trade
double   g_r2PiorAdv = 0.0;    // pior excursao adversa desde o scratch
double   g_r2MaxDesde= 0.0;    // maior excursao favoravel desde o scratch
double   g_r2Topo    = 0.0;    // topo CONGELADO do range (0 = ainda nao congelou)
datetime g_r2BarraPior = 0;    // barra do pior adverso
datetime g_r2Inicio  = 0;      // barra do scratch
int      g_r2Feitas  = 0;      // reentradas ja feitas nesta sequencia
int      g_seqAtual  = 0;      // indice da posicao principal (0 = original, 1+ = reentrada)

//--- PIRAMIDE [v2.00] — estrategia secundaria, magic proprio
CTrade   g_tradePir;
bool     g_pirAtiva  = false;  // ha sequencia de piramide em andamento?
int      g_pirDir    = 0;
double   g_pirBidRef = 0.0;    // BID de referencia (entrada da principal)
double   g_pirAtr    = 0.0;
int      g_pirAbertas= 0;      // quantas adicoes ja foram abertas
double   g_pirBidEnt[8];       // BID de entrada de cada adicao (p/ o BE dela)
double   g_pirMfe[8];          // excursao favoravel de cada adicao
bool     g_pirArm[8];          // BE da adicao armado?
ulong    g_pirTicket[8];       // ticket de cada adicao
bool     g_pirRejCont[8];      // [B17] rejeicao desta adicao ja contada?

//--- diagnostico
long     g_nOps=0, g_falhaSig=0, g_falhaCtx=0, g_falhaAbrir=0, g_falhaFechar=0;
long     g_blockSpread=0, g_vetoRegime=0, g_vetoConflu=0, g_vetoHist=0;
long     g_r2Disparos=0, g_r2Expirados=0, g_pirAdicoes=0;
long     g_pirRejeitadas=0, g_pirSemTicket=0;  // [B17] casos opostos, contados separados
long     g_saidaBE=0, g_saidaStop=0, g_saidaSinal=0;

//+------------------------------------------------------------------+
double Bid() { MqlTick t; return SymbolInfoTick(_Symbol, t) ? t.bid : 0.0; }
double Ask() { MqlTick t; return SymbolInfoTick(_Symbol, t) ? t.ask : 0.0; }
double SpreadPts() { double b=Bid(), a=Ask(); return (b>0 && a>0) ? (a-b)/g_point : 0.0; }

//+------------------------------------------------------------------+
//| Le um buffer. ok=false sinaliza FALHA (nao "valor zero") [B2]     |
//+------------------------------------------------------------------+
double LeBuffer(const int handle, const int buf, const int shift, bool &ok)
{
   double v[1];
   ok = (CopyBuffer(handle, buf, shift, 1, v) == 1);
   return ok ? v[0] : 0.0;
}

//+------------------------------------------------------------------+
//| Converte nivel definido no BID para preco de SL do servidor [B1]  |
//| SL de COMPRA dispara no BID; SL de VENDA dispara no ASK.          |
//+------------------------------------------------------------------+
double NivelBidParaSL(const double nivelBid, const int dir)
{
   double p = (dir > 0) ? nivelBid : nivelBid + g_spreadEnt * g_point;
   return NormalizeDouble(p, _Digits);
}

//+------------------------------------------------------------------+
//| Marca no grafico, com janela rolante [B4]                         |
//+------------------------------------------------------------------+
void Marca(const string prefixo, const datetime t, const double preco,
           const int dir, const color cor, const int codigo)
{
   if(!InpDraw) return;
   g_objId++;
   string nome = "SB_" + prefixo + "_" + IntegerToString(g_objId);
   if(!ObjectCreate(0, nome, OBJ_ARROW, 0, t, preco)) return;
   ObjectSetInteger(0, nome, OBJPROP_ARROWCODE, codigo);
   ObjectSetInteger(0, nome, OBJPROP_COLOR, cor);
   ObjectSetInteger(0, nome, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, nome, OBJPROP_ANCHOR, dir > 0 ? ANCHOR_TOP : ANCHOR_BOTTOM);
   ObjectSetInteger(0, nome, OBJPROP_SELECTABLE, false);
   long velho = g_objId - InpMaxObj;
   if(velho > 0)
   {
      ObjectDelete(0, "SB_IN_"  + IntegerToString(velho));
      ObjectDelete(0, "SB_OUT_" + IntegerToString(velho));
   }
}

//+------------------------------------------------------------------+
//| Normaliza o volume ao min/max/step do simbolo [B6]                |
//+------------------------------------------------------------------+
double VolumeValido(double v)
{
   double mn = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double mx = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double st = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(st > 0) v = MathRound(v / st) * st;
   v = MathMax(mn, MathMin(mx, v));
   int casas = (st >= 1.0) ? 0 : (st >= 0.1 ? 1 : 2);
   return NormalizeDouble(v, casas);
}

//+------------------------------------------------------------------+
//| Ticket da posicao do EA (0 se nao houver) [B8]                    |
//+------------------------------------------------------------------+
ulong MinhaPosicao(ulong &posId)
{
   posId = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;
      posId = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      return t;
   }
   return 0;
}
ulong MinhaPosicao() { ulong x; return MinhaPosicao(x); }

//+------------------------------------------------------------------+
//| Deal de saida no historico: preco e lucro REAIS [B3]              |
//+------------------------------------------------------------------+
bool DealDeSaida(const ulong posId, double &preco, double &lucro, datetime &quando)
{
   preco = 0.0; lucro = 0.0; quando = 0;
   if(posId == 0) return false;
   if(!HistorySelect(g_tEntrada - 60, TimeCurrent() + 60)) return false;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0) continue;
      if((ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID) != posId) continue;
      if(HistoryDealGetInteger(d, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      preco  = HistoryDealGetDouble(d, DEAL_PRICE);
      lucro  = HistoryDealGetDouble(d, DEAL_PROFIT) +
               HistoryDealGetDouble(d, DEAL_SWAP) +
               HistoryDealGetDouble(d, DEAL_COMMISSION);
      quando = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Grava a operacao encerrada no CSV                                 |
//+------------------------------------------------------------------+
void RegistraSaida(const string motivo)
{
   double pSaida = 0.0, lucro = 0.0; datetime tSaida = TimeCurrent();
   bool exato = DealDeSaida(g_posId, pSaida, lucro, tSaida);
   if(!exato) { pSaida = (g_dir > 0) ? Bid() : Ask(); tSaida = TimeCurrent(); }

   if(motivo == "BE")         g_saidaBE++;
   else if(motivo == "STOP")  g_saidaStop++;
   else                       g_saidaSinal++;

   // [v1.06] arma o gatilho de reentrada: precisa superar o EXTREMO que este
   // trade fez antes de voltar. Em range o preco nao supera; em tendencia sim.
   // [v2.00] R2: comeca a MONITORAR o esgotamento do recuo. Nao arma nivel
   // aqui — o topo do range so' e' congelado quando o recuo para de piorar.
   if(InpR2Enabled && motivo != "SINAL" && g_r2Feitas < InpR2MaxPorSeq && g_atrEnt > 0)
   {
      g_r2Ativo     = true;
      g_r2Dir       = g_dir;
      g_r2BidBE     = Bid();
      g_r2Atr       = g_atrEnt;
      g_r2PiorAdv   = 0.0;
      g_r2MaxDesde  = 0.0;
      g_r2Topo      = 0.0;
      g_r2Inicio    = iTime(_Symbol, PERIOD_CURRENT, 0);
      g_r2BarraPior = g_r2Inicio;
   }

   // P&L em pontos sobre o BID, comparavel com a medicao
   double bidSaida = (g_dir > 0) ? pSaida : pSaida - g_spreadEnt * g_point;
   double pnlPts = (bidSaida - g_bidEnt) / g_point * g_dir;

   Marca("OUT", tSaida, pSaida, -g_dir,
         (motivo == "STOP") ? clrRed : (motivo == "BE" ? clrGold : clrDodgerBlue), 251);

   if(g_csv == INVALID_HANDLE) return;
   int barras = (int)((tSaida - g_tEntrada) / PeriodSeconds(PERIOD_CURRENT));
   string l = TimeToString(g_tEntrada, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + ";" +
              IntegerToString(g_dir) + ";" +
              DoubleToString(g_pEntrada, _Digits) + ";" +
              DoubleToString(g_bidEnt, _Digits) + ";" +
              DoubleToString(g_atrEnt, 1) + ";" +
              DoubleToString(g_spreadEnt, 1) + ";" +
              TimeToString(tSaida, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + ";" +
              DoubleToString(pSaida, _Digits) + ";" + motivo + ";" +
              DoubleToString(pnlPts, 1) + ";" + DoubleToString(lucro, 2) + ";" +
              DoubleToString(g_mfe, 1) + ";" + DoubleToString(g_mae, 1) + ";" +
              IntegerToString(barras) + ";" + (exato ? "1" : "0") +
              ";" + IntegerToString(g_seqAtual);
   FileWriteString(g_csv, l + "\n");
}

//+------------------------------------------------------------------+
//| Fecha a posicao. Retorna true se confirmou o fechamento [B9]      |
//+------------------------------------------------------------------+
bool Fecha(const string motivo)
{
   ulong t = MinhaPosicao();
   if(t == 0) { g_temPos = false; return true; }
   if(!g_trade.PositionClose(t, InpSlippage))
   {
      g_falhaFechar++;
      PrintFormat("Falha ao fechar (%s): %d %s", motivo,
                  g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
      return false;
   }
   RegistraSaida(motivo);
   g_temPos = false;
   return true;
}

//+------------------------------------------------------------------+
//| Abre posicao na direcao dada                                      |
//+------------------------------------------------------------------+
void Abre(const int dir)
{
   bool ok;
   double atr = LeBuffer(g_hATR, 0, 1, ok) / g_point;
   if(!ok || atr <= 0) { g_falhaCtx++; return; }

   double bid = Bid(), ask = Ask();
   if(bid <= 0 || ask <= 0) return;

   double spread = (ask - bid) / g_point;
   if(InpMaxSpread > 0 && spread > InpMaxSpread) { g_blockSpread++; return; }

   g_spreadEnt = spread;
   double stopPts = InpStopATR * atr;
   double nivelBidStop = (dir > 0) ? (bid - stopPts * g_point) : (bid + stopPts * g_point);
   double sl = NivelBidParaSL(nivelBidStop, dir);

   double vol = VolumeValido(InpLots);
   bool enviado = (dir > 0) ? g_trade.Buy(vol, _Symbol, 0.0, sl, 0.0, "SBurn pullback")
                            : g_trade.Sell(vol, _Symbol, 0.0, sl, 0.0, "SBurn pullback");
   if(!enviado)
   {
      g_falhaAbrir++;
      PrintFormat("Falha ao abrir (%d): %d %s", dir, g_trade.ResultRetcode(),
                  g_trade.ResultRetcodeDescription());
      return;
   }

   ulong pid = 0;
   if(MinhaPosicao(pid) == 0)
   { g_falhaAbrir++; Print("Ordem enviada mas posicao nao encontrada"); return; }

   g_nOps++;
   g_posId    = pid;
   g_temPos   = true;
   g_dir      = dir;
   g_tEntrada = TimeCurrent();
   g_pEntrada = g_trade.ResultPrice();
   g_bidEnt   = bid;
   g_atrEnt   = atr;
   g_armPts   = InpArmATR * atr;
   g_beArmado = false;
   g_tentBE   = 0;
   g_mfe = 0.0; g_mae = 0.0;

   Marca("IN", g_tEntrada, g_pEntrada, dir, dir > 0 ? clrLime : clrOrangeRed,
         dir > 0 ? 233 : 234);

   //--- [v2.00] a piramide acompanha a entrada principal (so' na original)
   if(InpPirEnabled && g_seqAtual == 0)
   {
      g_pirAtiva   = true;
      g_pirDir     = dir;
      g_pirBidRef  = bid;
      g_pirAtr     = atr;
      g_pirAbertas = 0;
      for(int k = 0; k < 8; k++) { g_pirTicket[k] = 0; g_pirArm[k] = false; g_pirMfe[k] = 0; }
   }
}

//+------------------------------------------------------------------+
//| Move o stop para o nivel BID DE ENTRADA (degrau zero medido)      |
//+------------------------------------------------------------------+
void AplicaBreakeven()
{
   if(!g_temPos || g_beArmado) return;
   if(g_armPts <= 0.0) return;                  // [B10] sem ATR valido, nao arma
   if(g_mfe < g_armPts) return;
   if(g_tentBE >= InpMaxTentBE) return;         // [B7]

   ulong t = MinhaPosicao();
   if(t == 0) return;
   double sl = NivelBidParaSL(g_bidEnt, g_dir); // [B1] venda soma o spread
   if(g_trade.PositionModify(t, sl, 0.0))
      g_beArmado = true;
   else
   {
      g_tentBE++;
      if(g_tentBE == 1)
         PrintFormat("Falha ao mover BE: %d %s", g_trade.ResultRetcode(),
                     g_trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| [v2.00] PIRAMIDE — estrategia SECUNDARIA, magic e lote proprios.  |
//| Adiciona uma posicao a cada InpPirPassoATR de excursao favoravel   |
//| da PRINCIPAL. Cada adicao carrega BE e stop PROPRIOS, medidos do   |
//| seu proprio nivel de entrada — nao e' grid: so' adiciona em cima   |
//| de movimento que ja' andou a favor.                                |
//+------------------------------------------------------------------+
void PiramideAbrir(const int k)
{
   if(k < 0 || k >= 8) return;
   double bid = Bid(), ask = Ask();
   if(bid <= 0 || ask <= 0 || g_pirAtr <= 0) return;
   if(InpMaxSpread > 0 && (ask - bid) / g_point > InpMaxSpread) return;

   double spread = (ask - bid) / g_point;
   double stopPts = InpPirStopATR * g_pirAtr;
   double nivelBid = (g_pirDir > 0) ? (bid - stopPts * g_point) : (bid + stopPts * g_point);
   double sl = (g_pirDir > 0) ? nivelBid : nivelBid + spread * g_point;
   sl = NormalizeDouble(sl, _Digits);

   double vol = VolumeValido(InpPirLots);
   bool ok = (g_pirDir > 0)
             ? g_tradePir.Buy (vol, _Symbol, 0.0, sl, 0.0, "SBurn piramide")
             : g_tradePir.Sell(vol, _Symbol, 0.0, sl, 0.0, "SBurn piramide");
   if(!ok)
   {
      //--- [B17] g_pirAbertas NAO avanca quando a ordem falha, entao o alvo do
      //    passo continua valido e PiramideAbrir era chamada — e contada — a
      //    cada tick. Conta e imprime UMA vez por adicao.
      if(!g_pirRejCont[k])
      {
         g_pirRejCont[k] = true;
         g_pirRejeitadas++;
         PrintFormat("Piramide: ordem da adicao %d REJEITADA: %d %s", k + 1,
                     g_tradePir.ResultRetcode(), g_tradePir.ResultRetcodeDescription());
      }
      return;
   }
   g_pirBidEnt[k] = bid;
   g_pirMfe[k]    = 0.0;
   g_pirArm[k]    = false;
   g_pirTicket[k] = 0;

   //--- [B16] identificacao do ticket, do mais confiavel para o menos.
   //    A v2.02 dependia do DEAL desta ordem ja' estar no historico; no tester
   //    ele nao esta logo apos o envio, o posId ficava 0 e a adicao seguia sem
   //    BE. Em conta HEDGING o ticket da POSICAO e' igual ao ticket da ORDEM de
   //    abertura, e ResultOrder() devolve isso na hora.
   ulong tk   = 0;
   ulong ord  = g_tradePir.ResultOrder();
   ulong deal = g_tradePir.ResultDeal();

   //--- 1) ordem DESTA requisicao (caminho normal em hedging)
   if(ord != 0 && PositionSelectByTicket(ord) &&
      PositionGetInteger(POSITION_MAGIC) == (long)InpPirMagic)
      tk = ord;

   //--- 2) deal DESTA requisicao -> DEAL_POSITION_ID (metodo da v2.02)
   if(tk == 0 && deal != 0 && HistorySelect(TimeCurrent() - 300, TimeCurrent() + 60))
   {
      ulong posId = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      if(posId != 0)
      {
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong t = PositionGetTicket(i);
            if(t == 0) continue;
            if((ulong)PositionGetInteger(POSITION_IDENTIFIER) != posId) continue;
            tk = t;
            break;
         }
      }
   }

   //--- 3) varredura por magic: a posicao MAIS RECENTE (maior POSITION_TIME),
   //    ignorando ticket ja' atribuido a outra adicao. Pegar "a primeira
   //    encontrada" era exatamente o defeito do [B14].
   if(tk == 0)
   {
      datetime melhorT  = 0;
      ulong    melhorTk = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong t = PositionGetTicket(i);
         if(t == 0) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != (long)InpPirMagic) continue;
         bool jaUsado = false;
         for(int j = 0; j < k; j++) if(g_pirTicket[j] == t) { jaUsado = true; break; }
         if(jaUsado) continue;
         datetime pt = (datetime)PositionGetInteger(POSITION_TIME);
         if(pt > melhorT || (pt == melhorT && t > melhorTk)) { melhorT = pt; melhorTk = t; }
      }
      tk = melhorTk;
   }
   g_pirTicket[k] = tk;

   if(g_pirTicket[k] == 0)
   {
      //--- [B15] a falha de identificacao era SILENCIOSA: a adicao existia,
      //    o loop do BE a pulava para sempre (g_pirTicket==0) e ela seguia so'
      //    com o stop inicial. Conta separado da rejeicao [B17] e vai para o
      //    log. No maximo uma vez por adicao: g_pirAbertas avanca logo abaixo
      //    e este slot nao volta a ser aberto.
      g_pirSemTicket++;
      PrintFormat("Piramide: adicao %d aberta mas NAO identificada "
                  "(ordem=%s deal=%s). Ela fica com o stop inicial e SEM breakeven.",
                  k + 1, IntegerToString((long)ord), IntegerToString((long)deal));
   }
   g_pirAbertas++;
   g_pirAdicoes++;
   Marca("PIR", TimeCurrent(), g_tradePir.ResultPrice(), g_pirDir,
         g_pirDir > 0 ? clrAqua : clrMagenta, g_pirDir > 0 ? 233 : 234);
}

//+------------------------------------------------------------------+
//| Fecha todas as posicoes da piramide                                |
//+------------------------------------------------------------------+
void PiramideFechar()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpPirMagic) continue;
      g_tradePir.PositionClose(t, InpSlippage);
   }
   g_pirAtiva = false; g_pirAbertas = 0;
   for(int k = 0; k < 8; k++)
   { g_pirTicket[k] = 0; g_pirArm[k] = false; g_pirMfe[k] = 0; g_pirRejCont[k] = false; }
}

//+------------------------------------------------------------------+
//| Gerencia a piramide a cada tick: abre adicoes e move o BE de cada |
//|                                                                   |
//| A DECIDIR (comportamento atual, NAO medido isolado): a piramide   |
//| SOBREVIVE ao BE e ao STOP da principal — so' e' encerrada por     |
//| sinal novo do SP. Depois de um scratch ela continua aberta E ainda|
//| pode abrir adicoes novas, sempre ancorada no g_pirBidRef da       |
//| entrada ORIGINAL (a reentrada R2 nao re-ancora: Abre() so' rearma |
//| a piramide quando g_seqAtual==0).                                 |
//| Isso pode ser exatamente o desejado — e' a continuacao que a      |
//| principal perde nos 63% de scratch, que e' o problema aberto da   |
//| secao 5.2 do CLAUDE.md. Mas nunca foi medido dos dois jeitos.     |
//| Nao alterar sem rodar as duas versoes na mesma janela.            |
//+------------------------------------------------------------------+
void PiramideGerenciar()
{
   if(!InpPirEnabled || !g_pirAtiva || g_pirAtr <= 0) return;
   double bid = Bid();
   if(bid <= 0) return;
   double excRef = (bid - g_pirBidRef) / g_point * g_pirDir;   // excursao da PRINCIPAL

   //--- abre a proxima adicao quando o movimento atinge o passo seguinte
   int maxAd = (InpPirMaxPos < 8) ? InpPirMaxPos : 8;
   if(g_pirAbertas < maxAd)
   {
      // [v2.01] a 1a adicao entra em InpPirInicioATR; as seguintes somam o passo
      double alvo = (InpPirInicioATR + g_pirAbertas * InpPirPassoATR) * g_pirAtr;
      if(excRef >= alvo) PiramideAbrir(g_pirAbertas);
   }

   //--- BE proprio de cada adicao, no nivel BID de entrada dela
   for(int k = 0; k < g_pirAbertas && k < 8; k++)
   {
      if(g_pirTicket[k] == 0 || g_pirArm[k]) continue;
      if(!PositionSelectByTicket(g_pirTicket[k])) { g_pirTicket[k] = 0; continue; }
      double excK = (bid - g_pirBidEnt[k]) / g_point * g_pirDir;
      if(excK > g_pirMfe[k]) g_pirMfe[k] = excK;
      if(g_pirMfe[k] >= InpPirArmATR * g_pirAtr)
      {
         double spread = (Ask() - bid) / g_point;
         double sl = (g_pirDir > 0) ? g_pirBidEnt[k] : g_pirBidEnt[k] + spread * g_point;
         if(g_tradePir.PositionModify(g_pirTicket[k], NormalizeDouble(sl, _Digits), 0.0))
            g_pirArm[k] = true;
      }
   }
}

//+------------------------------------------------------------------+
//| Adota posicao pre-existente [B5][B10]                             |
//+------------------------------------------------------------------+
void AdotaPosicao()
{
   ulong pid = 0;
   ulong t = MinhaPosicao(pid);
   if(t == 0) return;
   bool ok;
   double atr = LeBuffer(g_hATR, 0, 1, ok) / g_point;
   g_posId    = pid;
   g_temPos   = true;
   g_dir      = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
   g_tEntrada = (datetime)PositionGetInteger(POSITION_TIME);
   g_pEntrada = PositionGetDouble(POSITION_PRICE_OPEN);
   g_spreadEnt = SpreadPts();
   g_bidEnt   = (g_dir > 0) ? g_pEntrada - g_spreadEnt * g_point : g_pEntrada;
   g_atrEnt   = (ok && atr > 0) ? atr : 0.0;
   g_armPts   = (g_atrEnt > 0) ? InpArmATR * g_atrEnt : 0.0;   // 0 = BE desarmado
   g_beArmado = false; g_tentBE = 0;
   g_mfe = 0.0; g_mae = 0.0;
   PrintFormat("Posicao existente adotada (dir %d). Niveis reconstruidos por "
               "aproximacao; BE %s.", g_dir, g_armPts > 0 ? "ativo" : "DESARMADO");
}

//+------------------------------------------------------------------+
//| Indicadores aquecidos? [B11]                                      |
//+------------------------------------------------------------------+
bool Aquecido()
{
   if(g_pronto) return true;
   // SONDA com CopyBuffer: e' ele que forca o calculo de indicadores
   // de outro timeframe no tester. BarsCalculated sozinho nao forca.
   double v[1];
   if(CopyBuffer(g_hSPsig, 26, 1, 1, v) != 1) return false;
   if(CopyBuffer(g_hSPreg, 27, 1, 1, v) != 1) return false;
   if(CopyBuffer(g_hATR,    0, 1, 1, v) != 1) return false;
   if(g_hTMO != INVALID_HANDLE && CopyBuffer(g_hTMO, 15, 1, 1, v) != 1) return false;
   g_pronto = true;
   Print("Indicadores aquecidos; EA operando a partir de ", TimeToString(TimeCurrent()));
   return true;
}

//+------------------------------------------------------------------+
//| Filtros de contexto do TMO. Retorna false se o sinal for vetado.  |
//+------------------------------------------------------------------+
bool ContextoTMOaprova(const int dir)
{
   if(g_hTMO == INVALID_HANDLE) return true;
   bool ok;
   if(g_usaConflu)
   {
      double conflu = LeBuffer(g_hTMO, 15, 1, ok);   // +1 / -1 / 0
      if(!ok) { g_falhaCtx++; return false; }
      if(conflu * dir <= 0) { g_vetoConflu++; return false; }
   }
   if(g_usaHist)
   {
      bool ok2;
      double main = LeBuffer(g_hTMO, 0, 1, ok);
      double sig  = LeBuffer(g_hTMO, 2, 1, ok2);
      if(!ok || !ok2) { g_falhaCtx++; return false; }
      if(MathAbs(main - sig) >= InpHistMax) { g_vetoHist++; return false; }
   }
   return true;
}

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   g_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(g_point <= 0) { Print("Ponto invalido"); return INIT_FAILED; }
   if(InpArmATR <= 0 || InpStopATR <= 0 || InpLots <= 0 || InpATRPeriod < 1)
   { Print("Parametros invalidos"); return INIT_PARAMETERS_INCORRECT; }
   // [v2.01] a piramide e' estrategia SEPARADA: parametros e magic proprios
   if(InpPirEnabled)
   {
      if(InpPirInicioATR <= 0 || InpPirPassoATR <= 0 || InpPirLots <= 0 || InpPirMaxPos < 1)
      { Print("Parametros da piramide invalidos"); return INIT_PARAMETERS_INCORRECT; }
      if(InpPirMagic == InpMagic)
      {
         Print("InpPirMagic deve ser DIFERENTE de InpMagic — magics iguais "
               "misturam as duas estrategias e corrompem a contabilidade.");
         return INIT_PARAMETERS_INCORRECT;
      }
   }

   //--- [B12] os filtros derivam do candidato: impossivel misturar
   g_usaConflu = (InpCandidato == B_CONFLU || InpCandidato == D_COMBO);
   g_usaHist   = (InpCandidato == C_HIST   || InpCandidato == D_COMBO);

   g_hSPsig = iCustom(_Symbol, PERIOD_CURRENT, InpSPName);
   if(g_hSPsig == INVALID_HANDLE)
   { Print("Falha ao criar handle do SP no TF do grafico"); return INIT_FAILED; }

   g_hSPreg = iCustom(_Symbol, InpSPTF, InpSPName);
   if(g_hSPreg == INVALID_HANDLE)
   { Print("Falha ao criar handle do SP no TF de regime"); return INIT_FAILED; }

   g_hATR = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   if(g_hATR == INVALID_HANDLE)
   { Print("Falha ao criar handle do ATR"); return INIT_FAILED; }

   if(g_usaConflu || g_usaHist)
   {
      // ORDEM POSICIONAL dos 22 inputs do TMO v4.02 (o indicador nao tem
      // input group justamente porque grupos desalinham parametros no iCustom)
      g_hTMO = iCustom(_Symbol, PERIOD_CURRENT, InpTMOName,
                       InpTMOTF2, InpTMOTF3,      // TF2, TF3
                       7, 3, 2,                   // TMOLen, CalcLen, SmoothLen
                       4.0,                       // HistScale
                       1.5, 7.0, -7.0,            // Offset, OB, OS
                       false, false, false, false,// ShowSig1, Sig1Extreme, ShowSig2, Sig2Extreme
                       false,                     // UseCascade
                       false, 5,                  // ExhaustFilter, ExhaustLookback
                       3, 0.1, false,             // Cooldown, MinCross, ZeroFilter
                       14,                        // ATRPeriod
                       false, 60);                // ShowCycle, MaxCycleObj
      if(g_hTMO == INVALID_HANDLE)
      { Print("Falha ao criar handle do TMO"); return INIT_FAILED; }
   }

   g_trade.SetExpertMagicNumber(InpMagic);
   g_tradePir.SetExpertMagicNumber(InpPirMagic);      // [v2.00] magic proprio
   g_tradePir.SetDeviationInPoints(InpSlippage);
   g_tradePir.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetDeviationInPoints(InpSlippage);
   g_trade.SetTypeFillingBySymbol(_Symbol);

   if(InpLogCSV)
   {
      string dt = TimeToString(TimeCurrent(), TIME_DATE);
      StringReplace(dt, ".", "-");
      g_csvPath = InpRoot + "\\ops_" + EnumToString(InpCandidato) + "_" + _Symbol + "_" +
                  EnumToString(_Period) + "_" + dt + ".csv";
      g_csv = FileOpen(g_csvPath, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
      if(g_csv == INVALID_HANDLE)
      { Print("Falha ao abrir CSV: ", g_csvPath); return INIT_FAILED; }
      FileWriteString(g_csv,
         "t_entrada;dir;p_entrada;bid_entrada;atr_ent;spread_ent;"
         "t_saida;p_saida;motivo;pnl_pts;pnl_moeda;mfe_pts;mae_pts;barras;preco_exato;seq\n");
   }

   AdotaPosicao();

   PrintFormat("S-EA-Pullback_Live v2.05 | cand=%s (conflu=%s hist=%s) | TF=%s SPTF=%s "
               "arm=%.2fxATR stop=%.2fxATR lote=%.2f maxSpread=%.0f | R2=%s "
               "piramide=%s(inicio %.1f passo %.1f max %d)",
               EnumToString(InpCandidato), g_usaConflu?"ON":"off", g_usaHist?"ON":"off",
               EnumToString(_Period), EnumToString(InpSPTF),
               InpArmATR, InpStopATR, VolumeValido(InpLots), InpMaxSpread,
               InpR2Enabled?"ON":"off", InpPirEnabled?"ON":"off",
               InpPirInicioATR, InpPirPassoATR, InpPirMaxPos);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   PrintFormat("=== %s: %d operacoes | saidas: BE=%d STOP=%d SINAL=%d ===",
               EnumToString(InpCandidato), (int)g_nOps,
               (int)g_saidaBE, (int)g_saidaStop, (int)g_saidaSinal);
   PrintFormat("R2: reentradas=%d expiradas=%d | piramide: adicoes=%d rejeitadas=%d sem_ticket=%d",
               (int)g_r2Disparos, (int)g_r2Expirados, (int)g_pirAdicoes,
               (int)g_pirRejeitadas, (int)g_pirSemTicket);
   PrintFormat("vetos: regime=%d conflu=%d hist=%d spread=%d | "
               "falhas: sinal=%d contexto=%d abrir=%d fechar=%d",
               (int)g_vetoRegime, (int)g_vetoConflu, (int)g_vetoHist, (int)g_blockSpread,
               (int)g_falhaSig, (int)g_falhaCtx, (int)g_falhaAbrir, (int)g_falhaFechar);
   if(g_falhaSig > 0 || g_falhaCtx > 0 || g_falhaAbrir > 0 || g_falhaFechar > 0)
      Print("ATENCAO: houve falhas — conferir antes de usar o resultado.");
   if(g_csv != INVALID_HANDLE) { FileClose(g_csv); g_csv = INVALID_HANDLE; Print("CSV: ", g_csvPath); }
   if(g_hSPsig != INVALID_HANDLE) IndicatorRelease(g_hSPsig);
   if(g_hSPreg != INVALID_HANDLE) IndicatorRelease(g_hSPreg);
   if(g_hATR   != INVALID_HANDLE) IndicatorRelease(g_hATR);
   if(g_hTMO   != INVALID_HANDLE) IndicatorRelease(g_hTMO);
}

//+------------------------------------------------------------------+
//| OnTick                                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- posicao fechada pelo SERVIDOR (stop ou breakeven)?
   if(g_temPos && MinhaPosicao() == 0)
   {
      RegistraSaida(g_beArmado ? "BE" : "STOP");
      g_temPos = false;
   }

   //--- [v2.00] piramide: gerencia adicoes e BE proprios
   PiramideGerenciar();

   //--- excursoes (sobre o BID, igual a medicao) e breakeven
   if(g_temPos)
   {
      double exc = (Bid() - g_bidEnt) / g_point * g_dir;
      if(exc > g_mfe)  g_mfe = exc;
      if(-exc > g_mae) g_mae = -exc;
      AplicaBreakeven();
   }

   //--- [v2.00] R2: monitora o esgotamento do recuo e reentra no rompimento
   if(InpR2Enabled && g_r2Ativo && !g_temPos)
   {
      int ps = PeriodSeconds(PERIOD_CURRENT);
      datetime barra = iTime(_Symbol, PERIOD_CURRENT, 0);
      int desde = (int)((barra - g_r2Inicio) / ps);
      double excS = (Bid() - g_r2BidBE) / g_point * g_r2Dir;

      if(desde > InpR2Validade) { g_r2Ativo = false; g_r2Expirados++; }
      else
      {
         // pior adverso: enquanto piora, o recuo NAO esgotou
         //
         // LIMITE CONHECIDO (nao corrigido de proposito): g_r2Topo usa 0.0
         // como "ainda nao congelou". Se o recuo nunca fez excursao favoravel
         // (g_r2MaxDesde==0), congelar em zero fica indistinguivel de nao ter
         // congelado, e a R2 nao dispara nesse scratch. Separar os dois casos
         // (um bool) faria o gatilho passar a valer "qualquer tick a favor",
         // que e' um gatilho DIFERENTE — mudanca de comportamento, exige
         // medicao antes. Ver R1/R7 do CLAUDE.md.
         if(-excS > g_r2PiorAdv) { g_r2PiorAdv = -excS; g_r2BarraPior = barra; g_r2Topo = 0.0; }
         else if(g_r2Topo == 0.0 && (int)((barra - g_r2BarraPior) / ps) >= InpR2Calma)
            g_r2Topo = g_r2MaxDesde;              // CONGELA o topo do range
         if(excS > g_r2MaxDesde) g_r2MaxDesde = excS;

         // gatilho: piso cumprido, recuo esgotado, e rompeu o topo congelado
         if(desde >= InpR2Piso && g_r2Topo != 0.0 && excS > g_r2Topo)
         {
            bool okReg2;
            double reg2 = LeBuffer(g_hSPreg, 27, 1, okReg2);
            if(okReg2 && reg2 * g_r2Dir > 0)      // regime ainda alinhado
            {
               int dirRe = g_r2Dir;
               g_r2Ativo = false;
               g_seqAtual = g_r2Feitas + 1;
               Abre(dirRe);
               if(g_temPos) { g_r2Feitas++; g_r2Disparos++; }
               else         g_seqAtual = 0;
               return;
            }
            else if(okReg2) g_r2Ativo = false;    // regime virou: descarta
         }
      }
   }

   //--- nova barra: le o sinal da barra FECHADA (shift 1)
   datetime bt = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(bt <= 0 || bt == g_lastBar) return;
   bool primeira = (g_lastBar == 0);
   g_lastBar = bt;
   if(primeira) return;
   if(!Aquecido()) return;                       // [B11]

   bool okSig;
   double sinal = LeBuffer(g_hSPsig, 26, 1, okSig);
   if(!okSig) { g_falhaSig++; return; }
   if(sinal == 0.0) return;
   int dir = (sinal > 0) ? 1 : -1;

   //--- qualquer sinal encerra a posicao corrente [B9]
   if(g_temPos && !Fecha("SINAL")) return;       // nao abre se nao conseguiu fechar

   //--- sinal novo = nova sequencia direcional: zera piramide e gatilho
   g_r2Ativo = false; g_r2Feitas = 0; g_seqAtual = 0;
   // Sinal novo encerra as DUAS estrategias. E' o UNICO ponto em que a
   // piramide e' fechada — BE e STOP da principal nao a encerram (ver a
   // nota em PiramideGerenciar).
   if(InpPirEnabled) PiramideFechar();

   //--- regime do TF maior (celula validada)
   bool okReg;
   double regime = LeBuffer(g_hSPreg, 27, 1, okReg);
   if(!okReg) { g_falhaCtx++; return; }
   if(regime * dir <= 0) { g_vetoRegime++; return; }

   //--- filtros de contexto do TMO (conforme o candidato)
   if(!ContextoTMOaprova(dir)) return;

   Abre(dir);
}
//+------------------------------------------------------------------+