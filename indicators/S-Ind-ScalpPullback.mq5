//+------------------------------------------------------------------+
//| >>> INSTALACAO (LEIA PRIMEIRO) <<<                                |
//| PASTA:    <PastaDeDados>\MQL5\Indicators\SBurn\          |
//| ARQUIVO:  S-Ind-ScalpPullback.mq5                                |
//| COMPILAR: SIM (F7) -> gera S-Ind-ScalpPullback.ex5               |
//| ASSINATURA no log ao iniciar (prova de identidade):               |
//|   "S-Ind-ScalpPullback v2.02 (SBurn) inicializado"                |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| S-Ind-ScalpPullback.mq5                                           |
//| Port of "Scalping PullBack Tool R1.1 by JustUncleL" from TV      |
//| v2.00 — zero-repaint real + sensores p/ EA                       |
//+------------------------------------------------------------------+
//| v2.02 - [B4] SENSOR ACOPLADO AO VISUAL (mesma classe do B8 do    |
//|        TMO): os buffers 8/9 (fractais) e 10-13 (HH/LH/HL/LL) so'  |
//|        eram gravados se InpShowFractals / InpShowHHLL estivessem  |
//|        ligados. Um EA que consome esses buffers via iCustom       |
//|        receberia EMPTY_VALUE se o usuario desligasse o desenho —  |
//|        falha silenciosa. Agora os buffers sao SEMPRE gravados e   |
//|        a visibilidade e' controlada por PLOT_DRAW_TYPE no OnInit, |
//|        igual ao que ja' era feito com as EMAs.                    |
//|                                                                    |
//| CORRECOES vs 1.10 (auditoria):                                    |
//|  [B1] Fractais, HH/LL e sinais eram avaliados TAMBEM na barra    |
//|       viva, a cada tick. Consequencias reais:                    |
//|       - setas de fractal fantasma: fractal marcado em i-2 com    |
//|         high[i] ainda incompleto e nunca apagado quando a        |
//|         condicao deixava de valer;                               |
//|       - estado valuewhen (g_topVW/g_botVW) corrompido: o mesmo   |
//|         fractal era empurrado repetidamente a cada tick,         |
//|         destruindo o historico de HH/LH/HL/LL;                   |
//|       - setas Buy/Sell que apareciam e sumiam na barra viva      |
//|         (repaint classico).                                      |
//|       Agora TODA logica de evento roda apenas em barra FECHADA;  |
//|       cada barra fechada e' processada exatamente uma vez, o     |
//|       que tambem torna os globals de valuewhen deterministicos. |
//|  [B2] InpDelayArrow era declarado e IGNORADO. Removido: o        |
//|       comportamento agora e' sempre "somente barra fechada"      |
//|       (doutrina zero-repaint; indicador e' sensor p/ EA).        |
//|  [B3] Sensores p/ EA ACRESCENTADOS ao final (mapa 0..25          |
//|       inalterado -> compatibilidade com iCustom existente):      |
//|       26 = Sinal (+1 compra / -1 venda / 0) na barra fechada     |
//|       27 = TrendDir (+1 alta / -1 baixa / 0 neutro)              |
//|       O sinal (26) e' gravado SEMPRE que a transicao ocorre;     |
//|       InpShowBuySell controla apenas a seta visual.              |
//|                                                                   |
//| Buffer Map (for EA via iCustom — ler no shift 1):                 |
//|  0  = PAC Upper (fill)    8  = Fractal Top                       |
//|  1  = PAC Lower (fill)    9  = Fractal Bottom                    |
//|  2  = PAC Center          10 = HH marker                         |
//|  3  = Fast EMA            11 = LH marker                         |
//|  4  = Medium EMA          12 = HL marker                         |
//|  5  = Slow EMA            13 = LL marker                         |
//|  6  = BUY arrow           14-18 = Color candles (OHLC+clr)       |
//|  7  = SELL arrow          19-22 = HA calc  23-25 = state         |
//|  26 = Sinal (+1/-1/0)     27 = TrendDir (+1/-1/0)                |
//+------------------------------------------------------------------+
#property copyright   "Port of JustUncleL | MT5 v2 zero-repaint"
#property version     "2.02"
#property description "Scalping Pullback Tool — PAC + EMA Ribbon + Fractals + Arrows (closed-bar only)"
#property indicator_chart_window
#property indicator_buffers  28
#property indicator_plots    14

