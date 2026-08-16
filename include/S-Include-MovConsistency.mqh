//+------------------------------------------------------------------+
//| >>> INSTALACAO (LEIA PRIMEIRO) <<<                                |
//| PASTA:    <PastaDeDados>\MQL5\Include\SBurn\             |
//| ARQUIVO:  S-Include-MovConsistency.mqh                           |
//| COMPILAR: NAO (e' include; quem compila e' o EA)                 |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| S-Include-MovConsistency.mqh                                     |
//| Sensor de CONSISTENCIA do movimento (o quao "reto" foi).        |
//| Parte do catalogo de sensores do MKS-Engine.                    |
//| COPIA FIEL vendorizada no projeto SBurn (Include\SBurn\).       |
//| Se divergir do original em C:\dev\MKS-Engine, o ORIGINAL vence. |
//+------------------------------------------------------------------+
//| HIPOTESE QUE MOTIVA:                                            |
//|  A forca/direcao do movimento inicial apos a virada do TMO     |
//|  prediz se o trade sera bom. Especificamente: a CONSISTENCIA   |
//|  (movimento reto vs cambaleante) pode distinguir os "bons"     |
//|  (+1560) dos "ruins" (-1515) MELHOR que so o fecho da barra 1. |
//|                                                                 |
//| O QUE MEDE:                                                    |
//|  consistencia = deslocamento_liquido / distancia_total         |
//|   ~1.0 = movimento reto (foi direto de A a B)                  |
//|   ~0.0 = movimento erratico (zigzag muito p/ chegar em B)      |
//|  Tambem conhecido como "eficiencia" do movimento.             |
//|                                                                 |
//| CONTRATO: mede e reporta, NUNCA julga. Quem decide e o EA.     |
//| A direcao e reportada separada; o EA cruza com a direcao       |
//| esperada da virada (consistencia a favor vs contra).          |
//+------------------------------------------------------------------+
#property strict

struct MovConsistencyReading
{
   bool     valido;            // janela cheia (N ticks coletados)?
   double   consistencia;      // 0..1 = |deslocamento| / distancia
   double   deslocamento_pts;  // deslocamento liquido, em pontos
   double   distancia_pts;     // distancia total percorrida, em pontos
   int      direcao;           // +1 subiu / -1 desceu / 0 neutro
   int      n_ticks;           // ticks coletados ate agora
};

//+------------------------------------------------------------------+
//| CMovConsistencySensor                                            |
//+------------------------------------------------------------------+
class CMovConsistencySensor
{
private:
   double m_prices[];   // buffer dos precos coletados (janela)
   int    m_window;     // tamanho da janela em ticks
   double m_point;      // tamanho do ponto do simbolo
   int    m_head;       // reservado (compatibilidade com o original)
   int    m_count;      // quantos ticks ja coletados
   bool   m_ativo;      // coleta em andamento?

public:
   //--- inicializacao
   void Init(int windowTicks, double point)
   {
      m_window = windowTicks;
      m_point  = point;
      ArrayResize(m_prices, m_window);
      ArrayInitialize(m_prices, 0.0);
      m_head = 0;
      m_count = 0;
      m_ativo = false;
   }

   //--- comeca uma nova coleta (chamado quando a virada acontece)
   void Start()
   {
      m_head = 0;
      m_count = 0;
      m_ativo = true;
   }

   //--- para a coleta
   void Stop()
   {
      m_ativo = false;
   }

   //--- alimenta um tick (so coleta se ativo e janela nao cheia)
   void Update(double price)
   {
      if(!m_ativo) return;
      if(m_count >= m_window) return;   // janela ja cheia, para de coletar
      m_prices[m_count] = price;
      m_count++;
   }

   //--- le a consistencia atual (nao muda estado)
   MovConsistencyReading Read()
   {
      MovConsistencyReading r;
      r.valido = (m_count >= m_window);
      r.consistencia = 0.0;
      r.deslocamento_pts = 0.0;
      r.distancia_pts = 0.0;
      r.direcao = 0;
      r.n_ticks = m_count;

      if(m_count < 2) return r;   // precisa de ao menos 2 ticks

      // deslocamento liquido: do primeiro ao ultimo tick coletado
      double desloc = m_prices[m_count-1] - m_prices[0];

      // distancia total: soma dos |movimentos| tick a tick
      double dist = 0.0;
      for(int i=1; i<m_count; i++)
         dist += MathAbs(m_prices[i] - m_prices[i-1]);

      r.deslocamento_pts = desloc / m_point;
      r.distancia_pts = dist / m_point;

      // consistencia = |deslocamento| / distancia (0 a 1)
      if(dist > 0.0)
         r.consistencia = MathAbs(desloc) / dist;

      // direcao do deslocamento liquido
      if(desloc > 0)      r.direcao = +1;
      else if(desloc < 0) r.direcao = -1;
      else                r.direcao = 0;

      return r;
   }

   //--- utilitario: ja coletou a janela inteira?
   bool Pronto()
   {
      return (m_count >= m_window);
   }
};
//+------------------------------------------------------------------+
