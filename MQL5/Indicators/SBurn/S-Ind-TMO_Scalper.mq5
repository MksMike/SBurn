//+------------------------------------------------------------------+
//| >>> INSTALACAO (LEIA PRIMEIRO) <<<                                |
//| PASTA:    <PastaDeDados>\MQL5\Indicators\SBurn\          |
//| ARQUIVO:  S-Ind-TMO_Scalper.mq5                                  |
//| COMPILAR: SIM (F7) -> gera S-Ind-TMO_Scalper.ex5                 |
//| ASSINATURA no log ao iniciar (prova de identidade):               |
//|   "S-Ind-TMO_Scalper v4.02 ... | TF2=PERIOD_M5 TF3=PERIOD_M15    |
//|    TMOLen=7 ..." <- os VALORES tem que bater com o esperado       |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| S-Ind-TMO_Scalper.mq5                                             |
//| TMO Scalper v4 — zero-repaint REAL (historico == live)            |
//+------------------------------------------------------------------+
//| v4.02 - BUG CRITICO DE INTERFACE (iCustom): as linhas            |
//|         "input group" ocupavam POSICAO na passagem de            |
//|         parametros via iCustom neste build, deslocando TUDO:     |
//|         TF3 recebia 7 (-> erro M7), TMOLen recebia 2 (-> main    |
//|         travado em +-7.50), ExhaustFilter recebia true com       |
//|         Lookback 0 (-> ZERO sinais). No grafico (sem iCustom)    |
//|         nada disso aparecia. Correcao: groups removidos (viram   |
//|         comentarios) + OnInit imprime os parametros RECEBIDOS,   |
//|         entao qualquer desalinhamento futuro aparece no log.     |
//| CORRECOES vs v3 (auditoria completa):                             |
//|  [B1] LOOKAHEAD MTF NO HISTORICO (grave): MapHTF mapeava a barra |
//|       HTF pelo tempo de ABERTURA. No historico, barras do chart  |
//|       enxergavam o valor FINAL de uma barra HTF que ainda estava |
//|       em formacao naquele instante (ex.: barra M1 10:03 lia a    |
//|       M5 10:00, cujo valor so' existiu as 10:05). Ao vivo o      |
//|       cache atrasado mascarava o problema -> backtest visual     |
//|       otimista e DIFERENTE do live. Agora o mapeamento e' por    |
//|       tempo de FECHAMENTO: barra HTF so' fica visivel para       |
//|       barras do chart abertas em t >= (open_HTF + periodo_HTF).  |
//|       Historico e live identicos, sempre.                        |
//|  [B2] LOOKAHEAD NA MEDICAO DE CICLO (grave): entrada era         |
//|       close[i-1], mas o sinal so' e' conhecido no fechamento da  |
//|       barra i. Agora entrada/saida = close[i] (equivale a abrir  |
//|       na barra seguinte) e o MFE/MAE conta APENAS barras         |
//|       pos-entrada. Labels antigos eram inflados.                 |
//|  [B3] Setas eram desenhadas em i-1 (uma barra ANTES de a         |
//|       informacao existir) — ilusao visual de antecipacao.        |
//|       Agora a seta fica na barra i, cujo fechamento confirmou    |
//|       o cruzamento.                                              |
//|  [B4] InpMaxCycleObj era declarado e IGNORADO. Agora e' aplicado |
//|       (janela rolante: label mais antigo e' apagado).            |
//|  [B5] ATR: copiava o historico inteiro a cada tick. Agora copia  |
//|       so' o trecho novo (O(1) por tick), com retry ate' o        |
//|       historico completo estar disponivel.                       |
//|  [B6] MapHTF era O(n) por tick. Agora: remapeamento completo so' |
//|       quando fecha barra HTF nova; por tick, so' as barras       |
//|       novas (busca binaria + ponteiro).                          |
//|  [B7] Validacao de inputs; falha explicita se o handle ATR nao   |
//|       for criado.                                                |
//|  [B8] Sensor desacoplado do visual: sig1/sig2 (buffers 9/10)     |
//|       sao gravados SEMPRE que a regra dispara; InpShowSig1/2     |
//|       controla apenas as setas. (Na v3, desligar a seta          |
//|       desligava o sensor do EA.)                                 |
//|                                                                   |
//| Buffer Map (INALTERADO vs v3 — compatibilidade com EA):          |
//|   0  = TMO1 Main (escalado)     1  = cor do Main                 |
//|   2  = TMO1 Signal              3  = Histograma (visual)         |
//|   4  = cor do Histograma        5/6 = setas TMO1 buy/sell        |
//|   7/8 = setas TMO2 buy/sell                                      |
//|  --- SENSORES p/ EA (ler no shift 1) ---                         |
//|   9  = Sinal TMO1 (+1 compra, -1 venda, 0) - barra fechada       |
//|  10  = Sinal TMO2 (+1/-1/0)                                      |
//|  11  = Estado TMO1 (+1 Main>Signal, -1 Main<Signal)              |
//|  12  = Estado TMO2  | 13 = Estado TMO3                           |
//|  14  = Exaustao TMO1 (+1 OB, -1 OS, 0 neutro)                    |
//|  15  = Confluencia MTF (+1 todos alta, -1 todos baixa, 0 misto)  |
//|  16  = ATR (amplitude p/ filtro de custo)                        |
//|                                                                   |
//| Obs: labels de ciclo (P&L / MFE) em unidades de PRECO do         |
//| simbolo (nao JPY). Conversao monetaria e' papel do EA/sensor.    |
//+------------------------------------------------------------------+
#property copyright   "TMO Scalper v4 | XAUUSD zero-repaint"
#property version     "4.02"
#property description "TMO MACD-style — zero repaint real (historico==live), cascade MTF, M1/M2/M5"
#property indicator_separate_window
#property indicator_buffers  30
#property indicator_plots    7