//--- Plot 0: PAC fill
#property indicator_label1   "PAC Upper;PAC Lower"
#property indicator_type1    DRAW_FILLING
#property indicator_color1   clrSilver,clrSilver
//--- Plot 1: PAC center
#property indicator_label2   "PAC Close"
#property indicator_type2    DRAW_LINE
#property indicator_color2   clrRed
#property indicator_width2   2
//--- Plot 2-4: EMA ribbon
#property indicator_label3   "Fast EMA"
#property indicator_type3    DRAW_LINE
#property indicator_color3   clrGreen
#property indicator_width3   2
#property indicator_label4   "Medium EMA"
#property indicator_type4    DRAW_LINE
#property indicator_color4   clrBlue
#property indicator_width4   3
#property indicator_label5   "Slow EMA"
#property indicator_type5    DRAW_LINE
#property indicator_color5   clrBlack
#property indicator_width5   4
//--- Plot 5-6: Buy/Sell
#property indicator_label6   "Buy"
#property indicator_type6    DRAW_ARROW
#property indicator_color6   clrGreen
#property indicator_width6   3
#property indicator_label7   "Sell"
#property indicator_type7    DRAW_ARROW
#property indicator_color7   clrMaroon
#property indicator_width7   3
//--- Plot 7-8: Fractals
#property indicator_label8   "Fractal Top"
#property indicator_type8    DRAW_ARROW
#property indicator_color8   clrRed
#property indicator_width8   1
#property indicator_label9   "Fractal Bot"
#property indicator_type9    DRAW_ARROW
#property indicator_color9   clrLime
#property indicator_width9   1
//--- Plot 9-12: HH/LH/HL/LL
#property indicator_label10  "HH"
#property indicator_type10   DRAW_ARROW
#property indicator_color10  clrMaroon
#property indicator_width10  1
#property indicator_label11  "LH"
#property indicator_type11   DRAW_ARROW
#property indicator_color11  clrMaroon
#property indicator_width11  1
#property indicator_label12  "HL"
#property indicator_type12   DRAW_ARROW
#property indicator_color12  clrGreen
#property indicator_width12  1
#property indicator_label13  "LL"
#property indicator_type13   DRAW_ARROW
#property indicator_color13  clrGreen
#property indicator_width13  1
//--- Plot 13: Colored candles
#property indicator_label14  "Open;High;Low;Close"
#property indicator_type14   DRAW_COLOR_CANDLES
#property indicator_color14  clrDodgerBlue,clrRed,clrGray
#property indicator_width14  1

//+------------------------------------------------------------------+
//| Inputs                                                            |
//+------------------------------------------------------------------+
input int    InpHiLoLen       = 34;    // PAC Channel EMA Length
input int    InpFastEMA       = 89;    // Fast EMA
input int    InpMediumEMA     = 200;   // Medium EMA
input int    InpSlowEMA       = 600;   // Slow EMA
input bool   InpShowFastEMA   = true;  // Show Fast EMA
input bool   InpShowMediumEMA = true;  // Show Medium EMA
input bool   InpShowSlowEMA   = false; // Show Slow EMA
input bool   InpShowFractals  = true;  // Show Fractals
input bool   InpFilterBW      = false; // Ideal Fractals Only (strict)
input bool   InpShowHHLL      = false; // Show HH/LH/HL/LL
input bool   InpShowBarColor  = true;  // Show Colored Candles
input bool   InpShowBuySell   = true;  // Show Buy/Sell Arrows (sensor sempre ativo)
input int    InpLookback      = 3;     // Pullback Lookback for PAC Cross
input bool   InpUseHA         = true;  // Use Heikin Ashi in Calculations
// [B2] InpDelayArrow removido: comportamento e' SEMPRE barra fechada.

