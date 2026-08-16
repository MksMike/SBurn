//+------------------------------------------------------------------+
//| >>> INSTALACAO (LEIA PRIMEIRO) <<<                                |
//| PASTA:    <PastaDeDados>\MQL5\Include\SBurn\             |
//| ARQUIVO:  S-Include-ConsistencyGate.mqh                          |
//| COMPILAR: NAO (e' include; quem compila e' o EA)                 |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| S-Include-ConsistencyGate.mqh                                    |
//| Gate de confluencia baseado no sensor MovConsistency (validado). |
//| Projeto SBurn — AUTOCONTIDO: este gate e o sensor validado       |
//| (MovConsistency_Sensor.mqh, copia fiel do MKS-Engine) vivem      |
//| JUNTOS em MQL5\Include\SBurn\. Se o original do MKS-Engine       |
//| divergir, o ORIGINAL vence: a matematica validada nao pode       |
//| mudar sem nova medicao.                                          |
//+------------------------------------------------------------------+
//| CHANGELOG:                                                        |
//|  v1.02 - renomeado p/ S-Include-* (instalacao inequivoca).       |
//|  v1.01 - RELOGIO DE MERCADO: Arm/Abort/OnTick agora recebem o    |
//|          time_msc do tick. Antes (v1.00) usava GetTickCount64   |
//|          (relogio da MAQUINA): no Strategy Tester isso fazia o  |
//|          timeout nunca disparar e coleta_ms sair ~0, porque o   |
//|          tester processa horas de mercado em segundos de CPU.   |
//|          Agora coleta_ms e timeout sao tempo de MERCADO, com    |
//|          semantica identica no tester e no live.                |
//+------------------------------------------------------------------+
//| CONTEXTO DE VALIDACAO (nao alterar sem nova medicao):             |
//|  - Sensor: CMovConsistencySensor (MovConsistency_Sensor.mqh)     |
//|  - Achado: Spearman +0.445 entre consistencia e MFE, medido em   |
//|    VIRADAS DO TMO, janela de 75 ticks pos-virada, XAUUSD M1.     |
//|  - A matematica do sensor NAO e' reimplementada aqui: este gate  |
//|    apenas CONSOME a classe validada, inalterada, via #include    |
//|    (copia fiel na mesma pasta).                                  |
//|                                                                   |
//| O QUE O GATE FAZ:                                                 |
//|  1. Arm(dir, preco, mktMs) no fechamento da barra de sinal      |
//|  2. OnTick(preco, mktMs) alimenta o sensor tick a tick          |
//|  3. Quando a janela enche -> resolve:                            |
//|       PASS         consistencia >= minimo E direcao alinhada    |
//|       FAIL_CONSIST consistencia abaixo do minimo                |
//|       FAIL_DIR     deslocamento liquido contra o sinal          |
//|       TIMEOUT      janela nao encheu no tempo limite (densidade |
//|                    de ticks incomparavel com a da validacao)    |
//|       ABORTED      novo sinal chegou durante a coleta           |
//|                                                                   |
//| PARAMETROS NAO CALIBRADOS (expostos de proposito):                |
//|  - minConsist: o corte deve vir da analise de quintis do CSV     |
//|    medido, nunca de intuicao. Default 0.0 = MODO MEDICAO:        |
//|    tudo passa, o CSV registra, a analise offline decide o corte. |
//|  - timeoutMs: limite operacional de seguranca (ms de MERCADO),   |
//|    nao parametro de estrategia. Timeouts registrados a parte.    |
//|                                                                   |
//| CONTRATO: o gate mede e reporta. Quem entra na operacao e' o EA. |
//+------------------------------------------------------------------+
#property strict

#include "S-Include-MovConsistency.mqh"

//--- estados do gate
enum ENUM_GATE_STATE
{
   GATE_IDLE         = 0,   // sem coleta ativa
   GATE_COLLECTING   = 1,   // janela enchendo
   GATE_PASS         = 2,   // resolvido: confluencia OK
   GATE_FAIL_CONSIST = 3,   // resolvido: consistencia < minimo
   GATE_FAIL_DIR     = 4,   // resolvido: direcao contra o sinal
   GATE_TIMEOUT      = 5,   // janela nao encheu a tempo
   GATE_ABORTED      = 6    // coleta interrompida por novo sinal
};

//+------------------------------------------------------------------+
//| CConsistencyGate                                                  |
//+------------------------------------------------------------------+
class CConsistencyGate
{
private:
   CMovConsistencySensor m_sensor;      // sensor validado, inalterado
   ENUM_GATE_STATE       m_state;
   int                   m_dir;          // direcao do sinal armado (+1/-1)
   datetime              m_armTime;      // hora (mercado) do Arm
   ulong                 m_armMs;        // time_msc do tick no Arm (MERCADO)
   double                m_armPrice;     // preco no Arm (referencia)
   ulong                 m_resolveMs;    // duracao da coleta em ms de MERCADO
   double                m_minConsist;   // corte de consistencia (0=medicao)
   bool                  m_requireAlign; // exigir direcao alinhada
   ulong                 m_timeoutMs;    // limite p/ encher a janela (ms mercado)
   MovConsistencyReading m_lastRead;     // leitura no momento da resolucao