//--- Plot 0: TMO1 Main line (color-coded)
#property indicator_label1   "TMO Main"
#property indicator_type1    DRAW_COLOR_LINE
#property indicator_color1   clrLime,clrRed,clrOrange
#property indicator_style1   STYLE_SOLID
#property indicator_width1   2

//--- Plot 1: TMO1 Signal line
#property indicator_label2   "TMO Signal"
#property indicator_type2    DRAW_LINE
#property indicator_color2   clrGold
#property indicator_style2   STYLE_SOLID
#property indicator_width2   1

//--- Plot 2: Histogram
#property indicator_label3   "Histogram"
#property indicator_type3    DRAW_COLOR_HISTOGRAM
#property indicator_color3   C'0,200,0',C'220,20,60'
#property indicator_style3   STYLE_SOLID
#property indicator_width3   3

//--- Plot 3-6: Signal arrows
#property indicator_label4   "TMO1 Buy"
#property indicator_type4    DRAW_ARROW
#property indicator_color4   clrLime
#property indicator_width4   2

#property indicator_label5   "TMO1 Sell"
#property indicator_type5    DRAW_ARROW
#property indicator_color5   clrRed
#property indicator_width5   2

#property indicator_label6   "TMO2 Buy"
#property indicator_type6    DRAW_ARROW
#property indicator_color6   C'0,100,0'
#property indicator_width6   3

#property indicator_label7   "TMO2 Sell"
#property indicator_type7    DRAW_ARROW
#property indicator_color7   C'139,0,0'
#property indicator_width7   3

//+------------------------------------------------------------------+
//| Inputs                                                            |
//+------------------------------------------------------------------+
//--- Timeframes ---
input ENUM_TIMEFRAMES    InpTF2          = PERIOD_M5;   // TMO2 Timeframe
input ENUM_TIMEFRAMES    InpTF3          = PERIOD_M15;  // TMO3 Timeframe

//--- TMO Settings ---
input int                InpTMOLen       = 7;     // TMO Length
input int                InpCalcLen      = 3;     // Calc Length
input int                InpSmoothLen    = 2;     // Smooth Length

//--- Visual ---
input double             InpHistScale    = 4.0;   // Multiplicador visual do histograma (so desenho)

//--- Signals ---
input double             InpOffset       = 1.5;   // Arrow Offset
input double             InpOBLevel      = 7.0;   // OB Extreme Threshold
input double             InpOSLevel      = -7.0;  // OS Extreme Threshold
input bool               InpShowSig1     = true;  // TMO1 Arrows (visual; sensor sempre ativo)
input bool               InpSig1Extreme  = false; // TMO1 Extremes Only (regra)
input bool               InpShowSig2     = true;  // TMO2 Arrows (visual; sensor sempre ativo)
input bool               InpSig2Extreme  = false; // TMO2 Extremes Only (regra)
input bool               InpUseCascade   = false; // Require HTF Confirmation

//--- Filtro Exaustao (teste isolado) ---
input bool               InpExhaustFilter   = false; // Ligar filtro de exaustao (so viradas de OB/OS)
input int                InpExhaustLookback = 5;     // Quantas barras olhar tras p/ tocar extremo