//+------------------------------------------------------------------+
//| Buffers                                                           |
//+------------------------------------------------------------------+
// Plot buffers (0-18)
double pacUBuf[], pacLBuf[], pacCBuf[];            // 0-2
double fastBuf[], medBuf[], slowBuf[];             // 3-5
double buyBuf[], sellBuf[];                        // 6-7
double fracTopBuf[], fracBotBuf[];                 // 8-9
double hhBuf[], lhBuf[], hlBuf[], llBuf[];         // 10-13
double candleO[], candleH[], candleL[], candleC[]; // 14-17
double candleClr[];                                // 18
// HA calculation buffers (19-22)
double haClBuf[], haOpBuf[], haHiBuf[], haLoBuf[];
// State buffers (23-25) — leitura deterministica em reprocessamento
double stateTradeDirBuf[];  // 23: trade direction state per bar
double stateBsBelowBuf[];   // 24: barssince(haClose < pacC) per bar
double stateBsAboveBuf[];   // 25: barssince(haClose > pacC) per bar
// Sensores p/ EA (26-27) [B3]
double sigBuf[];            // 26: +1 compra / -1 venda / 0 (barra fechada)
double trendBuf[];          // 27: trendDir (+1/-1/0)

//+------------------------------------------------------------------+
//| Estado valuewhen dos fractais (HH/LH/HL/LL).                      |
//| Seguro como global porque, com o gate de barra fechada [B1],     |
//| cada barra fechada e' processada EXATAMENTE uma vez, em ordem    |
//| cronologica, e prev_calculated==0 reinicializa tudo.             |
//+------------------------------------------------------------------+
double g_topVW[3], g_botVW[3];