   //--- tempo decorrido de mercado, protegido contra ms nao-monotonico
   ulong Elapsed(const ulong mktMs) const
   {
      return (mktMs > m_armMs) ? (mktMs - m_armMs) : 0;
   }

   //--- aplica as regras de resolucao sobre uma leitura completa
   void Resolve(const MovConsistencyReading &r, const ulong mktMs)
   {
      m_lastRead  = r;
      m_resolveMs = Elapsed(mktMs);
      if(m_requireAlign && r.direcao != m_dir)
         m_state = GATE_FAIL_DIR;
      else if(r.consistencia < m_minConsist)
         m_state = GATE_FAIL_CONSIST;
      else
         m_state = GATE_PASS;
      m_sensor.Stop();
   }

public:
   //--- inicializacao (uma vez, no OnInit do EA)
   void Init(const int windowTicks, const double point,
             const double minConsist, const bool requireAlign,
             const ulong timeoutMs)
   {
      m_sensor.Init(windowTicks, point);
      m_state        = GATE_IDLE;
      m_dir          = 0;
      m_armTime      = 0;
      m_armMs        = 0;
      m_armPrice     = 0.0;
      m_resolveMs    = 0;
      m_minConsist   = minConsist;
      m_requireAlign = requireAlign;
      m_timeoutMs    = timeoutMs;
      ZeroMemory(m_lastRead);
   }

   //--- arma o gate na confirmacao do sinal (fechamento da barra)
   //    mktMs = time_msc do tick atual (relogio de MERCADO)
   void Arm(const int dir, const double price, const ulong mktMs)
   {
      m_dir      = dir;
      m_armMs    = mktMs;
      m_armTime  = (datetime)(mktMs / 1000);
      m_armPrice = price;
      m_resolveMs= 0;
      ZeroMemory(m_lastRead);
      m_sensor.Start();
      m_state    = GATE_COLLECTING;
   }

   //--- interrompe coleta em andamento (novo sinal chegou)
   //    guarda a leitura parcial p/ log honesto
   void Abort(const ulong mktMs)
   {
      if(m_state != GATE_COLLECTING) return;
      m_lastRead  = m_sensor.Read();       // leitura parcial (valido=false)
      m_resolveMs = Elapsed(mktMs);
      m_sensor.Stop();
      m_state     = GATE_ABORTED;
   }

   //--- volta ao repouso apos o EA consumir o resultado
   void Reset()
   {
      if(m_state == GATE_COLLECTING) return;   // usar Abort() p/ isso
      m_state = GATE_IDLE;
      m_dir   = 0;
   }

   //--- alimenta um tick; retorna o estado apos processar
   //    mktMs = time_msc do tick atual (relogio de MERCADO)
   ENUM_GATE_STATE OnTick(const double price, const ulong mktMs)
   {
      if(m_state != GATE_COLLECTING) return m_state;

      m_sensor.Update(price);

      if(m_sensor.Pronto())
      {
         Resolve(m_sensor.Read(), mktMs);
         return m_state;
      }

      if(m_timeoutMs > 0 && Elapsed(mktMs) > m_timeoutMs)
      {
         m_lastRead  = m_sensor.Read();     // parcial: registrada p/ analise
         m_resolveMs = Elapsed(mktMs);
         m_sensor.Stop();
         m_state     = GATE_TIMEOUT;
      }
      return m_state;
   }

   //--- acesso (somente leitura)
   ENUM_GATE_STATE        State()      const { return m_state; }
   int                    ArmDir()     const { return m_dir; }
   datetime               ArmTime()    const { return m_armTime; }
   double                 ArmPrice()   const { return m_armPrice; }
   ulong                  ResolveMs()  const { return m_resolveMs; }  // ms de MERCADO
   MovConsistencyReading  Reading()    const { return m_lastRead; }
   bool                   Busy()       const { return m_state == GATE_COLLECTING; }
   bool                   Resolved()   const
   {
      return m_state == GATE_PASS || m_state == GATE_FAIL_CONSIST ||
             m_state == GATE_FAIL_DIR || m_state == GATE_TIMEOUT ||
             m_state == GATE_ABORTED;
   }

   //--- texto p/ CSV/log
   static string StateText(const ENUM_GATE_STATE s)
   {
      switch(s)
      {
         case GATE_PASS:         return "PASS";
         case GATE_FAIL_CONSIST: return "FAIL_CONSIST";
         case GATE_FAIL_DIR:     return "FAIL_DIR";
         case GATE_TIMEOUT:      return "TIMEOUT";
         case GATE_ABORTED:      return "ABORT";
         case GATE_COLLECTING:   return "COLLECTING";
      }
      return "IDLE";
   }
};
//+------------------------------------------------------------------+