//--- Anti-Whipsaw ---
input int                InpCooldown     = 3;     // Min Bars Between Signals (0=off)
input double             InpMinCross     = 0.1;   // Min |Main-Signal| to Qualify (0=off; escala +-15)
input bool               InpZeroFilter   = false; // Buy from below zero, Sell from above

//--- Custo (XAUUSD) ---
input int                InpATRPeriod    = 14;    // ATR p/ amplitude (filtro de custo no EA)

//--- Cycle Measurement ---
input bool               InpShowCycle    = true;  // Show P&L / MFE per cycle (visual)
input int                InpMaxCycleObj  = 60;    // Max labels de ciclo no grafico

//+------------------------------------------------------------------+
//| Buffers                                                           |
//+------------------------------------------------------------------+
double mainDispBuf[];     // 0
double mainClrBuf[];      // 1
double sigDispBuf[];      // 2
double histBuf[];         // 3
double histClrBuf[];      // 4
double tmo1BuyBuf[];      // 5
double tmo1SellBuf[];     // 6
double tmo2BuyBuf[];      // 7
double tmo2SellBuf[];     // 8
// --- leitura de sensor p/ EA ---
double sig1Buf[];         // 9  sinal TMO1 (+1/-1/0)
double sig2SigBuf[];      // 10 sinal TMO2
double state1Buf[];       // 11 estado TMO1
double state2Buf[];       // 12 estado TMO2
double state3Buf[];       // 13 estado TMO3
double exhaustBuf[];      // 14 exaustao TMO1
double confluenceBuf[];   // 15 confluencia MTF
double atrBuf[];          // 16 ATR
// --- calc internos ---
double tmo1DataBuf[];     // 17
double tmo1EMABuf[];      // 18
double tmo1MainRaw[];     // 19
double tmo1SigRaw[];      // 20
double main2Buf[];        // 21 TMO2 main (mapeado por FECHAMENTO)
double sig2Buf[];         // 22 TMO2 signal
double main3Buf[];        // 23 TMO3 main
double sig3Buf[];         // 24 TMO3 signal
double cooldownBuf[];     // 25
double cycDirBuf[];       // 26 direcao do ciclo (1/-1/0)
double cycEntryBuf[];     // 27 preco de entrada do ciclo (close da barra de sinal)
double cycHighBuf[];      // 28 high corrente do ciclo (pos-entrada)
double cycLowBuf[];       // 29 low corrente do ciclo (pos-entrada)

double   g_scale;
int      g_hATR   = INVALID_HANDLE;
bool     g_atrOK  = false;   // historico completo do ATR ja' copiado?
datetime g_lastHTF2 = 0;     // ultima barra HTF2 processada
datetime g_lastHTF3 = 0;
// cache dos arrays HTF (raw, so' barras FECHADAS, cronologico)
double   g_m2raw[], g_s2raw[]; datetime g_t2[];
double   g_m3raw[], g_s3raw[]; datetime g_t3[];
int      g_n2 = 0, g_n3 = 0;
long     g_cycId  = 0;       // id sequencial dos labels de ciclo
int      g_subwin = -1;      // cache da subjanela do indicador

//+------------------------------------------------------------------+
double EMAstep(double src, double prev, int period)
{
   double a = 2.0 / (period + 1.0);
   return a * src + (1.0 - a) * prev;
}

//+------------------------------------------------------------------+
//| Recalcula o TMO de um HTF a partir de barras FECHADAS (shift 1). |
//| Guarda em arrays raw cronologicos (0 = mais antiga). So chamado  |
//| quando uma barra HTF nova fecha. Nunca inclui o shift 0.         |
//+------------------------------------------------------------------+
bool RecalcHTF(ENUM_TIMEFRAMES tf, double &mraw[], double &sraw[],
               datetime &traw[], int &nOut)
{
   int htfBars = Bars(_Symbol, tf);
   int need = InpTMOLen + InpCalcLen + InpSmoothLen + 10;
   if(htfBars < need) return false;

   // copiar a partir do shift 1 (exclui a barra HTF em formacao)
   int cnt = htfBars - 1;
   double o[], c[]; datetime t[];
   int co = CopyOpen(_Symbol, tf, 1, cnt, o);
   int cc = CopyClose(_Symbol, tf, 1, cnt, c);
   int ct = CopyTime(_Symbol, tf, 1, cnt, t);
   int mc = MathMin(co, MathMin(cc, ct));
   if(mc <= 0) return false;

   // Copy* com shift retorna series (0 = mais recente fechada).
   // Reordenar para cronologico para a recorrencia EMA.
   ArraySetAsSeries(o, false);
   ArraySetAsSeries(c, false);
   ArraySetAsSeries(t, false);

   ArrayResize(mraw, mc); ArrayResize(sraw, mc); ArrayResize(traw, mc);
   double data, ema1, mainR, sigR;
   double pema1 = 0, pmain = 0, psig = 0;
   for(int j = 0; j < mc; j++)
   {
      int d = 0;
      for(int k = 1; k < InpTMOLen && j - k >= 0; k++)
      {
         if(c[j] > o[j - k]) d++;
         if(c[j] < o[j - k]) d--;
      }
      data  = d;
      ema1  = (j == 0) ? data  : EMAstep(data,  pema1, InpCalcLen);
      mainR = (j == 0) ? ema1  : EMAstep(ema1,  pmain, InpSmoothLen);
      sigR  = (j == 0) ? mainR : EMAstep(mainR, psig,  InpSmoothLen);
      pema1 = ema1; pmain = mainR; psig = sigR;
      mraw[j] = mainR * g_scale;
      sraw[j] = sigR  * g_scale;
      traw[j] = t[j];
   }
   nOut = mc;
   return true;
}

