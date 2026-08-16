//+------------------------------------------------------------------+
//| >>> INSTALACAO (LEIA PRIMEIRO) <<<                                |
//| PASTA:    <PastaDeDados>\MQL5\Experts\SBurn\                      |
//| ARQUIVO:  S-EA-Pullback_Live.mq5                                  |
//| COMPILAR: SIM (F7). Requer em Indicators\SBurn\:                  |
//|             S-Ind-ScalpPullback.ex5  (sempre)                     |
//|             S-Ind-TMO_Scalper.ex5    (se usar candidato B/C/D)    |
//| ASSINATURA no log ao iniciar (prova de identidade):               |
//|   "S-EA-Pullback_Live v1.07 | cand=... TF=... SPTF=..."           |
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
//| DEFAULTS = MELHOR CONFIGURACAO MEDIDA (backtest real, ticks reais, |
//| XAUUSDm M5, 2026.01.01-08.12, 0.01 lote):                          |
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
//|  v1.07 - auditoria pre-backup: o contador de reentradas era        |
//|   incrementado ANTES de a ordem ser confirmada; se a abertura      |
//|   falhasse, a cota da piramide era consumida sem trade. Agora so'  |
//|   incrementa apos a posicao existir.                               |
//|  v1.06 - REENTRADA COM PIRAMIDE (opcional, DESLIGADA por padrao). |
//|   Motivo medido: a estrategia fica no mercado apenas 9% do tempo  |
//|   e participa de 31% do movimento direcional que ela mesma        |
//|   identifica. Apos um scratch por breakeven, em 71% dos casos o   |
//|   preco RETOMA a direcao original e anda ~10.000 pts sem ela.     |
//|   Apos um stop, 83% e ~17.000 pts.                                |
//|   Nenhuma variavel conhecida no momento do scratch prevê isso     |
//|   (MFE, duracao, ATR: todos entre 66% e 77%, rho ~0.1). Logo o    |
//|   gatilho tem que ser CONFIRMACAO, nao previsao — coerente com a  |
//|   lei do projeto: evento de mudanca nao tem direcao, ESTADO tem.  |
//|                                                                    |
//|   GATILHO: o preco supera o EXTREMO que o trade anterior fez       |
//|   antes de voltar (entrada + MFE), com folga de InpReentryK x ATR.|
//|   Por que este: num range o preco por definicao NAO supera o      |
//|   extremo anterior — ele bate e volta. Se superou, deixou de ser  |
//|   range. O filtro e' a propria definicao de lateralidade,         |
//|   invertida. E a entrada e' por confirmacao (o mercado prova).    |
//|                                                                    |
//|   PIRAMIDE: SEQUENCIAL (uma posicao por vez), ate                 |
//|   InpMaxReentradas por sequencia direcional. Nao ha exposicao     |
//|   simultanea: o risco por trade continua sendo 1 stop.            |
//|   A coluna "seq" no CSV traz o indice (0 = original, 1..N =       |
//|   reentradas) para medir a curva de decaimento e decidir a        |
//|   profundidade — nao chutar.                                      |
//|   Condicoes: regime do TF maior ainda alinhado, gatilho expira em |
//|   InpReentryBars barras, e opcionalmente exige ATR em expansao.   |
//|   TUDO NAO CALIBRADO ate a grade rodar.                           |
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
#property version   "1.07"
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

input group "=== Reentrada / piramide (GRADE, NAO CALIBRADA) ==="
input bool            InpReentry     = false; // Ligar reentrada apos scratch/stop
input double          InpReentryK    = 0.00;  // Folga alem do extremo anterior, x ATR
input int             InpMaxReentradas = 3;   // Maximo de reentradas por sequencia
input int             InpReentryBars = 24;    // Validade do gatilho, em barras
input bool            InpReentryExp  = false; // Exigir ATR em expansao vs a entrada original

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