//+------------------------------------------------------------------+
//| EMA step                                                          |
//+------------------------------------------------------------------+
double EMAstep(double src, double prev, int period)
{
   double alpha = 2.0 / (period + 1.0);
   return alpha * src + (1.0 - alpha) * prev;
}

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   if(InpHiLoLen < 1 || InpFastEMA < 1 || InpMediumEMA < 1 ||
      InpSlowEMA < 1 || InpLookback < 1)
   {
      Print("ScalpPullback v2: parametros invalidos (todos os periodos >= 1)");
      return INIT_PARAMETERS_INCORRECT;
   }

   SetIndexBuffer(0,  pacUBuf,    INDICATOR_DATA);
   SetIndexBuffer(1,  pacLBuf,    INDICATOR_DATA);
   SetIndexBuffer(2,  pacCBuf,    INDICATOR_DATA);
   SetIndexBuffer(3,  fastBuf,    INDICATOR_DATA);
   SetIndexBuffer(4,  medBuf,     INDICATOR_DATA);
   SetIndexBuffer(5,  slowBuf,    INDICATOR_DATA);
   SetIndexBuffer(6,  buyBuf,     INDICATOR_DATA);
   SetIndexBuffer(7,  sellBuf,    INDICATOR_DATA);
   SetIndexBuffer(8,  fracTopBuf, INDICATOR_DATA);
   SetIndexBuffer(9,  fracBotBuf, INDICATOR_DATA);
   SetIndexBuffer(10, hhBuf,      INDICATOR_DATA);
   SetIndexBuffer(11, lhBuf,      INDICATOR_DATA);
   SetIndexBuffer(12, hlBuf,      INDICATOR_DATA);
   SetIndexBuffer(13, llBuf,      INDICATOR_DATA);
   SetIndexBuffer(14, candleO,    INDICATOR_DATA);
   SetIndexBuffer(15, candleH,    INDICATOR_DATA);
   SetIndexBuffer(16, candleL,    INDICATOR_DATA);
   SetIndexBuffer(17, candleC,    INDICATOR_DATA);
   SetIndexBuffer(18, candleClr,  INDICATOR_COLOR_INDEX);
   SetIndexBuffer(19, haClBuf,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(20, haOpBuf,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(21, haHiBuf,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(22, haLoBuf,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(23, stateTradeDirBuf, INDICATOR_CALCULATIONS);
   SetIndexBuffer(24, stateBsBelowBuf,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(25, stateBsAboveBuf,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(26, sigBuf,     INDICATOR_CALCULATIONS);
   SetIndexBuffer(27, trendBuf,   INDICATOR_CALCULATIONS);

   //--- arrow codes
   PlotIndexSetInteger(5, PLOT_ARROW, 233);   // Buy up
   PlotIndexSetInteger(6, PLOT_ARROW, 234);   // Sell down
   PlotIndexSetInteger(7, PLOT_ARROW, 234);   // Fractal top
   PlotIndexSetInteger(8, PLOT_ARROW, 233);   // Fractal bot
   PlotIndexSetInteger(9, PLOT_ARROW, 110);   // HH
   PlotIndexSetInteger(10, PLOT_ARROW, 110);  // LH
   PlotIndexSetInteger(11, PLOT_ARROW, 110);  // HL
   PlotIndexSetInteger(12, PLOT_ARROW, 110);  // LL

   //--- arrow shifts
   PlotIndexSetInteger(5, PLOT_ARROW_SHIFT, 20);
   PlotIndexSetInteger(6, PLOT_ARROW_SHIFT, -20);
   PlotIndexSetInteger(7, PLOT_ARROW_SHIFT, -15);
   PlotIndexSetInteger(8, PLOT_ARROW_SHIFT, 15);
   PlotIndexSetInteger(9, PLOT_ARROW_SHIFT, -25);
   PlotIndexSetInteger(10, PLOT_ARROW_SHIFT, -25);
   PlotIndexSetInteger(11, PLOT_ARROW_SHIFT, 25);
   PlotIndexSetInteger(12, PLOT_ARROW_SHIFT, 25);

   for(int p = 0; p < 14; p++)
      PlotIndexSetDouble(p, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   //--- EMA/candle visibility
   if(!InpShowFastEMA)   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);
   if(!InpShowMediumEMA) PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_NONE);
   if(!InpShowSlowEMA)   PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_NONE);
   if(!InpShowBarColor)  PlotIndexSetInteger(13, PLOT_DRAW_TYPE, DRAW_NONE);
   // [B4] fractais e HH/LL: buffers sempre calculados, so' o desenho e' opcional
   if(!InpShowFractals)
   { PlotIndexSetInteger(7, PLOT_DRAW_TYPE, DRAW_NONE);
     PlotIndexSetInteger(8, PLOT_DRAW_TYPE, DRAW_NONE); }
   if(!InpShowHHLL)
   { for(int q = 9; q <= 12; q++) PlotIndexSetInteger(q, PLOT_DRAW_TYPE, DRAW_NONE); }

   ArrayInitialize(g_topVW, 0);
   ArrayInitialize(g_botVW, 0);

   IndicatorSetString(INDICATOR_SHORTNAME, "S-Ind-ScalpPullback v2");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   // assinatura de identidade: prova no log QUAL codigo esta rodando
   Print("S-Ind-ScalpPullback v2.02 (SBurn) inicializado");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { }

//+------------------------------------------------------------------+
//| OnCalculate                                                       |
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
   if(rates_total < InpSlowEMA + 10) return 0;

   int start;
   if(prev_calculated == 0)
   {
      start = 0;
      ArrayInitialize(buyBuf,  EMPTY_VALUE);
      ArrayInitialize(sellBuf, EMPTY_VALUE);
      ArrayInitialize(fracTopBuf, EMPTY_VALUE);
      ArrayInitialize(fracBotBuf, EMPTY_VALUE);
      ArrayInitialize(hhBuf, EMPTY_VALUE);
      ArrayInitialize(lhBuf, EMPTY_VALUE);
      ArrayInitialize(hlBuf, EMPTY_VALUE);
      ArrayInitialize(llBuf, EMPTY_VALUE);
      ArrayInitialize(candleO, EMPTY_VALUE);
      ArrayInitialize(candleH, EMPTY_VALUE);
      ArrayInitialize(candleL, EMPTY_VALUE);
      ArrayInitialize(candleC, EMPTY_VALUE);
      ArrayInitialize(candleClr, 0);
      ArrayInitialize(stateTradeDirBuf, 0);
      ArrayInitialize(stateBsBelowBuf, 9999);
      ArrayInitialize(stateBsAboveBuf, 9999);
      ArrayInitialize(sigBuf, 0);
      ArrayInitialize(trendBuf, 0);
      ArrayInitialize(g_topVW, 0);
      ArrayInitialize(g_botVW, 0);
   }
   else
      start = prev_calculated - 1;

   for(int i = start; i < rates_total; i++)
   {
      // ============================================================
      // [B1] Barra viva (i == rates_total-1): apenas linhas continuas
      // (HA, PAC, EMAs, cor de candle). NENHUM evento (fractal,
      // HH/LL, sinal, estado) e' avaliado nela. Cada barra fechada
      // e' avaliada exatamente uma vez, na chegada da barra seguinte.
      // ============================================================
      bool closed = (i < rates_total - 1);

      //=== 1. Heikin Ashi ===
      double haCl, haOp, haHi, haLo;
      if(InpUseHA)
      {
         haCl = (open[i] + high[i] + low[i] + close[i]) / 4.0;
         haOp = (i == 0) ? (open[i] + close[i]) / 2.0
                         : (haOpBuf[i-1] + haClBuf[i-1]) / 2.0;
         haHi = MathMax(high[i], MathMax(haOp, haCl));
         haLo = MathMin(low[i], MathMin(haOp, haCl));
      }
      else
      { haCl = close[i]; haOp = open[i]; haHi = high[i]; haLo = low[i]; }
      haClBuf[i] = haCl; haOpBuf[i] = haOp;
      haHiBuf[i] = haHi; haLoBuf[i] = haLo;

      //=== 2. EMAs (sempre; visibilidade via PLOT_DRAW_TYPE) ===
      if(i == 0)
      {
         pacCBuf[i] = haCl; pacUBuf[i] = haHi; pacLBuf[i] = haLo;
         fastBuf[i] = haCl; medBuf[i] = haCl; slowBuf[i] = haCl;
      }
      else
      {
         pacCBuf[i] = EMAstep(haCl, pacCBuf[i-1], InpHiLoLen);
         pacUBuf[i] = EMAstep(haHi, pacUBuf[i-1], InpHiLoLen);
         pacLBuf[i] = EMAstep(haLo, pacLBuf[i-1], InpHiLoLen);
         fastBuf[i] = EMAstep(haCl, fastBuf[i-1], InpFastEMA);
         medBuf[i]  = EMAstep(haCl, medBuf[i-1],  InpMediumEMA);
         slowBuf[i] = EMAstep(haCl, slowBuf[i-1], InpSlowEMA);
      }

      //=== 3. Trend direction (sensor 27; EA le no shift 1) ===
      int trendDir = 0;
      if(fastBuf[i] > medBuf[i] && pacLBuf[i] > medBuf[i])      trendDir = 1;
      else if(fastBuf[i] < medBuf[i] && pacUBuf[i] < medBuf[i]) trendDir = -1;
      trendBuf[i] = trendDir;

      //=== 4. Bar coloring ===
      if(InpShowBarColor)
      {
         candleO[i] = open[i]; candleH[i] = high[i];
         candleL[i] = low[i];  candleC[i] = close[i];
         candleClr[i] = (haCl > pacUBuf[i]) ? 0 : (haCl < pacLBuf[i]) ? 1 : 2;
      }

      //=== limpeza dos marcadores/sinais da propria barra ===
      fracTopBuf[i] = EMPTY_VALUE;
      fracBotBuf[i] = EMPTY_VALUE;
      hhBuf[i] = EMPTY_VALUE; lhBuf[i] = EMPTY_VALUE;
      hlBuf[i] = EMPTY_VALUE; llBuf[i] = EMPTY_VALUE;
      buyBuf[i]  = EMPTY_VALUE;
      sellBuf[i] = EMPTY_VALUE;
      sigBuf[i]  = 0;

      //--- estado da barra anterior (via BUFFERS, deterministico)
      int prevTradeDir = (i > 0) ? (int)stateTradeDirBuf[i-1] : 0;
      int prevBsBelow  = (i > 0) ? (int)stateBsBelowBuf[i-1]  : 9999;
      int prevBsAbove  = (i > 0) ? (int)stateBsAboveBuf[i-1]  : 9999;

      if(!closed)
      {
         // barra viva: propaga estado sem alterar; nenhum evento
         stateTradeDirBuf[i] = prevTradeDir;
         stateBsBelowBuf[i]  = prevBsBelow;
         stateBsAboveBuf[i]  = prevBsAbove;
         continue;
      }

      //=== 5. Fractais (precos REAIS; somente barra fechada) ===
      bool topFrac = false, botFrac = false;
      if(i >= 4)
      {
         if(InpFilterBW) // strict regular
         {
            topFrac = high[i-4] < high[i-3] && high[i-3] < high[i-2]
                      && high[i-2] > high[i-1] && high[i-1] > high[i];
            botFrac = low[i-4] > low[i-3] && low[i-3] > low[i-2]
                      && low[i-2] < low[i-1] && low[i-1] < low[i];
         }
         else // BW permissive
         {
            topFrac = high[i-4] < high[i-2] && high[i-3] <= high[i-2]
                      && high[i-2] >= high[i-1] && high[i-2] > high[i];
            botFrac = low[i-4] > low[i-2] && low[i-3] >= low[i-2]
                      && low[i-2] <= low[i-1] && low[i-2] < low[i];
         }
         // [B4] sensor SEMPRE gravado; visibilidade via PLOT_DRAW_TYPE
         if(topFrac) fracTopBuf[i-2] = high[i-2];
         if(botFrac) fracBotBuf[i-2] = low[i-2];

         //=== 6. HH/LH/HL/LL (valuewhen — 1 push por barra fechada) ===
         if(topFrac)
         {
            g_topVW[2] = g_topVW[1]; g_topVW[1] = g_topVW[0];
            g_topVW[0] = high[i-2];
            if(g_topVW[1] > 0)   // [B4] sempre grava
            {
               if(g_topVW[1] < g_topVW[0] && g_topVW[2] < g_topVW[0]) hhBuf[i-2] = high[i-2];
               if(g_topVW[1] > g_topVW[0] && g_topVW[2] > g_topVW[0]) lhBuf[i-2] = high[i-2];
            }
         }
         if(botFrac)
         {
            g_botVW[2] = g_botVW[1]; g_botVW[1] = g_botVW[0];
            g_botVW[0] = low[i-2];
            if(g_botVW[1] > 0)   // [B4] sempre grava
            {
               if(g_botVW[1] < g_botVW[0] && g_botVW[2] < g_botVW[0]) hlBuf[i-2] = low[i-2];
               if(g_botVW[1] > g_botVW[0] && g_botVW[2] > g_botVW[0]) llBuf[i-2] = low[i-2];
            }
         }
      }

      //=== 7. Buy/Sell — state machine em BUFFER (barra fechada) ===
      //--- barssince com haCl FINAL da barra
      int curBsBelow = (haCl < pacCBuf[i]) ? 0 : prevBsBelow + 1;
      int curBsAbove = (haCl > pacCBuf[i]) ? 0 : prevBsAbove + 1;

      //--- PAC exit conditions
      bool pacExitU = (haOp < pacUBuf[i]) && (haCl > pacUBuf[i])
                      && (curBsBelow <= InpLookback);
      bool pacExitL = (haOp > pacLBuf[i]) && (haCl < pacLBuf[i])
                      && (curBsAbove <= InpLookback);

      //--- combina com tendencia
      bool buySignal  = (trendDir == 1)  && pacExitU;
      bool sellSignal = (trendDir == -1) && pacExitL;

      //--- state machine (else-if = comportamento do ternario Pine:
      //    apenas UM ramo dispara por barra)
      int curTradeDir;
      if(prevTradeDir == 1 && haCl < pacCBuf[i])
         curTradeDir = 0;                          // era long, pullback reset
      else if(prevTradeDir == -1 && haCl > pacCBuf[i])
         curTradeDir = 0;                          // era short, pullback reset
      else if(prevTradeDir == 0 && buySignal)
         curTradeDir = 1;                          // neutro -> long
      else if(prevTradeDir == 0 && sellSignal)
         curTradeDir = -1;                         // neutro -> short
      else
         curTradeDir = prevTradeDir;               // mantem estado

      //--- grava estado para a proxima barra ler
      stateTradeDirBuf[i] = curTradeDir;
      stateBsBelowBuf[i]  = curBsBelow;
      stateBsAboveBuf[i]  = curBsAbove;

      //--- transicao 0 -> +-1: sensor SEMPRE; seta so' visual [B3]
      if(prevTradeDir == 0 && curTradeDir == 1)
      {
         sigBuf[i] = +1;
         if(InpShowBuySell) buyBuf[i] = low[i];
      }
      else if(prevTradeDir == 0 && curTradeDir == -1)
      {
         sigBuf[i] = -1;
         if(InpShowBuySell) sellBuf[i] = high[i];
      }
   }

   return rates_total;
}
//+------------------------------------------------------------------+