//+------------------------------------------------------------------+
//| Mapeia arrays HTF raw -> barras do chart, no intervalo [from,to).|
//| REGRA [B1]: barra HTF (open=traw[h]) so' fica visivel para       |
//| barras do chart cujo open >= traw[h] + periodo_HTF, ou seja,     |
//| APOS o fechamento real da barra HTF. Identico em historico e     |
//| live. Antes de qualquer HTF fechada: 0 (estado neutro).          |
//+------------------------------------------------------------------+
void MapHTFRange(const double &mraw[], const double &sraw[],
                 const datetime &traw[], int n, int tfSec,
                 const datetime &ctime[], int from, int to,
                 double &mout[], double &sout[])
{
   if(from >= to) return;
   if(n <= 0)
   {
      for(int i = from; i < to; i++) { mout[i] = 0.0; sout[i] = 0.0; }
      return;
   }
   // busca binaria: maior h com traw[h] + tfSec <= ctime[from]
   int lo = 0, hi = n - 1, h = -1;
   while(lo <= hi)
   {
      int mid = (lo + hi) / 2;
      if(traw[mid] + tfSec <= ctime[from]) { h = mid; lo = mid + 1; }
      else hi = mid - 1;
   }
   for(int i = from; i < to; i++)
   {
      while(h < n - 1 && traw[h + 1] + tfSec <= ctime[i]) h++;
      if(h < 0) { mout[i] = 0.0; sout[i] = 0.0; }
      else      { mout[i] = mraw[h]; sout[i] = sraw[h]; }
   }
}