//--- reentrada [v1.06]
bool     g_reArmado = false;   // ha gatilho de reentrada pendente?
int      g_reDir    = 0;       // direcao do gatilho
double   g_reNivel  = 0.0;     // preco que precisa ser superado (em BID)
double   g_reAtrOrig= 0.0;     // ATR da entrada original (p/ teste de expansao)
datetime g_reAte    = 0;       // validade do gatilho
int      g_reIdx    = 0;       // quantas reentradas ja feitas nesta sequencia
int      g_seqAtual = 0;       // indice da posicao corrente (0 = original)

//--- diagnostico
long     g_nOps=0, g_falhaSig=0, g_falhaCtx=0, g_falhaAbrir=0, g_falhaFechar=0;
long     g_blockSpread=0, g_vetoRegime=0, g_vetoConflu=0, g_vetoHist=0;
long     g_vetoReExpira=0, g_vetoReRegime=0;
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
   if(InpReentry && motivo != "SINAL" && g_reIdx < InpMaxReentradas && g_atrEnt > 0)
   {
      double extremo = g_bidEnt + g_dir * (g_mfe + InpReentryK * g_atrEnt) * g_point;
      g_reArmado  = true;
      g_reDir     = g_dir;
      g_reNivel   = extremo;
      g_reAtrOrig = g_atrEnt;
      g_reAte     = TimeCurrent() + (datetime)(InpReentryBars * PeriodSeconds(PERIOD_CURRENT));
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

   PrintFormat("S-EA-Pullback_Live v1.07 | cand=%s (conflu=%s hist=%s) | TF=%s SPTF=%s "
               "arm=%.2fxATR stop=%.2fxATR lote=%.2f maxSpread=%.0f | reentry=%s(K=%.2f max=%d)",
               EnumToString(InpCandidato), g_usaConflu?"ON":"off", g_usaHist?"ON":"off",
               EnumToString(_Period), EnumToString(InpSPTF),
               InpArmATR, InpStopATR, VolumeValido(InpLots), InpMaxSpread,
               InpReentry?"ON":"off", InpReentryK, InpMaxReentradas);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   PrintFormat("=== %s: %d operacoes | saidas: BE=%d STOP=%d SINAL=%d ===",
               EnumToString(InpCandidato), (int)g_nOps,
               (int)g_saidaBE, (int)g_saidaStop, (int)g_saidaSinal);
   PrintFormat("reentradas: expiradas=%d regime mudou=%d", (int)g_vetoReExpira, (int)g_vetoReRegime);
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

   //--- excursoes (sobre o BID, igual a medicao) e breakeven
   if(g_temPos)
   {
      double exc = (Bid() - g_bidEnt) / g_point * g_dir;
      if(exc > g_mfe)  g_mfe = exc;
      if(-exc > g_mae) g_mae = -exc;
      AplicaBreakeven();
   }

   //--- [v1.06] gatilho de reentrada: so' com posicao fechada
   if(InpReentry && g_reArmado && !g_temPos)
   {
      if(TimeCurrent() > g_reAte) { g_reArmado = false; g_vetoReExpira++; }
      else
      {
         double b = Bid();
         bool rompeu = (g_reDir > 0) ? (b >= g_reNivel) : (b <= g_reNivel);
         if(rompeu)
         {
            bool okReg2, okAtr;
            double reg2 = LeBuffer(g_hSPreg, 27, 1, okReg2);
            double atrN = LeBuffer(g_hATR, 0, 1, okAtr) / g_point;
            if(!okReg2 || !okAtr) { /* tenta no proximo tick */ }
            else if(reg2 * g_reDir <= 0) { g_reArmado = false; g_vetoReRegime++; }
            else if(InpReentryExp && atrN <= g_reAtrOrig) { /* espera expansao */ }
            else
            {
               int dirRe = g_reDir;
               g_reArmado = false;
               g_seqAtual = g_reIdx + 1;
               Abre(dirRe);
               if(g_temPos) g_reIdx++;         // so' consome a cota se abriu
               else         g_seqAtual = 0;
               return;
            }
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
   g_reArmado = false; g_reIdx = 0; g_seqAtual = 0;

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