//+------------------------------------------------------------------+
//| Label de ciclo (P&L / MFE) com limite rolante [B4].              |
//+------------------------------------------------------------------+
void DrawCycleLabel(datetime t, double y, bool below, double pnl, double mfe)
{
   if(g_subwin < 0) g_subwin = ChartWindowFind();
   g_cycId++;
   string name = "SBURN_TMO_CYC_" + IntegerToString(g_cycId);
   ObjectCreate(0, name, OBJ_TEXT, g_subwin, t, y);
   ObjectSetString (0, name, OBJPROP_TEXT,
                    DoubleToString(pnl, 1) + " / " + DoubleToString(mfe, 1));
   ObjectSetInteger(0, name, OBJPROP_COLOR, pnl >= 0 ? clrLime : clrOrangeRed);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
   ObjectSetString (0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, below ? ANCHOR_LEFT_LOWER : ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   long old = g_cycId - (long)InpMaxCycleObj;
   if(old > 0) ObjectDelete(0, "SBURN_TMO_CYC_" + IntegerToString(old));
}

//+------------------------------------------------------------------+
int OnInit()
{
   // [B7] validacao de parametros
   if(InpTMOLen < 2 || InpCalcLen < 1 || InpSmoothLen < 1 ||
      InpATRPeriod < 1 || InpMaxCycleObj < 1)
   {
      Print("TMO Scalper v4: parametros invalidos (TMOLen>=2, CalcLen>=1, SmoothLen>=1, ATR>=1, MaxCycleObj>=1)");
      return INIT_PARAMETERS_INCORRECT;
   }

   // --- buffers de PLOT (DATA/COLOR) primeiro ---
   SetIndexBuffer(0,  mainDispBuf,   INDICATOR_DATA);
   SetIndexBuffer(1,  mainClrBuf,    INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2,  sigDispBuf,    INDICATOR_DATA);
   SetIndexBuffer(3,  histBuf,       INDICATOR_DATA);
   SetIndexBuffer(4,  histClrBuf,    INDICATOR_COLOR_INDEX);
   SetIndexBuffer(5,  tmo1BuyBuf,    INDICATOR_DATA);
   SetIndexBuffer(6,  tmo1SellBuf,   INDICATOR_DATA);
   SetIndexBuffer(7,  tmo2BuyBuf,    INDICATOR_DATA);
   SetIndexBuffer(8,  tmo2SellBuf,   INDICATOR_DATA);
   // --- buffers de CALCULO/leitura de sensor ---
   SetIndexBuffer(9,  sig1Buf,       INDICATOR_CALCULATIONS);
   SetIndexBuffer(10, sig2SigBuf,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(11, state1Buf,     INDICATOR_CALCULATIONS);
   SetIndexBuffer(12, state2Buf,     INDICATOR_CALCULATIONS);
   SetIndexBuffer(13, state3Buf,     INDICATOR_CALCULATIONS);
   SetIndexBuffer(14, exhaustBuf,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(15, confluenceBuf, INDICATOR_CALCULATIONS);
   SetIndexBuffer(16, atrBuf,        INDICATOR_CALCULATIONS);
   SetIndexBuffer(17, tmo1DataBuf,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(18, tmo1EMABuf,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(19, tmo1MainRaw,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(20, tmo1SigRaw,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(21, main2Buf,      INDICATOR_CALCULATIONS);
   SetIndexBuffer(22, sig2Buf,       INDICATOR_CALCULATIONS);
   SetIndexBuffer(23, main3Buf,      INDICATOR_CALCULATIONS);
   SetIndexBuffer(24, sig3Buf,       INDICATOR_CALCULATIONS);
   SetIndexBuffer(25, cooldownBuf,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(26, cycDirBuf,     INDICATOR_CALCULATIONS);
   SetIndexBuffer(27, cycEntryBuf,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(28, cycHighBuf,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(29, cycLowBuf,     INDICATOR_CALCULATIONS);

   PlotIndexSetInteger(3, PLOT_ARROW, 233);
   PlotIndexSetInteger(4, PLOT_ARROW, 234);
   PlotIndexSetInteger(5, PLOT_ARROW, 233);
   PlotIndexSetInteger(6, PLOT_ARROW, 234);

   for(int p = 0; p < 7; p++)
      PlotIndexSetDouble(p, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   IndicatorSetInteger(INDICATOR_LEVELS, 7);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 15);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, 10);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, 7);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 3, 0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 4, -7);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 5, -10);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 6, -15);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, clrFireBrick);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 1, C'60,0,0');
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 2, clrOrange);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 3, clrDimGray);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 4, clrOrange);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 5, C'0,60,0');
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 6, clrDarkGreen);
   for(int l = 0; l < 7; l++)
      IndicatorSetInteger(INDICATOR_LEVELSTYLE, l, (l == 2 || l == 4) ? STYLE_DASH : STYLE_DOT);

   g_scale = 15.0 / InpTMOLen;

   // [B7] falha explicita se o ATR nao criar
   g_hATR = iATR(_Symbol, _Period, InpATRPeriod);
   if(g_hATR == INVALID_HANDLE)
   {
      Print("TMO Scalper v4: falha ao criar handle do ATR");
      return INIT_FAILED;
   }

   g_atrOK  = false;
   g_cycId  = 0;
   g_subwin = -1;

   IndicatorSetString(INDICATOR_SHORTNAME,
      StringFormat("S-Ind-TMO_Scalper v4(%d,%d,%d)", InpTMOLen, InpCalcLen, InpSmoothLen));
   // assinatura de identidade + ECO dos parametros RECEBIDOS:
   // prova no log QUAL codigo roda e COM QUAIS valores (anti-desalinhamento)
   Print("S-Ind-TMO_Scalper v4.02 (SBurn) inicializado | TF2=",
         EnumToString(InpTF2), " TF3=", EnumToString(InpTF3),
         " TMOLen=", InpTMOLen, " Calc=", InpCalcLen,
         " Smooth=", InpSmoothLen, " Cooldown=", InpCooldown,
         " Exhaust=", (InpExhaustFilter ? "ON" : "OFF"),
         " Cascade=", (InpUseCascade ? "ON" : "OFF"));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "SBURN_TMO_CYC_");
   if(g_hATR != INVALID_HANDLE) IndicatorRelease(g_hATR);
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   int needed = InpTMOLen + InpCalcLen + InpSmoothLen + 5;
   if(rates_total < needed) return 0;

   int  start;
   bool fullRemap = false;
   if(prev_calculated == 0)
   {
      start = 0;
      ArrayInitialize(tmo1BuyBuf,  EMPTY_VALUE);
      ArrayInitialize(tmo1SellBuf, EMPTY_VALUE);
      ArrayInitialize(tmo2BuyBuf,  EMPTY_VALUE);
      ArrayInitialize(tmo2SellBuf, EMPTY_VALUE);
      ArrayInitialize(tmo1DataBuf, 0);
      ArrayInitialize(tmo1EMABuf, 0);
      ArrayInitialize(tmo1MainRaw, 0);
      ArrayInitialize(tmo1SigRaw, 0);
      ArrayInitialize(histBuf, 0);
      ArrayInitialize(cooldownBuf, 9999);
      ArrayInitialize(sig1Buf, 0);
      ArrayInitialize(sig2SigBuf, 0);
      ArrayInitialize(exhaustBuf, 0);
      ArrayInitialize(confluenceBuf, 0);
      ArrayInitialize(atrBuf, 0);
      ArrayInitialize(cycDirBuf, 0);
      ArrayInitialize(cycEntryBuf, 0);
      ArrayInitialize(cycHighBuf, 0);
      ArrayInitialize(cycLowBuf, 0);
      ObjectsDeleteAll(0, "SBURN_TMO_CYC_");
      g_lastHTF2 = 0; g_lastHTF3 = 0;
      g_atrOK = false;
      g_cycId = 0;
      fullRemap = true;
   }
   else
      start = prev_calculated - 1;

   //=== ATR (leitura p/ EA) — copia incremental [B5] ===
   {
      int cnt = g_atrOK ? (rates_total - start) : rates_total;
      double atrTmp[];
      ArraySetAsSeries(atrTmp, true);
      int c = CopyBuffer(g_hATR, 0, 0, cnt, atrTmp);
      if(c > 0)
      {
         for(int p = 0; p < c; p++)
            atrBuf[rates_total - 1 - p] = atrTmp[p];
         if(!g_atrOK && c >= cnt) g_atrOK = true; // historico completo carregado
      }
   }

   //=== HTF: recalcula SO quando fecha barra HTF nova (ou 1a carga) ===
   datetime cur2 = (datetime)SeriesInfoInteger(_Symbol, InpTF2, SERIES_LASTBAR_DATE);
   if(cur2 > 0 && (cur2 != g_lastHTF2 || g_n2 == 0))
   {
      if(RecalcHTF(InpTF2, g_m2raw, g_s2raw, g_t2, g_n2))
      { g_lastHTF2 = cur2; fullRemap = true; }
   }
   datetime cur3 = (datetime)SeriesInfoInteger(_Symbol, InpTF3, SERIES_LASTBAR_DATE);
   if(cur3 > 0 && (cur3 != g_lastHTF3 || g_n3 == 0))
   {
      if(RecalcHTF(InpTF3, g_m3raw, g_s3raw, g_t3, g_n3))
      { g_lastHTF3 = cur3; fullRemap = true; }
   }

   // [B6] remapeia tudo apenas quando ha' HTF nova; senao so' barras novas
   int mapFrom = fullRemap ? 0 : start;
   MapHTFRange(g_m2raw, g_s2raw, g_t2, g_n2, PeriodSeconds(InpTF2),
               time, mapFrom, rates_total, main2Buf, sig2Buf);
   MapHTFRange(g_m3raw, g_s3raw, g_t3, g_n3, PeriodSeconds(InpTF3),
               time, mapFrom, rates_total, main3Buf, sig3Buf);

   //=== TMO1 no chart + visuais + sinais ===
   for(int i = start; i < rates_total; i++)
   {
      int d = 0;
      for(int k = 1; k < InpTMOLen && i - k >= 0; k++)
      {
         if(close[i] > open[i - k]) d++;
         if(close[i] < open[i - k]) d--;
      }
      tmo1DataBuf[i] = d;

      tmo1EMABuf[i]  = (i == 0) ? d              : EMAstep(d,              tmo1EMABuf[i-1],  InpCalcLen);
      tmo1MainRaw[i] = (i == 0) ? tmo1EMABuf[i]  : EMAstep(tmo1EMABuf[i],  tmo1MainRaw[i-1], InpSmoothLen);
      tmo1SigRaw[i]  = (i == 0) ? tmo1MainRaw[i] : EMAstep(tmo1MainRaw[i], tmo1SigRaw[i-1],  InpSmoothLen);

      double m1 = tmo1MainRaw[i] * g_scale;
      double s1 = tmo1SigRaw[i]  * g_scale;
      mainDispBuf[i] = m1;
      sigDispBuf[i]  = s1;

      if(m1 > InpOBLevel || m1 < InpOSLevel) mainClrBuf[i] = 2;
      else mainClrBuf[i] = (m1 > s1) ? 0 : 1;

      double hist = m1 - s1;
      // histBuf e' VISUAL: multiplicador so' amplia o desenho.
      histBuf[i]    = hist * InpHistScale;
      histClrBuf[i] = (hist >= 0) ? 0 : 1;

      // --- sensores de estado (barra i) ---
      state1Buf[i]  = (m1 > s1) ? +1 : (m1 < s1) ? -1 : 0;
      state2Buf[i]  = (main2Buf[i] > sig2Buf[i]) ? +1 : (main2Buf[i] < sig2Buf[i]) ? -1 : 0;
      state3Buf[i]  = (main3Buf[i] > sig3Buf[i]) ? +1 : (main3Buf[i] < sig3Buf[i]) ? -1 : 0;
      exhaustBuf[i] = (m1 > InpOBLevel) ? +1 : (m1 < InpOSLevel) ? -1 : 0;
      if(state1Buf[i] > 0 && state2Buf[i] > 0 && state3Buf[i] > 0)      confluenceBuf[i] = +1;
      else if(state1Buf[i] < 0 && state2Buf[i] < 0 && state3Buf[i] < 0) confluenceBuf[i] = -1;
      else confluenceBuf[i] = 0;

      // limpar marcadores/sinais da propria barra i
      tmo1BuyBuf[i]  = EMPTY_VALUE;
      tmo1SellBuf[i] = EMPTY_VALUE;
      tmo2BuyBuf[i]  = EMPTY_VALUE;
      tmo2SellBuf[i] = EMPTY_VALUE;
      sig1Buf[i]    = 0;
      sig2SigBuf[i] = 0;

      if(i < 2) { cooldownBuf[i] = 9999; continue; }

      // ============================================================
      // ZERO REPAINT: sinal so' em barra FECHADA (i < rates_total-1).
      // A barra em formacao nunca gera sinal; cada barra fechada e'
      // avaliada exatamente uma vez.
      // ============================================================
      bool barClosed = (i < rates_total - 1);

      int prevCooldown = (int)cooldownBuf[i-1];
      int curCooldown  = prevCooldown + 1;

      if(barClosed)
      {
         double m1p = mainDispBuf[i-1], s1p = sigDispBuf[i-1];
         double m2  = main2Buf[i],      s2  = sig2Buf[i];
         double m2p = main2Buf[i-1],    s2p = sig2Buf[i-1];
         double m3  = main3Buf[i],      s3  = sig3Buf[i];

         bool tmo1Up = (m1 > s1) && (m1p <= s1p);
         bool tmo1Dn = (m1 < s1) && (m1p >= s1p);
         bool tmo2Up = (m2 > s2) && (m2p <= s2p);
         bool tmo2Dn = (m2 < s2) && (m2p >= s2p);

         bool cooldownOK  = (InpCooldown <= 0) || (prevCooldown >= InpCooldown);
         bool crossDistOK = (InpMinCross <= 0) || (MathAbs(m1 - s1) >= InpMinCross);
         bool zeroOK_buy  = !InpZeroFilter || (m1p < 0);
         bool zeroOK_sell = !InpZeroFilter || (m1p > 0);

         // --- filtro de exaustao: tocou OB/OS nas ultimas N barras? ---
         bool cameFromOS = !InpExhaustFilter;  // filtro off => sempre passa
         bool cameFromOB = !InpExhaustFilter;
         if(InpExhaustFilter)
         {
            int lb = InpExhaustLookback;
            for(int b = 1; b <= lb && (i - b) >= 0; b++)
            {
               if(mainDispBuf[i-b] <= InpOSLevel) cameFromOS = true;
               if(mainDispBuf[i-b] >= InpOBLevel) cameFromOB = true;
            }
         }

         // --- TMO1: regra sempre avaliada (sensor); seta so' visual [B8] ---
         if(!InpSig1Extreme)
         {
            bool t2bull = !InpUseCascade || (m2 > s2);
            bool t2bear = !InpUseCascade || (m2 < s2);
            if(tmo1Up && t2bull && cooldownOK && crossDistOK && zeroOK_buy && cameFromOS)
            {
               sig1Buf[i] = +1; curCooldown = 0;
               if(InpShowSig1) tmo1BuyBuf[i] = m1 - InpOffset;   // [B3] seta na barra do sinal
            }
            if(tmo1Dn && t2bear && cooldownOK && crossDistOK && zeroOK_sell && cameFromOB)
            {
               sig1Buf[i] = -1; curCooldown = 0;
               if(InpShowSig1) tmo1SellBuf[i] = m1 + InpOffset;
            }
         }
         else // Extremes Only
         {
            bool t2bull = !InpUseCascade || (m2 > s2);
            bool t2bear = !InpUseCascade || (m2 < s2);
            if(tmo1Up && m1 < InpOSLevel && t2bull && cooldownOK && crossDistOK)
            {
               sig1Buf[i] = +1; curCooldown = 0;
               if(InpShowSig1) tmo1BuyBuf[i] = m1 - InpOffset;
            }
            if(tmo1Dn && m1 > InpOBLevel && t2bear && cooldownOK && crossDistOK)
            {
               sig1Buf[i] = -1; curCooldown = 0;
               if(InpShowSig1) tmo1SellBuf[i] = m1 + InpOffset;
            }
         }

         // --- TMO2: idem [B8] ---
         if(!InpSig2Extreme)
         {
            bool t3bull = !InpUseCascade || (m3 > s3);
            bool t3bear = !InpUseCascade || (m3 < s3);
            if(tmo2Up && t3bull && cooldownOK)
            {
               sig2SigBuf[i] = +1;
               if(InpShowSig2) tmo2BuyBuf[i] = m2 - InpOffset;
            }
            if(tmo2Dn && t3bear && cooldownOK)
            {
               sig2SigBuf[i] = -1;
               if(InpShowSig2) tmo2SellBuf[i] = m2 + InpOffset;
            }
         }
         else
         {
            bool t3bull = !InpUseCascade || (m3 > s3);
            bool t3bear = !InpUseCascade || (m3 < s3);
            if(tmo2Up && m2 < InpOSLevel && t3bull && cooldownOK)
            {
               sig2SigBuf[i] = +1;
               if(InpShowSig2) tmo2BuyBuf[i] = m2 - InpOffset;
            }
            if(tmo2Dn && m2 > InpOBLevel && t3bear && cooldownOK)
            {
               sig2SigBuf[i] = -1;
               if(InpShowSig2) tmo2SellBuf[i] = m2 + InpOffset;
            }
         }

         //=== Medicao de ciclo (P&L/MFE) — SEM lookahead [B2] ===
         // Entrada = close[i] da barra de sinal (equivale a abrir na
         // abertura da barra seguinte). MFE/MAE acumula so' barras
         // pos-entrada. Fechamento do ciclo = close[i] do novo sinal.
         double prevDir   = cycDirBuf[i-1];
         double prevEntry = cycEntryBuf[i-1];
         double prevHigh  = cycHighBuf[i-1];
         double prevLow   = cycLowBuf[i-1];

         double curDir   = prevDir;
         double curEntry = prevEntry;
         double curHigh  = (prevHigh > 0) ? MathMax(prevHigh, high[i]) : high[i];
         double curLow   = (prevLow  > 0) ? MathMin(prevLow,  low[i])  : low[i];

         bool newBuy  = (sig1Buf[i] > 0);
         bool newSell = (sig1Buf[i] < 0);

         if(newBuy || newSell)
         {
            if(InpShowCycle && prevDir != 0.0 && prevEntry > 0)
            {
               double pnl, mfe;
               if(prevDir > 0) { pnl = close[i] - prevEntry; mfe = curHigh - prevEntry; }
               else            { pnl = prevEntry - close[i]; mfe = prevEntry - curLow;  }
               double y = newSell ? (m1 + InpOffset + 1.5) : (m1 - InpOffset - 1.5);
               DrawCycleLabel(time[i], y, newSell, pnl, mfe);
            }
            curDir   = newBuy ? 1 : -1;
            curEntry = close[i];
            curHigh  = close[i];   // range da propria barra de sinal NAO conta
            curLow   = close[i];
         }
         cycDirBuf[i]   = curDir;
         cycEntryBuf[i] = curEntry;
         cycHighBuf[i]  = curHigh;
         cycLowBuf[i]   = curLow;
      }
      else
      {
         // barra viva: propaga estado do ciclo sem alterar
         cycDirBuf[i]   = cycDirBuf[i-1];
         cycEntryBuf[i] = cycEntryBuf[i-1];
         cycHighBuf[i]  = cycHighBuf[i-1];
         cycLowBuf[i]   = cycLowBuf[i-1];
      }

      cooldownBuf[i] = curCooldown;
   }

   return rates_total;
}
//+------------------------------------------------------------------+
