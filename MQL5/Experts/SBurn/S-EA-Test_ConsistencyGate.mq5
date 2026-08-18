//+------------------------------------------------------------------+
//| >>> INSTALACAO (LEIA PRIMEIRO) <<<                                |
//| PASTA:    <PastaDeDados>\MQL5\Experts\SBurn\             |
//| ARQUIVO:  S-EA-Test_ConsistencyGate.mq5                          |
//| COMPILAR: SIM (F7), DEPOIS dos 2 indicadores e com os 2 includes no lugar|
//| ASSINATURA no log ao iniciar (prova de identidade):               |
//|   "S-EA-Test_ConsistencyGate v1.04 inicializado | TF=..."                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| S-EA-Test_ConsistencyGate.mq5                                     |
//| Mede o valor do ConsistencyGate sobre os sinais do TMO v4.       |
//| NAO opera - so mede e grava CSV. XAUUSD M1. MKS-Engine.          |
//+------------------------------------------------------------------+
//| PERGUNTAS QUE RESPONDE:                                           |
//|  1. A consistencia (janela validada de 75 ticks) continua        |
//|     separando bons de maus sinais NESTE contexto (TMO v4,        |
//|     buffers de sensor desacoplados)?                             |
//|  2. Quanto do movimento e' CONSUMIDO pela espera da janela?      |
//|     Para isso o CSV registra DUAS entradas por sinal:            |
//|       A = bid no primeiro tick apos o fechamento da barra de     |
//|           sinal (convencao ja usada: entrada em open[i+1])       |
//|       B = bid no tick em que o gate resolve (entrada real com    |
//|           gate). MFE/MAE de A e B por horizonte de TEMPO.        |
//|  3. Qual corte de consistencia vale a pena? O EA NAO decide:     |
//|     com minConsist=0 (default) tudo resolve PASS e o CSV vira    |
//|     medicao pura; a analise offline simula qualquer corte,       |
//|     porque consistencia, alinhamento e MFE_B estao todos la.     |
//|                                                                   |
//| METODO:                                                           |
//|  - Sinal: buffer 9 (TMO1) ou 10 (TMO2) do TMO_Scalper v4, lido   |
//|    no shift 1 na abertura de cada barra (barra fechada).         |
//|  - Gate: 1 coleta por vez; novo sinal ABORTA a coleta anterior   |
//|    (registrada como ABORT, com leitura parcial).                 |
//|  - Excursoes tick a tick em pontos, sempre sobre o BID;          |
//|    colunas de spread permitem ajuste de custo na analise.        |
//|  - Horizontes por TEMPO a partir do relogio de CADA entrada:     |
//|    5 / 15 / 30 minutos.                                          |
//|                                                                   |
//| v1.27: DOIS BUGS corrigidos na compilacao/auditoria:              |
//|   [1] 'bid' nao declarado no bloco de liquidez — o parametro de    |
//|       OnSignal se chama 'bidNow'. Erro de compilacao.              |
//|   [2] SILENCIOSO e pior: rec.atrEnt era usado pelo bloco de        |
//|       liquidez ANTES de ser atribuido (ZeroMemory deixava 0), e    |
//|       DistNivel devolve 0 quando o ATR e' zero. As cinco colunas   |
//|       liq_* sairiam TODAS ZERADAS e a analise concluiria "zonas    |
//|       de liquidez nao separam nada" — conclusao falsa produzida    |
//|       por bug. Agora atrEnt e' atribuido no inicio do registro.    |
//| v1.26: CORRECAO DE BUG encontrado na auditoria pre-rodada.        |
//|   O range R3 (janela deslizante) estava implementado como MAXIMO   |
//|   CORRENTE desde o scratch, atualizado no mesmo tick em que o      |
//|   gatilho era testado. Consequencia: excS nunca podia ser MAIOR    |
//|   que reR3Alto (acabara de receber esse valor), entao o gatilho    |
//|   R3 NUNCA disparava — coluna morta, sem erro visivel.             |
//|   Agora R3 e' de fato deslizante: guarda o maximo POR BARRA num    |
//|   buffer circular de InpReJanela posicoes e o topo e' o maior      |
//|   valor das barras ANTERIORES (nunca da barra corrente).           |
//| v1.25: ESTRUTURA DE CALENDARIO — primeira familia realmente nova  |
//|   desde as zonas de liquidez. NAO e' derivada de preco: mede       |
//|   POSICAO NO TEMPO. Motivo: ja' medimos que NY e' mais fraca no    |
//|   ouro (medMFE15B 2.594 contra 3.844 da Asia) e nunca fechamos o   |
//|   assunto. Abertura carrega eventos estruturais reais — rollover,  |
//|   gap de fim de semana, transicao de liquidez, fixing de Londres.  |
//|   Colunas:                                                         |
//|     cal_dia    minutos desde a virada de dia do SERVIDOR           |
//|     cal_asia   minutos desde a abertura de Toquio (00:00 srv)      |
//|     cal_lon    minutos desde a abertura de Londres (08:00 srv)     |
//|     cal_ny     minutos desde a abertura de Nova York (15:00 srv)   |
//|     cal_dow    dia da semana (1=seg .. 5=sex)                      |
//|     cal_1abarra 1 se e' a primeira barra do dia no TF do grafico   |
//|   As aberturas usam o relogio do SERVIDOR (GMT+2/+3 com horario    |
//|   de verao) — sao aproximacoes das sessoes, nao horario exato de   |
//|   bolsa. Ajustar InpSrvAsia/Lon/NY se o servidor mudar de offset.  |
//|   Hipotese registrada: o efeito, se existir, deve ser de VETO      |
//|   (nao operar nos primeiros N minutos), pelo mesmo motivo do       |
//|   filtro de spread — e la' 99% da vantagem NAO era custo, era      |
//|   condicao de mercado. Conferir se e' duplicata do spread.         |
//| v1.24: SUPERTREND (M5 e TF de regime) como CONTEXTO.               |
//|   Motivo: o regime atual (trendDir do SP) e' EMA contra EMA — um   |
//|   limiar FIXO. O Supertrend usa bandas ATR x multiplicador, ou     |
//|   seja, ADAPTA o limiar a volatilidade: em periodo calmo vira com  |
//|   pouco movimento, em periodo agitado exige mais. E' diferenca de  |
//|   MECANISMO, nao so' de nome — e' o que justifica medir.           |
//|   Colunas: st_local (TF do grafico), st_regime (InpSPTF),          |
//|   st_acordo (+1/-1 se os dois concordam, 0 se divergem).           |
//|   A analise responde as TRES leituras de uma vez, offline:         |
//|     (a) SUBSTITUTO do regime atual — troca a regua, nao corta      |
//|         amostra. E' a leitura com mais chance.                     |
//|     (b) FILTRO ADICIONAL sobre o gatilho — corta amostra; e' o     |
//|         que o B_CONFLU fez, descartando trades de +$2,86.          |
//|     (c) GATILHO proprio (virada do Supertrend) — evento de         |
//|         mudanca de regime, familia enterrada 5 vezes (TMO em 5 TFs,|
//|         MACROSS com -2.972/trade e 8/8 meses negativos).           |
//|   NOTA R6: Supertrend NAO e' familia nova de informacao — continua |
//|   sendo tendencia derivada de preco. O que ele traz e' a adaptacao |
//|   a volatilidade. Se nao separar nada alem do trendDir, e'         |
//|   duplicata e sai da fila.                                         |
//| v1.23: ALTERNATIVAS AO ATR — o ATR e' hoje o UNICO denominador do |
//|   desenho (stop, gatilho de BE, passo da piramide, distancias de   |
//|   liquidez). Isso e' ponto unico de falha: se ele distorcer num    |
//|   regime, tudo distorce junto. Defeitos conhecidos: inclui GAPS    |
//|   (uma abertura de domingo infla a leitura por 14 barras), e' uma  |
//|   MEDIA (reage devagar em transicao de regime) e nao distingue     |
//|   DIRECAO de BAGUNCA (5.000 pts de tendencia limpa e 5.000 pts de  |
//|   serrote dao o mesmo valor).                                      |
//|   Estas colunas NAO substituem o ATR — apenas medem em paralelo,   |
//|   para a analise dizer se alguma mede algo que ele nao mede:       |
//|     vol_std   desvio-padrao dos retornos (ignora gap)              |
//|     vol_yz    Yang-Zhang (estimador eficiente com poucas barras)   |
//|     vol_medr  range MEDIANO (robusto a outlier, ao contrario da    |
//|               media que o ATR usa)                                 |
//|     vol_eff   Efficiency Ratio de Kaufman = |deslocamento| /       |
//|               distancia percorrida. E' matematicamente o mesmo que |
//|               o MovConsistency do MKS-Engine, que reprovou como    |
//|               FILTRO DE ENTRADA mas nunca foi testado como         |
//|               CLASSIFICADOR DE REGIME barra a barra — que e' o uso |
//|               canonico dele. ~1 = tendencia limpa; ~0 = lateral.   |
//|   Todas na mesma janela do ATR (InpATRPeriod), em pontos, exceto   |
//|   vol_eff que e' adimensional (0 a 1).                             |
//| v1.22: ZONAS DE LIQUIDEZ — a unica familia de informacao que o    |
//|   projeto nunca tocou. Tudo que medimos ate aqui compara o preco   |
//|   com ELE MESMO (medias, osciladores, ATR, excursoes). Nada mede   |
//|   o preco em relacao a NIVEIS ONDE HA ORDENS ACUMULADAS.           |
//|   Pista que motiva: 83% dos stops acionados estavam na direcao     |
//|   CERTA — o preco tirou a posicao e depois seguiu o caminho        |
//|   previsto. Essa e' a assinatura de varredura de liquidez.         |
//|   Colunas (distancias em ATR, com sinal: + = o nivel esta A FAVOR  |
//|   da direcao do trade; - = esta CONTRA, ou seja, no caminho):      |
//|     liq_round  distancia ao numero redondo mais proximo ($10)      |
//|     liq_r50    distancia ao nivel de $50                           |
//|     liq_pdh    distancia a maxima do dia anterior                  |
//|     liq_pdl    distancia a minima do dia anterior                  |
//|     liq_frac   distancia ao fractal NAO VISITADO mais proximo      |
//|   Obs: a estrutura de fractais como DIRECAO ja foi medida e        |
//|   reprovou (est_micro/est_macro). Aqui o fractal e' usado como     |
//|   NIVEL, que e' outra pergunta.                                    |
//|   Sao colunas de CONTEXTO: nenhuma filtra nada dentro do EA.       |
//| v1.21: DUAS SOLUCOES PARA "SURFAR A TENDENCIA", medidas juntas:  |
//|                                                                    |
//| (A) PIRAMIDE SIMULTANEA — colunas pir_p<passo>_n<k>.               |
//|   Motivo: a estrategia participa de 31% do movimento que ela mesma |
//|   identifica; 36% dos sinais produzem pernas >3 ATR e 60% DESSAS   |
//|   viram scratch. Adicionar posicao EM CIMA DE TRADE VENCEDOR (o    |
//|   oposto de grid, que adiciona em cima de perdedor) cria           |
//|   participacao redundante: quando a perna se desenvolve, ha varias |
//|   posicoes dentro dela. Cada adicao carrega BE e stop PROPRIOS,    |
//|   medidos a partir do PROPRIO nivel de entrada.                    |
//|   Grade: passo {0.5, 1.0} x ATR, ate 5 posicoes.                   |
//|                                                                    |
//| (B) REENTRADA POR ESGOTAMENTO — colunas re_*.                      |
//|   Motivo: apos o scratch, o preco retoma a direcao original em 71% |
//|   dos casos, mas o fundo do recuo vem 14 barras depois (mediana);  |
//|   na barra 5, 63% ainda estao caindo. Por isso o rompimento        |
//|   IMEDIATO do extremo falhou (stop de 20% contra 8%).              |
//|   Aqui o gatilho e' ESTADO, nao relogio: apos um piso curto de     |
//|   InpRePiso barras, o EA registra o range formado desde o scratch  |
//|   e so' reentra quando o preco (i) para de fazer extremo adverso   |
//|   novo por InpReCalma barras e (ii) rompe o topo do range de       |
//|   referencia. Tres definicoes de range sao medidas em paralelo:    |
//|     R1 = N barras ao redor do scratch (fixo)                       |
//|     R2 = do scratch ate o fundo (congela quando a calma comeca)    |
//|     R3 = janela deslizante de N barras                             |
//|   Snapshot no scratch (ATR, estado e posicao do TMO) gravado para  |
//|   a analise decidir OFFLINE qual confirmador do TMO usa.           |
//|   TUDO NAO CALIBRADO — a grade decide.                             |
//| v1.20: ESTRUTURA DE MERCADO (micro e macro) — informacao de uma  |
//|   familia NOVA: fractais medem MEMORIA DE PRECO (onde o mercado    |
//|   foi rejeitado), nao media suavizada. Passa no teste da R6.       |
//|   Lidos dos buffers 8 (fractal de topo) e 9 (fractal de fundo) do  |
//|   ScalpPullback — NAO dos buffers 10-13 (HH/LH/HL/LL), porque      |
//|   estes so' sao gravados se InpShowHHLL estiver ligado (mesmo      |
//|   acoplamento sensor-visual que ja' corrigimos em outros buffers).|
//|   MICRO = ultimos 2 topos e 2 fundos no TF do grafico.            |
//|   MACRO = o mesmo no InpSPTF.                                     |
//|   Codificacao: +1 alta (topo e fundo ascendentes), -1 baixa,       |
//|   0 indefinido/misto. Colunas est_micro, est_macro, est_acordo.    |
//|   ATENCAO METODOLOGICA: isso e' FILTRO, e filtro sempre REDUZ      |
//|   trades. Nao confundir com o objetivo de aumentar frequencia —    |
//|   esse depende do GATILHO (SIG_PBSHALLOW). Medir cada componente  |
//|   ISOLADO antes de qualquer voto ponderado: peso e' parametro, e   |
//|   parametro sem medicao viola a R1.                                |
//| v1.19: SIG_PBSHALLOW — gatilho de PULLBACK RASO dentro do regime. |
//|   Motivo medido: o titular fica no mercado 9% do tempo e participa|
//|   de 31% do movimento que ele mesmo identifica; o gatilho do SP    |
//|   exige o preco VOLTAR ao canal PAC, condicao rara (todos os 337   |
//|   sinais tem recuo de 1 a 3 barras — a maquina de estados nao      |
//|   gera nada alem disso). E a profundidade do recuo NAO importa:    |
//|   rho=-0,03 entre profundidade e resultado. Logo: afrouxar a       |
//|   definicao de recuo deve gerar mais sinais SEM perder qualidade.  |
//|   REGRA: dentro do estado de tendencia (SP trendDir do TF do       |
//|   grafico E do InpSPTF concordando), conta barras consecutivas     |
//|   contra a tendencia (fecho contra fecho). Quando houver de        |
//|   InpPbMin a InpPbMax barras de recuo e a barra seguinte RETOMAR   |
//|   (fecha a favor), dispara o sinal na direcao da tendencia.        |
//|   NAO exige retorno ao canal PAC. Cooldown InpPbCool barras evita  |
//|   disparo em toda barra de tendencia continua.                     |
//|   Entrada por ESTADO + respirada, coerente com as leis do projeto: |
//|   nao compra o extremo e nao aposta em evento de mudanca.          |
//|   TUDO NAO CALIBRADO — a grade (min/max/cooldown) decide.          |
//| v1.18: GRADE COMPLETA do contra-trade: 4 alvos x 3 stops = 12    |
//|        combinacoes exatas (ct_1..ct_12), fechando de uma vez as   |
//|        perguntas que a grade 3x2 deixava ambiguas (1.5x1.0,       |
//|        0.5x2.0 etc). Ordem das colunas: para cada ALVO, os 3      |
//|        stops em sequencia. Alvos {0.5,1.0,1.5,2.0} x stops        |
//|        {0.5,1.0,2.0}, em multiplos de ATR. GRADE DE MEDICAO.      |
//| v1.17: mede as DUAS ideias novas, sem construir EA nenhum ainda: |
//|  (A) CONTRA-TRADE POS-BREAKEVEN. Quando a posicao teria armado o  |
//|      BE (favA >= InpCtrArmATR x ATR) e o preco volta a entrada,   |
//|      o EA marca o ponto e simula, tick a tick, 6 combinacoes de   |
//|      (alvo x stop) na direcao CONTRARIA. Colunas be_hit, t_be e   |
//|      ct_1..ct_6 = P&L exato de saida, ou sentinela = nem alvo nem |
//|      stop ate o fim do ciclo. Motivo: a analise mostrou que apos  |
//|      o scratch o preco segue CONTRA em 86-88% dos casos (>=1 ATR),|
//|      mas o EV depende do stop, que so' medindo o caminho se sabe. |
//|  (B) SIG_MACROSS: nova fonte de sinal = PAC(vermelha, buffer 2)   |
//|      cruzando as EMAs 89 (verde, buf 3) e 200 (azul, buf 4).      |
//|      Testa a ideia do cruzamento antecipado como GATILHO; as      |
//|      colunas de contexto permitem testa-lo tambem como VETO.      |
//| v1.16: ESCADA DE DEGRAU FIXO (breakeven acima de zero), medida   |
//|        tick a tick — um stop em +500 fica ACIMA da entrada e e'   |
//|        invisivel p/ MFE/MAE, igual ao trailing.                   |
//|        Grade 3x3 em MULTIPLOS DE ATR (atravessa timeframes):      |
//|          armar em  {InpBeArm1..3} x ATR  (quando o degrau sobe)   |
//|          sair em   {InpBeLvl1..3} x ATR  (altura do degrau)       |
//|        Colunas be_a<i>l<j>: nivel de saida em pontos, ou          |
//|        SENTINELA -999999 = nao saiu (usar o P&L do ciclo).        |
//|        Stop inicial tambem em ATR (InpSimStopATR).                |
//|        Diferenca p/ o trailing: o degrau e FIXO — protege sem     |
//|        acompanhar o pico, entao nao decapita a cauda.             |
//|        GRADE DE MEDICAO, NAO CALIBRADA.                           |
//| v1.15: TRAILING (escada) medido DENTRO do EA. Trailing e' o      |
//|        unico mecanismo que NAO da p/ simular offline: o recuo    |
//|        desde o pico, quando o preco ainda esta em lucro, nao     |
//|        aparece em MFE/MAE (que medem a partir da ENTRADA).       |
//|        Para cada distancia da grade calcula-se o P&L EXATO de    |
//|        saida, tick a tick: stop inicial em -InpSimStop; quando   |
//|        o pico passa de T, o stop sobe p/ (pico - T) e nunca      |
//|        desce. Colunas tr_1..tr_4: nivel de saida em pontos, ou   |
//|        SENTINELA -999999 = nao saiu (usar o P&L do ciclo).       |
//|        Coluna atr_ent = ATR na entrada, p/ testar modulacao      |
//|        por volatilidade (trailing largo em dia agitado).         |
//|        GRADE DE MEDICAO, NAO CALIBRADA: os valores existem p/    |
//|        medir a curva, nao como parametro de operacao.            |
//| v1.14: CAMINHO DO PRECO (ordem entre MFE e MAE). Novas colunas:  |
//|        mae_pre = excursao adversa sofrida ANTES do pico          |
//|        mfe_pre = excursao favoravel obtida ANTES do fundo        |
//|        t_mfe / t_mae = barra em que pico e fundo ocorreram       |
//|        cp_mfe_N / cp_mae_N = MFE e MAE acumulados ate as barras  |
//|        1,2,3,5,8,13,21,34 (checkpoints do caminho)               |
//|        Com isso a analise simula OFFLINE breakeven, trailing e   |
//|        parcial+runner. Stop fixo ja era exato via cyc_mae.       |
//|        Usar apenas checkpoints com N <= cyc_bars.                |
//| v1.13: CORRECAO CRITICA: nas v1.10-1.12 o CABECALHO do CSV       |
//|        declarava cyc_*, ret* e sig_high/low mas o WriteRec nao   |
//|        gravava os valores (patch nao aplicado em silencio) ->    |
//|        colunas vazias na rodada de 14/08. Tail do WriteRec       |
//|        reescrito e verificado gravador a gravador.               |
//| v1.12: RETENCAO ESTENDIDA: o registro so e escrito depois de o   |
//|        ciclo fechar (proximo sinal) ou de 200 barras (cap).      |
//|        Necessario p/ fontes de cadencia baixa (SIG_SP), onde o   |
//|        proximo sinal chega depois das 30 barras de horizonte e   |
//|        o ciclo ficava sem estampa (cyc_bars=0 na rodada de 14/08)|
//| v1.11: TRILHA DE DECISAO: ret1/ret2/ret3/ret5/ret8 = resultado   |
//|        (pts, direcional) no fechamento das barras 1,2,3,5,8      |
//|        apos a entrada, + sig_high/sig_low (extremos da barra de  |
//|        sinal). Permitem simular OFFLINE, com preco EXATO de      |
//|        saida: time-stop/prove-it, confirmacao de barra 1,        |
//|        breakeven e entrada por ordem STOP alem do extremo.       |
//| v1.10: RANGE DO CICLO REAL: quando o proximo sinal chega, o      |
//|        registro anterior recebe cyc_bars (duracao ate o proximo  |
//|        cruzamento), cyc_mfe e cyc_mae (excursoes tick a tick     |
//|        DENTRO do ciclo). E o SensorReach aplicado ao ciclo:      |
//|        quantis empiricos de alcance p/ alvos, stops e trailing.  |
//|        Ciclos mais longos que 30 barras ja escritos ficam com    |
//|        cyc_bars=0 (minoria; filtrar na analise).                 |
//| v1.09: LOCALIZACAO DO PULLBACK: colunas do SP no TF DO GRAFICO   |
//|        em todo sinal: sp_trend_tf (tendencia local), bs_below/   |
//|        bs_above (barras desde o outro lado do canal = frescor    |
//|        do recuo), zpos (posicao normalizada do close no canal:   |
//|        0=centro, +-0.5=bordas) e pac_w (largura do canal, pts).  |
//|        A analise reconstroi episodios de pullback e o INDICE do  |
//|        gatilho (1..5) offline -> estudo de piramide sem regra    |
//|        fixa no EA. O EA segue apenas MEDINDO.                    |
//| v1.08: GEOMETRIA do cruzamento: m1_cross (valor do main do TMO   |
//|        na barra do sinal) e hist_cross (main-signal). Permitem   |
//|        cacar a classe de ciclos curtos (whipsaw): posicao de     |
//|        nascimento do cruzamento e profundidade, simulando       |
//|        offline filtros "um sinal por perna" e MinCross sem      |
//|        rodar grades no tester.                                  |
//| v1.07: terceira fonte de sinal: SIG_SP = buffer 26 do            |
//|        ScalpPullback no TF DO GRAFICO (estrategia de pullback:   |
//|        tendencia + recuo ate a zona PAC + saida a favor).        |
//|        O contexto TMO (zona/estados) continua sendo gravado,     |
//|        permitindo testar SP-gatilho + veto de zona do TMO.       |
//| v1.06: SEGUNDO sensor de regime: ScalpPullback (buffer 27 =      |
//|        trendDir) lido num TF de direcao (default M30, input).    |
//|        Coluna nova sp_trend no CSV. Permite o duelo de sensores  |
//|        de regime: SP(M30) vs TMO-state, sobre os mesmos sinais.  |
//|        O EA continua so MEDINDO: nenhum filtro e aplicado aqui.  |
//| v1.05: colunas de CONTEXTO por sinal (lidas no shift 1):         |
//|        state2 (TMO M5), state3 (TMO M15), conflu (MTF),          |
//|        exhaust (OB/OS no momento do cruzamento). Permitem        |
//|        testar a hipotese "filtro de regime": sinais alinhados    |
//|        com o TF maior tem assimetria MFE-MAE melhor?             |
//| v1.04: horizontes em BARRAS do TF do grafico (5/15/30 barras).   |
//|        Em M1 identico ao anterior (5/15/30 min); em M5 vira      |
//|        25/75/150 min; em M15 vira 75/225/450 min. Isso torna a   |
//|        comparacao entre timeframes justa. As colunas mfe5/15/30  |
//|        passam a significar 5/15/30 BARRAS.                       |
//| v1.03: renomeacao S-EA-*/S-Ind-*/S-Include-* (instalacao         |
//|        inequivoca) + assinatura de versao no log.                |
//| v1.02: DIAGNOSTICO do sintoma "Linhas escritas: 0" - conta      |
//|        leituras/falhas de CopyBuffer, sonda os buffers 0/2/11   |
//|        nas primeiras barras e registra min/max do buffer 0      |
//|        (identidade do .ex5: v4 = faixa aprox +-15). Tambem      |
//|        adiciona tester_indicator p/ garantir que o agente do    |
//|        tester recebe o indicador certo (nome via input nao e'   |
//|        detectavel estaticamente pelo tester).                   |
//| v1.01: relogio do gate = time_msc do tick (tempo de MERCADO);    |
//|        no tester o relogio de maquina fazia timeout nunca        |
//|        disparar e coleta_ms sair ~0.                             |
//|                                                                   |
//| RODAR COM "Every tick based on real ticks". Ticks simulados      |
//| invalidam a leitura do sensor (regra do projeto).                |
//|                                                                   |
//| CSV (FILE_COMMON): <root>\test_consistgate_<simbolo>_<per>_<data>|
//+------------------------------------------------------------------+
#property copyright "MKS-Engine"
#property version   "1.27"
#property strict

// Nome do indicador vem de INPUT (string), entao o tester nao consegue
// detectar a dependencia sozinho e nao envia o .ex5 ao agente de teste.
// Esta propriedade garante o envio (deve casar com o default do input).
#property tester_indicator "SBurn\\S-Ind-TMO_Scalper.ex5"
#property tester_indicator "SBurn\\S-Ind-ScalpPullback.ex5"

#include <SBurn/S-Include-ConsistencyGate.mqh>

//--- fonte do sinal
enum ENUM_SIG_SOURCE
{
   SIG_TMO1 = 0,   // buffer 9  (sinal TMO1)
   SIG_TMO2 = 1,   // buffer 10 (sinal TMO2)
   SIG_SP   = 2,   // buffer 26 do ScalpPullback no TF do grafico (pullback)
   SIG_MACROSS = 3,// PAC (buf 2) cruzando EMA89 (buf 3) e EMA200 (buf 4) [v1.17]
   SIG_PBSHALLOW = 4 // pullback raso dentro do regime alinhado [v1.19]
};

//+------------------------------------------------------------------+
//| Inputs                                                            |
//+------------------------------------------------------------------+
input group "=== Fonte do sinal ==="
input ENUM_SIG_SOURCE    InpSigSource    = SIG_TMO1; // Buffer de sinal do TMO v4
input string             InpIndicName    = "SBurn\\S-Ind-TMO_Scalper"; // Nome do indicador compilado

input group "=== TMO v4 (repassados ao iCustom, MESMA ORDEM) ==="
input ENUM_TIMEFRAMES    InpTF2          = PERIOD_M5;
input ENUM_TIMEFRAMES    InpTF3          = PERIOD_M15;
input int                InpTMOLen       = 7;
input int                InpCalcLen      = 3;
input int                InpSmoothLen    = 2;
input double             InpHistScale    = 4.0;
input double             InpOffset       = 1.5;
input double             InpOBLevel      = 7.0;
input double             InpOSLevel      = -7.0;
input bool               InpShowSig1     = true;
input bool               InpSig1Extreme  = false;
input bool               InpShowSig2     = true;
input bool               InpSig2Extreme  = false;
input bool               InpUseCascade   = false;
input bool               InpExhaustFilter   = false;
input int                InpExhaustLookback = 5;
input int                InpCooldown     = 3;
input double             InpMinCross     = 0.1;
input bool               InpZeroFilter   = false;
input int                InpATRPeriod    = 14;
input bool               InpShowCycle    = false;  // false: sem objetos no tester
input int                InpMaxCycleObj  = 60;

input group "=== ScalpPullback como sensor de regime ==="
input string             InpSPName       = "SBurn\\S-Ind-ScalpPullback"; // Indicador SP compilado
input ENUM_TIMEFRAMES    InpSPTF         = PERIOD_M30; // TF de direcao do SP

input group "=== Gate (contexto validado: janela 75) ==="
input int                InpWindowTicks  = 75;     // Janela de ticks (75 = validada)
input double             InpMinConsist   = 0.0;    // Corte (0 = MODO MEDICAO; calibrar por quintis)
input bool               InpRequireAlign = false;  // Exigir direcao alinhada (false em medicao)
input int                InpTimeoutSec   = 300;    // Timeout da coleta, s (operacional, NAO CALIBRADO)
input bool               InpFeedMid      = false;  // false=BID (confirmar com Test_MovConsistency)

input group "=== Simulacao de saida (GRADE DE MEDICAO, NAO CALIBRADA) ==="
input double             InpSimStop      = 20000;  // Stop inicial p/ o trailing, pts
input double             InpTrail1       = 2000;   // Distancia de trailing 1, pts
input double             InpTrail2       = 4000;   // Distancia de trailing 2, pts
input double             InpTrail3       = 8000;   // Distancia de trailing 3, pts
input double             InpTrail4       = 16000;  // Distancia de trailing 4, pts

input group "=== Calendario / sessoes (hora do SERVIDOR) ==="
input int                InpSrvAsia      = 0;     // Abertura Asia, hora do servidor
input int                InpSrvLon       = 8;     // Abertura Londres, hora do servidor
input int                InpSrvNY        = 15;    // Abertura Nova York, hora do servidor

input group "=== Supertrend (contexto, medido em paralelo) ==="
input int                InpStPeriod     = 10;    // Periodo do ATR do Supertrend
input double             InpStMult       = 3.0;   // Multiplicador das bandas
input int                InpStBarras     = 300;   // Barras para estabilizar a recorrencia

input group "=== Zonas de liquidez ==="
input double             InpLiqRound     = 10.0;  // Passo do numero redondo, em unidades do preco
input double             InpLiqRound2    = 50.0;  // Segundo passo (nivel maior)

input group "=== Estrutura de mercado (fractais) ==="
input int                InpEstBarras    = 120;   // Quantas barras varrer p/ achar 2 fractais

input group "=== Pullback raso (SIG_PBSHALLOW) — GRADE, NAO CALIBRADA ==="
input int                InpPbMin        = 1;     // Min de barras de recuo
input int                InpPbMax        = 4;     // Max de barras de recuo
input int                InpPbCool       = 3;     // Cooldown entre sinais, barras

input group "=== Piramide simultanea (GRADE, x ATR) ==="
input double             InpPirPasso1    = 0.50;  // Passo entre adicoes 1, x ATR
input double             InpPirPasso2    = 1.00;  // Passo entre adicoes 2, x ATR
input int                InpPirMax       = 5;     // Maximo de posicoes por sinal

input group "=== Reentrada por esgotamento (GRADE) ==="
input int                InpRePiso       = 5;     // Piso: barras minimas apos o scratch
input int                InpReCalma      = 3;     // Barras sem novo extremo adverso = calma
input int                InpReJanela     = 10;    // Barras do range R1/R3
input int                InpReValidade   = 120;   // Validade do monitoramento, barras

input group "=== Contra-trade pos-breakeven (GRADE, x ATR) ==="
input double             InpCtrArmATR    = 0.73;  // BE considerado armado em, x ATR
input double             InpCtrTgt1      = 0.50;  // Alvo do contra-trade 1, x ATR
input double             InpCtrTgt2      = 1.00;  // Alvo 2
input double             InpCtrTgt3      = 1.50;  // Alvo 3
input double             InpCtrTgt4      = 2.00;  // Alvo 4
input double             InpCtrStop1     = 0.50;  // Stop do contra-trade 1, x ATR
input double             InpCtrStop2     = 1.00;  // Stop 2
input double             InpCtrStop3     = 2.00;  // Stop 3

input group "=== Escada de degrau fixo (GRADE, multiplos de ATR) ==="
input double             InpSimStopATR   = 3.67;  // Stop inicial, x ATR
input double             InpBeArm1       = 0.40;  // Armar degrau em, x ATR (1)
input double             InpBeArm2       = 0.73;  // Armar degrau em, x ATR (2)
input double             InpBeArm3       = 1.20;  // Armar degrau em, x ATR (3)
input double             InpBeLvl1       = 0.05;  // Altura do degrau, x ATR (1 ~ spread)
input double             InpBeLvl2       = 0.20;  // Altura do degrau, x ATR (2)
input double             InpBeLvl3       = 0.35;  // Altura do degrau, x ATR (3)

input group "=== Projeto / Arquivos ==="
input string             InpProjectRoot  = "SBurn";

//+------------------------------------------------------------------+
//| Constantes / globais                                              |
//+------------------------------------------------------------------+
#define N_HZ 3
int HZ_SEC[N_HZ];   // 5/15/30 BARRAS do TF do grafico (definido no OnInit)

int      g_hTMO = INVALID_HANDLE;
int      g_hStLocal = INVALID_HANDLE;   // ATR do Supertrend, TF do grafico [v1.24]
int      g_hStReg   = INVALID_HANDLE;   // ATR do Supertrend, TF de regime
int      g_hSP    = INVALID_HANDLE;  // SP no TF de direcao (regime, buffer 27)
int      g_hSPsig = INVALID_HANDLE;  // SP no TF do grafico (gatilho, buffer 26)
int      g_hSig   = INVALID_HANDLE;  // handle efetivo da fonte de sinal
int      g_sigBufIdx = 9;
CConsistencyGate g_gate;

double   g_point;
datetime g_lastBar = 0;
int      g_csv = INVALID_HANDLE;
int      g_ps  = 300;         // segundos por barra do TF do grafico
double   g_trailD[4];         // grade de distancias de trailing
double   g_beArm[3], g_beLvl[3];   // grade da escada de degrau fixo [v1.16]
double   g_ctTgt[4], g_ctStop[3];  // grade do contra-trade [v1.18]
double   g_pirPasso[2];            // grade da piramide [v1.21]
#define  TR_NAO_SAIU -999999.0
string   g_csvPath;

//--- registro por sinal
struct GateRec
{
   // sinal / entrada A
   datetime tSig;             // hora do tick de deteccao (abertura barra i+1)
   int      dir;              // +1/-1
   double   priceA;           // bid no tick de deteccao
   double   spreadSigPts;
   // resolucao / entrada B
   int      status;           // ENUM_GATE_STATE congelado na resolucao
   ulong    coletaMs;
   datetime tB;
   double   priceB;
   double   spreadResPts;
   bool     hasB;
   // leitura do sensor (parcial em ABORT/TIMEOUT)
   double   consist, deslocPts, distPts;
   int      dirSensor, nTicks;
   int      alinhado;         // 1 se dirSensor == dir
   // contexto no momento do sinal (buffers 12/13/15/14 no shift 1)
   int      state2, state3, conflu, exh;
   int      spTrend;          // trendDir do ScalpPullback no TF de direcao
   double   m1Cross;          // main do TMO (escala +-15) na barra do sinal
   double   histCross;        // main - signal na barra do sinal
   // localizacao do pullback no TF do grafico [v1.09]
   int      spTrendTF;        // tendencia do SP no TF do grafico (+1/-1/0)
   int      estMicro;         // estrutura de fractais no TF do grafico [v1.20]
   double   liqRound, liqR50, liqPdh, liqPdl, liqFrac;   // zonas de liquidez [v1.22]
   double   volStd, volYz, volMedr, volEff;              // alternativas ao ATR [v1.23]
   int      stLocal, stRegime;                           // Supertrend [v1.24]
   int      calDia, calAsia, calLon, calNY, calDow, cal1a; // calendario [v1.25]
   int      estMacro;         // estrutura de fractais no InpSPTF
   int      bsBelow;          // barras desde haClose < centro do canal
   int      bsAbove;          // barras desde haClose > centro do canal
   double   zpos;             // (close - pacC)/(pacU - pacL): 0=centro, +-0.5=bordas
   double   pacW;             // largura do canal em pontos
   // trilha de decisao [v1.11]
   datetime tBar0;            // abertura da barra de entrada (ancora exata)
   double   ret[5];           // resultado no fecho das barras 1,2,3,5,8 (pts, direcional)
   bool     retDone[5];
   double   sigHigh, sigLow;  // extremos da barra de sinal (p/ simular entrada stop)
   // (A) piramide simultanea: 2 passos x 5 posicoes [v1.21]
   //     cada adicao k entra a k*passo*ATR da entrada original, com BE e stop
   //     medidos do PROPRIO nivel. pirOut = P&L de saida, ou sentinela.
   bool     pirAberta[10];    // [passo*5 + k] a adicao chegou a abrir?
   double   pirEnt[10];       // nivel de entrada (excursao, em pontos)
   double   pirFav[10];       // maior excursao favoravel DESDE a entrada dela
   bool     pirArm[10];       // BE armado?
   double   pirOut[10];       // nivel de saida, ou TR_NAO_SAIU

   // (B) reentrada por esgotamento [v1.21]
   double   reAtrSnap;        // ATR no momento do scratch
   double   reTmoMain;        // main do TMO no scratch
   double   reTmoHist;        // main-signal no scratch
   int      reTmoEstado;      // estado do TMO no scratch (+1/-1/0)
   double   reR1Alto, reR1Baixo;   // range fixo: InpReJanela barras ao redor
   double   reR2Alto, reR2Baixo;   // range do scratch ate a calma
   double   reR3Alto, reR3Baixo;   // janela deslizante (max das barras anteriores)
   double   reWin[32];             // buffer circular: maximo por barra [v1.26]
   int      reWinBarra;            // ultima barra registrada no buffer
   double   rePiorAdv;        // pior excursao adversa desde o scratch
   double   reMaxDesde;       // maior excursao favoravel desde o scratch
   int      reBarraPior;      // barra em que ela ocorreu
   int      reCalmaDesde;     // barra em que comecou a calma (0 = ainda nao)
   int      reGatilho[3];     // barra do rompimento p/ R1,R2,R3 (0 = nao houve)
   double   reEnt[3];         // nivel de entrada da reentrada
   double   reOut[3];         // P&L de saida da reentrada, ou sentinela
   bool     reArm[3];         // BE da reentrada armado
   double   reFav[3];         // favoravel desde a reentrada
   // contra-trade pos-breakeven [v1.17]
   bool     beHit;            // o BE teria sido atingido?
   double   bidBE;            // BID no momento do scratch (entrada do contra-trade)
   int      tBE;              // barra do scratch
   double   ctArmPts;         // gatilho de armar, em pontos
   double   ctOut[12];        // P&L de saida de cada (alvo x stop), ou sentinela
   // escada de degrau fixo: 3 gatilhos x 3 alturas [v1.16]
   double   beArmPts[3];      // nivel de armar, em pontos (arm x ATR da entrada)
   double   beLvlPts[3];      // altura do degrau, em pontos
   double   beStop[9];        // stop corrente de cada combinacao
   double   beOut[9];         // nivel de saida, ou sentinela
   // trailing medido tick a tick [v1.15]
   double   trStop[4];        // nivel corrente do stop (em pontos de excursao)
   double   trOut[4];         // nivel de saida, ou TR_NAO_SAIU
   double   atrEnt;           // ATR na entrada (buffer 16 do TMO), em pontos
   // caminho do preco [v1.14]
   double   maePre;           // adverso maximo ANTES do pico favoravel
   double   mfePre;           // favoravel maximo ANTES do fundo adverso
   int      tMfe, tMae;       // barra do pico e do fundo
   double   cpMfe[8], cpMae[8];
   bool     cpDone[8];
   // range do ciclo real (estampado quando o PROXIMO sinal chega) [v1.10]
   int      cycBars;          // duracao do ciclo em barras (0 = nao estampado)
   double   cycMfe;           // excursao favoravel maxima ate o proximo sinal
   double   cycMae;           // excursao adversa maxima ate o proximo sinal
   // excursoes (pontos, sobre bid)
   double   favA, advA, favB, advB;
   double   mfeA[N_HZ], maeA[N_HZ];
   double   mfeB[N_HZ], maeB[N_HZ];
   bool     doneA[N_HZ], doneB[N_HZ];
   bool     resolvido;        // status final ja estampado
};

GateRec  g_recs[];
int      g_nRecs = 0;
int      g_gateRec = -1;      // indice do rec servido pelo gate
int      g_lastRec = -1;      // indice do rec do sinal ANTERIOR (p/ estampar ciclo)

//--- contadores p/ resumo
long     g_cnt[7];            // por ENUM_GATE_STATE
long     g_written = 0, g_dropped = 0, g_incompleteAtEnd = 0;
double   g_mfe15B_pass[];     // p/ mediana rapida no resumo
int      g_nPass15 = 0;

//--- diagnostico (v1.02): por que zero sinais?
long     g_barsSeen = 0;      // barras fechadas inspecionadas
long     g_readOK   = 0;      // CopyBuffer com sucesso
long     g_readFail = 0;      // CopyBuffer falhou
long     g_nonZero  = 0;      // leituras com sinal != 0
bool     g_diagDone = false;  // sonda profunda das 3 primeiras barras
double   g_b0Min =  DBL_MAX;  // faixa do buffer 0 (TMO main)
double   g_b0Max = -DBL_MAX;

//+------------------------------------------------------------------+
//| Utilitario                                                        |
//+------------------------------------------------------------------+
double SpreadPts()
{
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return 0.0;
   return (t.ask - t.bid) / g_point;
}

string DateTag()
{
   string s = TimeToString(TimeCurrent(), TIME_DATE); // yyyy.mm.dd
   StringReplace(s, ".", "-");
   return s;
}

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   g_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(g_point <= 0) { Print("Ponto invalido"); return INIT_FAILED; }
   if(InpWindowTicks < 2) { Print("Janela de ticks invalida"); return INIT_FAILED; }

   g_sigBufIdx = (InpSigSource == SIG_TMO1) ? 9 :
                 (InpSigSource == SIG_TMO2) ? 10 : 26;   // MACROSS: calculado, nao lido

   //--- horizontes escalados pelo TF do grafico: 5/15/30 BARRAS
   int ps = PeriodSeconds(PERIOD_CURRENT);
   g_ps = ps;
   g_trailD[0] = InpTrail1; g_trailD[1] = InpTrail2;
   g_trailD[2] = InpTrail3; g_trailD[3] = InpTrail4;
   g_beArm[0] = InpBeArm1; g_beArm[1] = InpBeArm2; g_beArm[2] = InpBeArm3;
   g_beLvl[0] = InpBeLvl1; g_beLvl[1] = InpBeLvl2; g_beLvl[2] = InpBeLvl3;
   g_ctTgt[0] = InpCtrTgt1; g_ctTgt[1] = InpCtrTgt2;
   g_ctTgt[2] = InpCtrTgt3; g_ctTgt[3] = InpCtrTgt4;
   g_ctStop[0] = InpCtrStop1; g_ctStop[1] = InpCtrStop2; g_ctStop[2] = InpCtrStop3;
   g_pirPasso[0] = InpPirPasso1; g_pirPasso[1] = InpPirPasso2;
   HZ_SEC[0] = 5  * ps;
   HZ_SEC[1] = 15 * ps;
   HZ_SEC[2] = 30 * ps;

   //--- iCustom com TODOS os inputs do TMO v4, na ordem de declaracao
   g_hTMO = iCustom(_Symbol, PERIOD_CURRENT, InpIndicName,
                    InpTF2, InpTF3,
                    InpTMOLen, InpCalcLen, InpSmoothLen,
                    InpHistScale,
                    InpOffset, InpOBLevel, InpOSLevel,
                    InpShowSig1, InpSig1Extreme,
                    InpShowSig2, InpSig2Extreme,
                    InpUseCascade,
                    InpExhaustFilter, InpExhaustLookback,
                    InpCooldown, InpMinCross, InpZeroFilter,
                    InpATRPeriod,
                    InpShowCycle, InpMaxCycleObj);
   if(g_hTMO == INVALID_HANDLE)
   { Print("Falha ao criar handle do ", InpIndicName); return INIT_FAILED; }

   //--- ScalpPullback no TF de direcao (defaults do indicador; le buffer 27)
   g_hSP = iCustom(_Symbol, InpSPTF, InpSPName);
   if(g_hSP == INVALID_HANDLE)
   { Print("Falha ao criar handle do ", InpSPName, " em ", EnumToString(InpSPTF)); return INIT_FAILED; }

   //--- SP no TF do grafico: SEMPRE criado [v1.09] - fornece tendencia
   //    local, frescor do recuo e posicao no canal p/ TODO sinal
   g_hSPsig = iCustom(_Symbol, PERIOD_CURRENT, InpSPName);
   if(g_hSPsig == INVALID_HANDLE)
   { Print("Falha ao criar handle do ", InpSPName, " no TF do grafico"); return INIT_FAILED; }

   //--- fonte do sinal: TMO (default) ou SP no TF do grafico [v1.07]
   g_hSig = (InpSigSource == SIG_SP) ? g_hSPsig : g_hTMO;

   //--- [v1.24] handles de ATR para o Supertrend (um por timeframe)
   g_hStLocal = iATR(_Symbol, PERIOD_CURRENT, InpStPeriod);
   g_hStReg   = iATR(_Symbol, InpSPTF,        InpStPeriod);
   if(g_hStLocal == INVALID_HANDLE || g_hStReg == INVALID_HANDLE)
   { Print("Falha ao criar handles de ATR do Supertrend"); return INIT_FAILED; }

   g_gate.Init(InpWindowTicks, g_point, InpMinConsist, InpRequireAlign,
               (ulong)InpTimeoutSec * 1000);

   //--- CSV
   g_csvPath = InpProjectRoot + "\\test_consistgate_" + _Symbol + "_" +
               EnumToString(_Period) + "_" + DateTag() + ".csv";
   g_csv = FileOpen(g_csvPath, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(g_csv == INVALID_HANDLE)
   { Print("Falha ao abrir CSV: ", g_csvPath); return INIT_FAILED; }

   FileWriteString(g_csv,
      "time_sig;dir;price_A;spread_sig_pts;status;coleta_ms;"
      "price_B;spread_res_pts;consist;dir_sensor;alinhado;"
      "desloc_pts;dist_pts;n_ticks;"
      "mfe5_A;mae5_A;mfe15_A;mae15_A;mfe30_A;mae30_A;"
      "mfe5_B;mae5_B;mfe15_B;mae15_B;mfe30_B;mae30_B;"
      "state2;state3;conflu;exhaust;sp_trend;m1_cross;hist_cross;"
      "sp_trend_tf;est_micro;est_macro;est_acordo;liq_round;liq_r50;liq_pdh;liq_pdl;liq_frac;vol_std;vol_yz;vol_medr;vol_eff;st_local;st_regime;st_acordo;cal_dia;cal_asia;cal_lon;cal_ny;cal_dow;cal_1abarra;bs_below;bs_above;zpos;pac_w;cyc_bars;cyc_mfe;cyc_mae;"
      "ret1;ret2;ret3;ret5;ret8;sig_high;sig_low;"
      "mae_pre;mfe_pre;t_mfe;t_mae;"
      "cp_mfe_1;cp_mae_1;cp_mfe_2;cp_mae_2;cp_mfe_3;cp_mae_3;cp_mfe_5;cp_mae_5;"
      "cp_mfe_8;cp_mae_8;cp_mfe_13;cp_mae_13;cp_mfe_21;cp_mae_21;"
      "cp_mfe_34;cp_mae_34;tr_1;tr_2;tr_3;tr_4;atr_ent;"
      "be_a1l1;be_a1l2;be_a1l3;be_a2l1;be_a2l2;be_a2l3;"
      "be_a3l1;be_a3l2;be_a3l3;"
      "be_hit;t_be;"
      "ct_1;ct_2;ct_3;ct_4;ct_5;ct_6;ct_7;ct_8;ct_9;ct_10;ct_11;ct_12;"
      "pir_a0;pir_a1;pir_a2;pir_a3;pir_a4;pir_b0;pir_b1;pir_b2;pir_b3;pir_b4;"
      "re_atr;re_tmo_main;re_tmo_hist;re_tmo_est;re_pior;re_calma;"
      "re_g1;re_o1;re_g2;re_o2;re_g3;re_o3\n");

   ArrayResize(g_recs, 0, 64);
   ArrayResize(g_mfe15B_pass, 0, 1024);
   ArrayInitialize(g_cnt, 0);

   Print("S-EA-Test_ConsistencyGate v1.07 inicializado | fonte=", EnumToString(InpSigSource),
         " TF=", EnumToString(_Period),
         " horizontes(s)=", HZ_SEC[0], "/", HZ_SEC[1], "/", HZ_SEC[2],
         " SPregime=", EnumToString(InpSPTF),
         " | buffer=", g_sigBufIdx,
         " janela=", InpWindowTicks,
         " minConsist=", DoubleToString(InpMinConsist, 3),
         (InpMinConsist == 0.0 ? " (MODO MEDICAO)" : ""),
         " | Rodar com Every tick based on real ticks");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Estampa a resolucao do gate no rec que ele serve                  |
//+------------------------------------------------------------------+
void StampResolve(const double bidNow)
{
   if(g_gateRec < 0 || g_gateRec >= g_nRecs) return;

   MovConsistencyReading r = g_gate.Reading();
   ENUM_GATE_STATE st = g_gate.State();

   g_recs[g_gateRec].status       = (int)st;
   g_recs[g_gateRec].coletaMs     = g_gate.ResolveMs();
   g_recs[g_gateRec].tB           = TimeCurrent();
   g_recs[g_gateRec].priceB       = bidNow;
   g_recs[g_gateRec].spreadResPts = SpreadPts();
   g_recs[g_gateRec].hasB         = true;   // hipotetica tambem em FAIL/TIMEOUT/ABORT
   g_recs[g_gateRec].consist      = r.consistencia;
   g_recs[g_gateRec].deslocPts    = r.deslocamento_pts;
   g_recs[g_gateRec].distPts      = r.distancia_pts;
   g_recs[g_gateRec].dirSensor    = r.direcao;
   g_recs[g_gateRec].nTicks       = r.n_ticks;
   g_recs[g_gateRec].alinhado     = (r.direcao == g_recs[g_gateRec].dir) ? 1 : 0;
   g_recs[g_gateRec].resolvido    = true;

   if(st >= 0 && st <= 6) g_cnt[(int)st]++;

   g_gate.Reset();
   g_gateRec = -1;
}

//+------------------------------------------------------------------+
//| [v1.17] Cruzamento da PAC (buf 2) sobre EMA89 (3) e EMA200 (4).   |
//| Retorna +1/-1 na barra em que a PAC passa a estar acima/abaixo    |
//| das DUAS medias, e 0 nas demais. Barras fechadas (shifts 1 e 2).  |
//+------------------------------------------------------------------+
int SinalMACross(const int handle)
{
   double pac[2], fast[2], med[2];
   if(CopyBuffer(handle, 2, 1, 2, pac)  != 2) return 0;
   if(CopyBuffer(handle, 3, 1, 2, fast) != 2) return 0;
   if(CopyBuffer(handle, 4, 1, 2, med)  != 2) return 0;
   // indice 1 = shift 1 (barra fechada mais recente), indice 0 = shift 2
   bool acimaAgora  = (pac[1] > fast[1] && pac[1] > med[1]);
   bool acimaAntes  = (pac[0] > fast[0] && pac[0] > med[0]);
   bool abaixoAgora = (pac[1] < fast[1] && pac[1] < med[1]);
   bool abaixoAntes = (pac[0] < fast[0] && pac[0] < med[0]);
   if(acimaAgora  && !acimaAntes)  return +1;
   if(abaixoAgora && !abaixoAntes) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| [v1.24] Estado do Supertrend num timeframe. Retorna +1 (alta),    |
//| -1 (baixa) ou 0 (indefinido/sem dados).                           |
//| Recorrencia classica: banda superior/inferior a partir da media    |
//| high/low +- mult*ATR, com "trava" (a banda so' aperta, nunca       |
//| afrouxa enquanto o lado nao vira). Le apenas BARRAS FECHADAS       |
//| (shift 1 em diante) — zero lookahead.                              |
//+------------------------------------------------------------------+
int SupertrendEstado(const ENUM_TIMEFRAMES tf, const int handleAtr)
{
   int n = InpStBarras;
   if(Bars(_Symbol, tf) < n + 5) n = Bars(_Symbol, tf) - 5;
   if(n < InpStPeriod + 10) return 0;

   double h[], l[], c[], a[];
   ArraySetAsSeries(h, false); ArraySetAsSeries(l, false);
   ArraySetAsSeries(c, false); ArraySetAsSeries(a, false);
   // shift 1 = ultima barra FECHADA; ordem cronologica p/ a recorrencia
   if(CopyHigh (_Symbol, tf, 1, n, h) < n) return 0;
   if(CopyLow  (_Symbol, tf, 1, n, l) < n) return 0;
   if(CopyClose(_Symbol, tf, 1, n, c) < n) return 0;
   if(CopyBuffer(handleAtr, 0, 1, n, a) < n) return 0;

   double supPrev = 0.0, infPrev = 0.0;
   int trend = 1;
   for(int i = 0; i < n; i++)
   {
      if(a[i] <= 0.0) continue;
      double med = (h[i] + l[i]) / 2.0;
      double supBas = med + InpStMult * a[i];
      double infBas = med - InpStMult * a[i];
      double sup, inf;
      if(i == 0) { sup = supBas; inf = infBas; trend = (c[i] > infBas) ? 1 : -1; }
      else
      {
         // a banda so' aperta enquanto o preco nao a rompe
         sup = (supBas < supPrev || c[i-1] > supPrev) ? supBas : supPrev;
         inf = (infBas > infPrev || c[i-1] < infPrev) ? infBas : infPrev;
         if(trend == -1 && c[i] > supPrev)      trend = 1;
         else if(trend == 1 && c[i] < infPrev)  trend = -1;
      }
      supPrev = sup; infPrev = inf;
   }
   return trend;
}

//+------------------------------------------------------------------+
//| [v1.23] Alternativas ao ATR, calculadas na mesma janela.          |
//| Preenche: desvio-padrao dos retornos, Yang-Zhang, range mediano   |
//| e Efficiency Ratio. Retorna false se nao houver barras suficientes|
//+------------------------------------------------------------------+
bool VolAlternativas(const int n, double &vstd, double &vyz, double &vmed, double &veff)
{
   vstd = 0; vyz = 0; vmed = 0; veff = 0;
   if(n < 3) return false;
   int need = n + 1;
   double o[], h[], l[], c[];
   ArraySetAsSeries(o, true); ArraySetAsSeries(h, true);
   ArraySetAsSeries(l, true); ArraySetAsSeries(c, true);
   if(CopyOpen (_Symbol, PERIOD_CURRENT, 1, need, o) < need) return false;
   if(CopyHigh (_Symbol, PERIOD_CURRENT, 1, need, h) < need) return false;
   if(CopyLow  (_Symbol, PERIOD_CURRENT, 1, need, l) < need) return false;
   if(CopyClose(_Symbol, PERIOD_CURRENT, 1, need, c) < need) return false;

   //--- desvio-padrao dos retornos fecho-a-fecho (NAO inclui gap de abertura)
   double soma = 0, soma2 = 0;
   for(int i = 0; i < n; i++)
   {
      double r = (c[i] - c[i+1]) / g_point;
      soma += r; soma2 += r * r;
   }
   double media = soma / n;
   vstd = MathSqrt(MathMax(0.0, soma2 / n - media * media));

   //--- Yang-Zhang simplificado: overnight + Rogers-Satchell
   double so = 0, srs = 0;
   for(int i = 0; i < n; i++)
   {
      double ro = MathLog(o[i] / c[i+1]);                       // salto de abertura
      so += ro * ro;
      double rs = MathLog(h[i]/c[i]) * MathLog(h[i]/o[i])
                + MathLog(l[i]/c[i]) * MathLog(l[i]/o[i]);      // Rogers-Satchell
      srs += rs;
   }
   vyz = MathSqrt(MathMax(0.0, so / n + srs / n)) * c[0] / g_point;

   //--- range MEDIANO das barras (robusto; o ATR usa media)
   double rng[];
   ArrayResize(rng, n);
   for(int i = 0; i < n; i++) rng[i] = (h[i] - l[i]) / g_point;
   ArraySort(rng);
   vmed = (n % 2 == 1) ? rng[n/2] : 0.5 * (rng[n/2 - 1] + rng[n/2]);

   //--- Efficiency Ratio: |deslocamento liquido| / distancia percorrida
   double desloc = MathAbs(c[0] - c[n]) / g_point;
   double dist = 0;
   for(int i = 0; i < n; i++) dist += MathAbs(c[i] - c[i+1]) / g_point;
   veff = (dist > 0) ? desloc / dist : 0.0;
   return true;
}

//+------------------------------------------------------------------+
//| [v1.22] Distancia com SINAL ate um nivel, em ATR.                 |
//| Positivo = o nivel esta A FAVOR do trade (o preco caminha p/ ele  |
//| e ele e' alvo). Negativo = esta CONTRA (ficou para tras).         |
//| Retorna 0 se o nivel nao existir.                                 |
//+------------------------------------------------------------------+
double DistNivel(const double nivel, const double preco, const int dir, const double atrPts)
{
   if(nivel <= 0.0 || atrPts <= 0.0) return 0.0;
   return ((nivel - preco) / g_point * dir) / atrPts;
}

//+------------------------------------------------------------------+
//| [v1.22] Numero redondo mais proximo ACIMA e ABAIXO do preco.      |
//| Devolve o que esta na direcao do trade (o proximo alvo natural).  |
//+------------------------------------------------------------------+
double RedondoAdiante(const double preco, const int dir, const double passo)
{
   if(passo <= 0.0) return 0.0;
   double base = MathFloor(preco / passo) * passo;
   return (dir > 0) ? base + passo : base;
}

//+------------------------------------------------------------------+
//| [v1.22] Fractal NAO VISITADO mais proximo na direcao do trade.    |
//| Varre para tras procurando o primeiro fractal de topo (compra) ou |
//| de fundo (venda) que o preco ainda NAO tocou desde que se formou. |
//| E' o nivel onde stops tendem a se acumular.                       |
//+------------------------------------------------------------------+
double FractalNaoVisitado(const int handle, const int dir, const int maxBarras)
{
   double v[1];
   int buf = (dir > 0) ? 8 : 9;          // 8 = topo, 9 = fundo
   double extremo = 0.0;                 // maior high (ou menor low) ja visto varrendo
   for(int sh = 1; sh <= maxBarras; sh++)
   {
      double hi = iHigh(_Symbol, PERIOD_CURRENT, sh);
      double lo = iLow(_Symbol, PERIOD_CURRENT, sh);
      if(CopyBuffer(handle, buf, sh, 1, v) == 1 && v[0] != EMPTY_VALUE && v[0] > 0)
      {
         // nao visitado = o preco nao voltou a este nivel depois que ele se formou
         if(dir > 0 && v[0] > extremo) return v[0];
         if(dir < 0 && (extremo == 0.0 || v[0] < extremo)) return v[0];
      }
      if(dir > 0) { if(hi > extremo) extremo = hi; }
      else        { if(extremo == 0.0 || lo < extremo) extremo = lo; }
   }
   return 0.0;
}

//+------------------------------------------------------------------+
//| [v1.21] Gatilho de breakeven usado pela piramide e pela reentrada:|
//| o MESMO 0.73 x ATR do titular, para os resultados serem           |
//| comparaveis. Nao e' parametro novo — e' o valor ja' medido.       |
//+------------------------------------------------------------------+
double ArmPtsPir(const double atrPts) { return 0.73 * atrPts; }

//+------------------------------------------------------------------+
//| [v1.20] Estrutura de mercado a partir dos fractais do SP.         |
//| Varre para tras os buffers 8 (topo) e 9 (fundo) coletando os 2    |
//| ultimos de cada. Alta = topo2>topo1 E fundo2>fundo1 (HH+HL).      |
//| Baixa = topo2<topo1 E fundo2<fundo1 (LH+LL). Misto = 0.           |
//| Os fractais sao confirmados 2 barras depois, entao ja' nascem      |
//| defasados — nao ha risco de lookahead ao ler do shift 1.           |
//+------------------------------------------------------------------+
int EstruturaMercado(const int handle, const int maxBarras)
{
   double topo[2], fundo[2];
   int nt = 0, nf = 0;
   double v[1];
   for(int sh = 1; sh <= maxBarras && (nt < 2 || nf < 2); sh++)
   {
      if(nt < 2 && CopyBuffer(handle, 8, sh, 1, v) == 1)
         if(v[0] != EMPTY_VALUE && v[0] > 0) { topo[nt] = v[0]; nt++; }
      if(nf < 2 && CopyBuffer(handle, 9, sh, 1, v) == 1)
         if(v[0] != EMPTY_VALUE && v[0] > 0) { fundo[nf] = v[0]; nf++; }
   }
   if(nt < 2 || nf < 2) return 0;
   // indice 0 = mais recente
   bool topoSobe  = topo[0]  > topo[1];
   bool fundoSobe = fundo[0] > fundo[1];
   if(topoSobe  && fundoSobe)  return +1;
   if(!topoSobe && !fundoSobe) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| [v1.19] Pullback RASO dentro do regime.                           |
//| Estado: trendDir do SP no TF do grafico (buf 27) precisa estar     |
//| alinhado com o regime do TF maior. Dentro dele, conta barras       |
//| consecutivas fechando CONTRA a tendencia; quando a contagem esta   |
//| na faixa [min,max] e a barra fechada mais recente RETOMA a favor,  |
//| dispara. Nao exige retorno ao canal PAC (essa e' a diferenca).     |
//+------------------------------------------------------------------+
int g_pbUltimo = 0;   // contador de cooldown, em barras

int SinalPullbackRaso(const int handleTF, const int regime)
{
   if(regime == 0) return 0;
   double tr[1];
   if(CopyBuffer(handleTF, 27, 1, 1, tr) != 1) return 0;
   int trendLocal = (int)tr[0];
   if(trendLocal == 0 || trendLocal != regime) return 0;   // estado precisa concordar

   // fechos das ultimas barras fechadas: shift 1 = mais recente
   int need = InpPbMax + 3;
   double cl[];
   ArraySetAsSeries(cl, true);
   if(CopyClose(_Symbol, PERIOD_CURRENT, 1, need, cl) < need) return 0;

   // barra 1 precisa RETOMAR a favor da tendencia
   double retomada = (cl[0] - cl[1]) * trendLocal;
   if(retomada <= 0) return 0;

   // conta quantas barras ANTES dela fecharam contra a tendencia
   int recuo = 0;
   for(int k = 1; k < need - 1; k++)
   {
      double d = (cl[k] - cl[k+1]) * trendLocal;
      if(d < 0) recuo++;
      else break;
   }
   if(recuo < InpPbMin || recuo > InpPbMax) return 0;
   return trendLocal;
}

//+------------------------------------------------------------------+
//| Le um buffer de contexto do TMO no shift 1 (0 em falha)           |
//+------------------------------------------------------------------+
int ReadCtx(const int handle, const int bufIdx)
{
   double v[1];
   if(CopyBuffer(handle, bufIdx, 1, 1, v) == 1) return (int)v[0];
   return 0;
}

//--- versao double (para valores continuos como main/signal do TMO)
double ReadCtxD(const int handle, const int bufIdx)
{
   double v[1];
   if(CopyBuffer(handle, bufIdx, 1, 1, v) == 1) return v[0];
   return 0.0;
}

//+------------------------------------------------------------------+
//| Novo sinal: aborta coleta corrente e arma novo rec                |
//+------------------------------------------------------------------+
void OnSignal(const int dir, const double bidNow, const ulong mktMs)
{
   //--- coleta em andamento? aborta e estampa (leitura parcial)
   if(g_gate.Busy())
   {
      g_gate.Abort(mktMs);
      StampResolve(bidNow);
   }

   //--- limite de seguranca de registros abertos
   if(g_nRecs >= 256)
   {
      g_dropped++;
      return;
   }

   //--- [v1.10] o sinal novo FECHA o ciclo do sinal anterior:
   //    estampa duracao e excursoes acumuladas ate agora
   if(g_lastRec >= 0 && g_lastRec < g_nRecs)
   {
      g_recs[g_lastRec].cycBars = (int)((TimeCurrent() - g_recs[g_lastRec].tSig)
                                        / PeriodSeconds(PERIOD_CURRENT));
      g_recs[g_lastRec].cycMfe  = g_recs[g_lastRec].favA;
      g_recs[g_lastRec].cycMae  = g_recs[g_lastRec].advA;
   }

   //--- novo registro
   ArrayResize(g_recs, g_nRecs + 1);
   GateRec rec;
   ZeroMemory(rec);
   rec.tSig         = TimeCurrent();
   rec.dir          = dir;
   rec.priceA       = bidNow;
   rec.spreadSigPts = SpreadPts();
   rec.status       = (int)GATE_COLLECTING;
   // [v1.27] ATR primeiro: liquidez, piramide, escada e reentrada dependem dele
   rec.atrEnt       = ReadCtxD(g_hTMO, 16) / g_point;
   // contexto de regime no momento do sinal (hipotese do filtro de contexto)
   rec.state2       = ReadCtx(g_hTMO, 12);   // estado TMO no TF2 (+1/-1)
   rec.state3       = ReadCtx(g_hTMO, 13);   // estado TMO no TF3 (+1/-1)
   rec.conflu       = ReadCtx(g_hTMO, 15);   // confluencia MTF (+1/-1/0)
   rec.exh          = ReadCtx(g_hTMO, 14);   // exaustao no cruzamento (+1/-1/0)
   rec.spTrend      = ReadCtx(g_hSP, 27);    // regime do ScalpPullback (+1/-1/0)
   // geometria do cruzamento (buffers 0 e 2 do TMO no shift 1) [v1.08]
   rec.m1Cross      = ReadCtxD(g_hTMO, 0);           // posicao de nascimento
   rec.histCross    = rec.m1Cross - ReadCtxD(g_hTMO, 2); // profundidade (histograma)
   // localizacao do pullback (SP do TF do grafico, shift 1) [v1.09]
   rec.spTrendTF    = ReadCtx(g_hSPsig, 27);
   rec.estMicro     = EstruturaMercado(g_hSPsig, InpEstBarras);   // [v1.20]
   // [v1.22] zonas de liquidez, todas em ATR e com sinal
   {
      double pr = bidNow, at = rec.atrEnt;
      rec.liqRound = DistNivel(RedondoAdiante(pr, dir, InpLiqRound),  pr, dir, at);
      rec.liqR50   = DistNivel(RedondoAdiante(pr, dir, InpLiqRound2), pr, dir, at);
      double pdh = iHigh(_Symbol, PERIOD_D1, 1);
      double pdl = iLow (_Symbol, PERIOD_D1, 1);
      rec.liqPdh   = DistNivel(pdh, pr, dir, at);
      rec.liqPdl   = DistNivel(pdl, pr, dir, at);
      rec.liqFrac  = DistNivel(FractalNaoVisitado(g_hSPsig, dir, InpEstBarras), pr, dir, at);
   }
   // [v1.23] alternativas ao ATR, medidas em paralelo (nao substituem nada)
   VolAlternativas(InpATRPeriod, rec.volStd, rec.volYz, rec.volMedr, rec.volEff);
   // [v1.24] Supertrend nos dois timeframes
   rec.stLocal  = SupertrendEstado(PERIOD_CURRENT, g_hStLocal);
   rec.stRegime = SupertrendEstado(InpSPTF,        g_hStReg);
   // [v1.25] posicao no tempo (relogio do servidor)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int agora = dt.hour * 60 + dt.min;
      rec.calDia  = agora;                                   // desde 00:00 do servidor
      rec.calAsia = (agora - InpSrvAsia * 60 + 1440) % 1440;
      rec.calLon  = (agora - InpSrvLon  * 60 + 1440) % 1440;
      rec.calNY   = (agora - InpSrvNY   * 60 + 1440) % 1440;
      rec.calDow  = dt.day_of_week;
      // primeira barra do dia no TF do grafico: a barra anterior era de outro dia
      MqlDateTime d0, d1;
      TimeToStruct(iTime(_Symbol, PERIOD_CURRENT, 1), d0);
      TimeToStruct(iTime(_Symbol, PERIOD_CURRENT, 2), d1);
      rec.cal1a = (d0.day != d1.day) ? 1 : 0;
   }
   rec.estMacro     = EstruturaMercado(g_hSP,    InpEstBarras);
   rec.bsBelow      = ReadCtx(g_hSPsig, 24);
   rec.bsAbove      = ReadCtx(g_hSPsig, 25);
   double pacU = ReadCtxD(g_hSPsig, 0);
   double pacL = ReadCtxD(g_hSPsig, 1);
   double pacC = ReadCtxD(g_hSPsig, 2);
   double cl1  = iClose(_Symbol, PERIOD_CURRENT, 1);
   double larg = pacU - pacL;
   rec.zpos = (larg > 0) ? (cl1 - pacC) / larg : 0.0;
   rec.pacW = larg / g_point;
   // trilha de decisao [v1.11]
   rec.tBar0   = iTime(_Symbol, PERIOD_CURRENT, 0);   // barra de entrada
   rec.sigHigh = iHigh(_Symbol, PERIOD_CURRENT, 1);   // extremos da barra de sinal
   rec.sigLow  = iLow(_Symbol, PERIOD_CURRENT, 1);
   for(int rr = 0; rr < 5; rr++) { rec.ret[rr] = 0.0; rec.retDone[rr] = false; }
   rec.maePre = 0.0; rec.mfePre = 0.0; rec.tMfe = 0; rec.tMae = 0;   // [v1.14]
   for(int tt = 0; tt < 4; tt++)                                     // [v1.15]
   { rec.trStop[tt] = -InpSimStop; rec.trOut[tt] = TR_NAO_SAIU; }
   // [v1.16] escada em pontos, congelada com o ATR da entrada (atrEnt ja' lido)
   double atrOk = (rec.atrEnt > 0.0) ? rec.atrEnt : 1.0;
   for(int aa = 0; aa < 3; aa++)
   {
      rec.beArmPts[aa] = g_beArm[aa] * atrOk;
      rec.beLvlPts[aa] = g_beLvl[aa] * atrOk;
   }
   for(int bb = 0; bb < 9; bb++)
   { rec.beStop[bb] = -InpSimStopATR * atrOk; rec.beOut[bb] = TR_NAO_SAIU; }
   rec.beHit = false; rec.bidBE = 0.0; rec.tBE = 0;                    // [v1.17]
   for(int pk = 0; pk < 10; pk++)                                      // [v1.21] piramide
   {
      rec.pirAberta[pk] = (pk % 5 == 0);          // k=0 e' a posicao original
      rec.pirEnt[pk] = 0.0; rec.pirFav[pk] = 0.0;
      rec.pirArm[pk] = false; rec.pirOut[pk] = TR_NAO_SAIU;
   }
   rec.reAtrSnap = 0; rec.reTmoMain = 0; rec.reTmoHist = 0; rec.reTmoEstado = 0;
   rec.reR1Alto = 0; rec.reR1Baixo = 0; rec.reR2Alto = 0; rec.reR2Baixo = 0;
   rec.reR3Alto = 0; rec.reR3Baixo = 0;
   for(int wk = 0; wk < 32; wk++) rec.reWin[wk] = -DBL_MAX;   // [v1.26]
   rec.reWinBarra = -1;
   rec.rePiorAdv = 0; rec.reMaxDesde = 0; rec.reBarraPior = 0; rec.reCalmaDesde = 0;
   for(int rk = 0; rk < 3; rk++)
   { rec.reGatilho[rk] = 0; rec.reEnt[rk] = 0; rec.reOut[rk] = TR_NAO_SAIU; rec.reArm[rk] = false; rec.reFav[rk] = 0; }
   rec.ctArmPts = InpCtrArmATR * atrOk;
   for(int cx = 0; cx < 12; cx++) rec.ctOut[cx] = TR_NAO_SAIU;
   for(int cc = 0; cc < 8; cc++) { rec.cpMfe[cc] = 0.0; rec.cpMae[cc] = 0.0; rec.cpDone[cc] = false; }
   rec.hasB         = false;
   rec.resolvido    = false;
   for(int h = 0; h < N_HZ; h++)
   { rec.doneA[h] = false; rec.doneB[h] = false; }
   g_recs[g_nRecs] = rec;
   g_gateRec = g_nRecs;
   g_lastRec = g_nRecs;
   g_nRecs++;

   g_gate.Arm(dir, bidNow, mktMs);
}

//+------------------------------------------------------------------+
//| Escreve um registro completo no CSV                               |
//+------------------------------------------------------------------+
void WriteRec(const GateRec &r)
{
   string line = TimeToString(r.tSig, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + ";" +
                 IntegerToString(r.dir) + ";" +
                 DoubleToString(r.priceA, _Digits) + ";" +
                 DoubleToString(r.spreadSigPts, 1) + ";" +
                 CConsistencyGate::StateText((ENUM_GATE_STATE)r.status) + ";" +
                 IntegerToString((long)r.coletaMs) + ";" +
                 DoubleToString(r.priceB, _Digits) + ";" +
                 DoubleToString(r.spreadResPts, 1) + ";" +
                 DoubleToString(r.consist, 4) + ";" +
                 IntegerToString(r.dirSensor) + ";" +
                 IntegerToString(r.alinhado) + ";" +
                 DoubleToString(r.deslocPts, 1) + ";" +
                 DoubleToString(r.distPts, 1) + ";" +
                 IntegerToString(r.nTicks);
   for(int h = 0; h < N_HZ; h++)
      line += ";" + DoubleToString(r.mfeA[h], 1) + ";" + DoubleToString(r.maeA[h], 1);
   for(int h = 0; h < N_HZ; h++)
      line += ";" + DoubleToString(r.mfeB[h], 1) + ";" + DoubleToString(r.maeB[h], 1);
   line += ";" + IntegerToString(r.state2) + ";" + IntegerToString(r.state3) +
           ";" + IntegerToString(r.conflu) + ";" + IntegerToString(r.exh) +
           ";" + IntegerToString(r.spTrend) +
           ";" + DoubleToString(r.m1Cross, 3) + ";" + DoubleToString(r.histCross, 3) +
           ";" + IntegerToString(r.spTrendTF) +
           ";" + IntegerToString(r.estMicro) + ";" + IntegerToString(r.estMacro) +
           ";" + IntegerToString((r.estMicro != 0 && r.estMicro == r.estMacro) ? r.estMicro : 0) +
           ";" + DoubleToString(r.liqRound, 3) + ";" + DoubleToString(r.liqR50, 3) +
           ";" + DoubleToString(r.liqPdh, 3)   + ";" + DoubleToString(r.liqPdl, 3) +
           ";" + DoubleToString(r.liqFrac, 3) +
           ";" + DoubleToString(r.volStd, 1)  + ";" + DoubleToString(r.volYz, 1) +
           ";" + DoubleToString(r.volMedr, 1) + ";" + DoubleToString(r.volEff, 4) +
           ";" + IntegerToString(r.stLocal) + ";" + IntegerToString(r.stRegime) +
           ";" + IntegerToString((r.stLocal != 0 && r.stLocal == r.stRegime) ? r.stLocal : 0) +
           ";" + IntegerToString(r.calDia)  + ";" + IntegerToString(r.calAsia) +
           ";" + IntegerToString(r.calLon)  + ";" + IntegerToString(r.calNY) +
           ";" + IntegerToString(r.calDow)  + ";" + IntegerToString(r.cal1a) +
           ";" + IntegerToString(r.bsBelow) +
           ";" + IntegerToString(r.bsAbove) + ";" + DoubleToString(r.zpos, 3) +
           ";" + DoubleToString(r.pacW, 1) +
           ";" + IntegerToString(r.cycBars) + ";" + DoubleToString(r.cycMfe, 1) +
           ";" + DoubleToString(r.cycMae, 1);
   for(int rr = 0; rr < 5; rr++)
      line += ";" + DoubleToString(r.ret[rr], 1);
   line += ";" + DoubleToString(r.sigHigh, _Digits) + ";" + DoubleToString(r.sigLow, _Digits);
   line += ";" + DoubleToString(r.maePre, 1) + ";" + DoubleToString(r.mfePre, 1) +
           ";" + IntegerToString(r.tMfe) + ";" + IntegerToString(r.tMae);
   for(int cc = 0; cc < 8; cc++)
      line += ";" + DoubleToString(r.cpMfe[cc], 1) + ";" + DoubleToString(r.cpMae[cc], 1);
   for(int tt = 0; tt < 4; tt++)
      line += ";" + DoubleToString(r.trOut[tt], 1);
   line += ";" + DoubleToString(r.atrEnt, 1);
   for(int bb = 0; bb < 9; bb++)
      line += ";" + DoubleToString(r.beOut[bb], 1);
   line += ";" + IntegerToString(r.beHit ? 1 : 0) + ";" + IntegerToString(r.tBE);
   for(int cx = 0; cx < 12; cx++)
      line += ";" + DoubleToString(r.ctOut[cx], 1);
   for(int pk = 0; pk < 10; pk++)                       // [v1.21] piramide
      line += ";" + DoubleToString(r.pirAberta[pk] ? r.pirOut[pk] : TR_NAO_SAIU, 1);
   line += ";" + DoubleToString(r.reAtrSnap, 1) +       // [v1.21] snapshot
           ";" + DoubleToString(r.reTmoMain, 3) +
           ";" + DoubleToString(r.reTmoHist, 3) +
           ";" + IntegerToString(r.reTmoEstado) +
           ";" + DoubleToString(r.rePiorAdv, 1) +
           ";" + IntegerToString(r.reCalmaDesde);
   for(int rk = 0; rk < 3; rk++)                        // [v1.21] reentrada
      line += ";" + IntegerToString(r.reGatilho[rk]) + ";" + DoubleToString(r.reOut[rk], 1);
   FileWriteString(g_csv, line + "\n");
   g_written++;

   //--- amostra p/ resumo: MFE 15min da entrada B nos PASS
   if((ENUM_GATE_STATE)r.status == GATE_PASS && r.doneB[1])
   {
      ArrayResize(g_mfe15B_pass, g_nPass15 + 1);
      g_mfe15B_pass[g_nPass15] = r.mfeB[1];
      g_nPass15++;
   }
}

//+------------------------------------------------------------------+
//| OnTick                                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk)) return;
   double bid  = tk.bid;
   double feed = InpFeedMid ? (tk.bid + tk.ask) * 0.5 : tk.bid;
   datetime now = TimeCurrent();
   ulong    mkt = (ulong)tk.time_msc;   // relogio de MERCADO em ms (tester e live)

   //=== 1. Nova barra -> ler sinal da barra fechada (shift 1) ===
   datetime bt = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(bt > 0 && bt != g_lastBar)
   {
      bool first = (g_lastBar == 0);
      g_lastBar = bt;
      if(!first)   // ignora a primeira barra vista (sem historico de "novo")
      {
         g_barsSeen++;
         double sig[1];
         int got;
         if(InpSigSource == SIG_MACROSS)   // [v1.17] calculado, nao lido
         { sig[0] = (double)SinalMACross(g_hSPsig); got = 1; }
         else if(InpSigSource == SIG_PBSHALLOW)   // [v1.19]
         {
            g_pbUltimo++;
            int reg = ReadCtx(g_hSP, 27);          // regime do TF maior
            int sp  = SinalPullbackRaso(g_hSPsig, reg);
            if(sp != 0 && g_pbUltimo <= InpPbCool) sp = 0;   // cooldown
            if(sp != 0) g_pbUltimo = 0;
            sig[0] = (double)sp; got = 1;
         }
         else
            got = CopyBuffer(g_hSig, g_sigBufIdx, 1, 1, sig);
         if(got == 1)
         {
            g_readOK++;
            if(sig[0] != 0.0) g_nonZero++;
            if(sig[0] > 0.5)       OnSignal(+1, bid, mkt);
            else if(sig[0] < -0.5) OnSignal(-1, bid, mkt);

            // range do buffer 0 (TMO main): identidade do .ex5 (v4 ~ +-15)
            double m0[1];
            if(CopyBuffer(g_hTMO, 0, 1, 1, m0) == 1)
            {
               if(m0[0] < g_b0Min) g_b0Min = m0[0];
               if(m0[0] > g_b0Max) g_b0Max = m0[0];
            }
         }
         else
         {
            g_readFail++;
            if(g_readFail == 1)
               Print("Diag: 1a falha de CopyBuffer no buffer ", g_sigBufIdx,
                     " err=", GetLastError(),
                     " BarsCalculated=", BarsCalculated(g_hTMO));
         }

         // sonda profunda: 3 primeiras barras mostram main/signal/estado/sinal
         if(!g_diagDone)
         {
            double b0[1], b2[1], b11[1];
            int a  = CopyBuffer(g_hTMO, 0,  1, 1, b0);
            int b  = CopyBuffer(g_hTMO, 2,  1, 1, b2);
            int c2 = CopyBuffer(g_hTMO, 11, 1, 1, b11);
            PrintFormat("Diag barra %d: main=%s signal=%s state1=%s sig=%s",
               (int)g_barsSeen,
               a==1  ? DoubleToString(b0[0], 3) : "FALHA",
               b==1  ? DoubleToString(b2[0], 3) : "FALHA",
               c2==1 ? DoubleToString(b11[0],1) : "FALHA",
               got==1? DoubleToString(sig[0],1) : "FALHA");
            if(g_barsSeen >= 3) g_diagDone = true;
         }
      }
   }

   //=== 1b. [v1.11] Nova barra: estampar trilha de decisao dos recs abertos ===
   if(bt > 0 && bt == g_lastBar)   // g_lastBar acabou de ser atualizado acima
   {
      static const int RET_BARS[5] = {1, 2, 3, 5, 8};
      static const int CP_BARS[8]  = {1, 2, 3, 5, 8, 13, 21, 34};   // [v1.14]
      int ps = PeriodSeconds(PERIOD_CURRENT);
      for(int k = 0; k < g_nRecs; k++)
      {
         int nb = (int)((bt - g_recs[k].tBar0) / ps);   // barras completadas
         for(int rr = 0; rr < 5; rr++)
            if(!g_recs[k].retDone[rr] && nb >= RET_BARS[rr])
            {
               g_recs[k].ret[rr]     = (bid - g_recs[k].priceA) / g_point * g_recs[k].dir;
               g_recs[k].retDone[rr] = true;
            }
         // [v1.14] fotografia do caminho: MFE/MAE acumulados ate cada checkpoint
         for(int cc = 0; cc < 8; cc++)
            if(!g_recs[k].cpDone[cc] && nb >= CP_BARS[cc])
            {
               g_recs[k].cpMfe[cc]  = g_recs[k].favA;
               g_recs[k].cpMae[cc]  = g_recs[k].advA;
               g_recs[k].cpDone[cc] = true;
            }
      }
   }

   //=== 2. Alimentar gate; se resolver, estampar ===
   if(g_gate.Busy())
   {
      ENUM_GATE_STATE st = g_gate.OnTick(feed, mkt);
      if(st != GATE_COLLECTING)
         StampResolve(bid);
   }

   //=== 3. Excursoes + horizontes de todos os regs abertos ===
   for(int k = g_nRecs - 1; k >= 0; k--)
   {
      GateRec rec = g_recs[k];

      //--- entrada A
      double exc = (bid - rec.priceA) / g_point * rec.dir;   // >0 = favoravel
      // [v1.14] ao bater novo pico, congela o adverso ja sofrido (e vice-versa):
      // e isso que permite simular breakeven/trailing offline
      if(exc > rec.favA)
      {
         rec.favA   = exc;
         rec.maePre = rec.advA;
         rec.tMfe   = (int)((now - rec.tBar0) / g_ps);
      }
      if(-exc > rec.advA)
      {
         rec.advA   = -exc;
         rec.mfePre = rec.favA;
         rec.tMae   = (int)((now - rec.tBar0) / g_ps);
      }

      // ================= [v1.21] (A) PIRAMIDE SIMULTANEA =================
      // adicao k entra quando a excursao favoravel atinge k*passo*ATR.
      // cada uma tem BE no PROPRIO nivel de entrada e stop 3.67 ATR dela.
      if(rec.atrEnt > 0.0)
      {
         double atrP = rec.atrEnt;
         for(int pp = 0; pp < 2; pp++)
            for(int k = 0; k < InpPirMax && k < 5; k++)
            {
               int ix = pp * 5 + k;
               double nivel = k * g_pirPasso[pp] * atrP;      // excursao de entrada
               if(!rec.pirAberta[ix])
               {
                  if(exc >= nivel)                            // atingiu o nivel: abre
                  { rec.pirAberta[ix] = true; rec.pirEnt[ix] = nivel; rec.pirFav[ix] = 0.0; }
                  else continue;
               }
               if(rec.pirOut[ix] != TR_NAO_SAIU) continue;    // ja saiu
               double excK = exc - rec.pirEnt[ix];            // excursao DESTA posicao
               if(excK > rec.pirFav[ix]) rec.pirFav[ix] = excK;
               if(!rec.pirArm[ix] && rec.pirFav[ix] >= ArmPtsPir(atrP)) rec.pirArm[ix] = true;
               if(rec.pirArm[ix] && excK <= 0.0)              // BE no proprio nivel
                  rec.pirOut[ix] = 0.0;
               else if(!rec.pirArm[ix] && excK <= -InpSimStopATR * atrP)
                  rec.pirOut[ix] = -InpSimStopATR * atrP;     // stop proprio
            }
      }

      // ================= [v1.21] (B) REENTRADA POR ESGOTAMENTO ============
      if(rec.beHit && rec.atrEnt > 0.0)
      {
         int bAgora = (int)((now - rec.tBar0) / g_ps);
         int desdeScratch = bAgora - rec.tBE;
         double excS = (bid - rec.bidBE) / g_point * rec.dir;   // excursao desde o scratch

         // acompanha o pior adverso e detecta a "calma"
         if(-excS > rec.rePiorAdv)
         { rec.rePiorAdv = -excS; rec.reBarraPior = bAgora; rec.reCalmaDesde = 0; }
         else if(rec.reCalmaDesde == 0 && bAgora - rec.reBarraPior >= InpReCalma)
         {
            rec.reCalmaDesde = bAgora;
            rec.reR2Alto = rec.reMaxDesde;      // congela R2 quando a calma comeca
            rec.reR2Baixo = -rec.rePiorAdv;
         }
         if(excS > rec.reMaxDesde) rec.reMaxDesde = excS;
         if(desdeScratch <= InpReJanela && excS > rec.reR1Alto) rec.reR1Alto = excS;  // R1 fixo
         // [v1.26] R3 deslizante: maximo por barra num buffer circular; o topo
         // considerado e' o das barras ANTERIORES, nunca o da barra corrente —
         // era esse o bug que impedia o gatilho de disparar.
         if(desdeScratch >= 0)
         {
            int jan = (InpReJanela < 32) ? InpReJanela : 32;
            if(jan < 2) jan = 2;
            int slot = desdeScratch % jan;
            if(rec.reWinBarra != desdeScratch)         // barra nova: limpa o slot
            { rec.reWin[slot] = excS; rec.reWinBarra = desdeScratch; }
            else if(excS > rec.reWin[slot]) rec.reWin[slot] = excS;
            double topo3 = -DBL_MAX;
            for(int wk = 0; wk < jan; wk++)
               if(wk != slot && rec.reWin[wk] > topo3) topo3 = rec.reWin[wk];
            rec.reR3Alto = (topo3 == -DBL_MAX) ? 0.0 : topo3;
         }

         // gatilho: piso cumprido, calma detectada, e rompe o topo do range
         if(desdeScratch >= InpRePiso && rec.reCalmaDesde > 0 && desdeScratch <= InpReValidade)
         {
            double topo[3];
            topo[0] = rec.reR1Alto; topo[1] = rec.reR2Alto; topo[2] = rec.reR3Alto;
            for(int rk = 0; rk < 3; rk++)
            {
               if(rec.reGatilho[rk] == 0 && excS > topo[rk] && topo[rk] != 0.0)
               { rec.reGatilho[rk] = bAgora; rec.reEnt[rk] = excS; rec.reFav[rk] = 0.0; }
               if(rec.reGatilho[rk] == 0 || rec.reOut[rk] != TR_NAO_SAIU) continue;
               double excR = excS - rec.reEnt[rk];
               if(excR > rec.reFav[rk]) rec.reFav[rk] = excR;
               if(!rec.reArm[rk] && rec.reFav[rk] >= ArmPtsPir(rec.atrEnt)) rec.reArm[rk] = true;
               if(rec.reArm[rk] && excR <= 0.0) rec.reOut[rk] = 0.0;
               else if(!rec.reArm[rk] && excR <= -InpSimStopATR * rec.atrEnt)
                  rec.reOut[rk] = -InpSimStopATR * rec.atrEnt;
            }
         }
      }

      // [v1.17] contra-trade: marca o scratch e simula alvo x stop ao contrario
      if(!rec.beHit && rec.favA >= rec.ctArmPts && exc <= 0.0)
      {
         rec.beHit = true;
         rec.bidBE = bid;
         rec.tBE   = (int)((now - rec.tBar0) / g_ps);
         // [v1.21] snapshot do momento do scratch, p/ a analise decidir offline
         rec.reAtrSnap  = ReadCtxD(g_hTMO, 16) / g_point;
         rec.reTmoMain  = ReadCtxD(g_hTMO, 0);
         rec.reTmoHist  = rec.reTmoMain - ReadCtxD(g_hTMO, 2);
         rec.reTmoEstado= ReadCtx(g_hTMO, 11);
         rec.reBarraPior= rec.tBE;
      }
      if(rec.beHit && rec.atrEnt > 0.0)
      {
         // excursao na direcao CONTRARIA a original, a partir do scratch
         double excC = (bid - rec.bidBE) / g_point * (-rec.dir);
         for(int tg = 0; tg < 4; tg++)
            for(int sp = 0; sp < 3; sp++)
            {
               int ix = tg * 3 + sp;
               if(rec.ctOut[ix] != TR_NAO_SAIU) continue;
               double alvo = g_ctTgt[tg]  * rec.atrEnt;
               double perd = g_ctStop[sp] * rec.atrEnt;
               if(excC >= alvo)       rec.ctOut[ix] =  alvo;
               else if(excC <= -perd) rec.ctOut[ix] = -perd;
            }
      }

      // [v1.16] escada de degrau fixo: ao atingir o gatilho, o stop pula
      // para a altura do degrau e fica la (nao acompanha o pico).
      for(int aa = 0; aa < 3; aa++)
         for(int ll = 0; ll < 3; ll++)
         {
            int idx = aa * 3 + ll;
            if(rec.beOut[idx] != TR_NAO_SAIU) continue;
            if(rec.favA >= rec.beArmPts[aa] && rec.beStop[idx] < rec.beLvlPts[ll])
               rec.beStop[idx] = rec.beLvlPts[ll];
            if(exc <= rec.beStop[idx]) rec.beOut[idx] = rec.beStop[idx];
         }

      // [v1.15] trailing exato: sobe o stop com o pico, nunca desce.
      // Registra o nivel de saida na PRIMEIRA vez que o preco o toca.
      for(int tt = 0; tt < 4; tt++)
      {
         if(rec.trOut[tt] != TR_NAO_SAIU) continue;      // ja saiu
         double nivel = rec.favA - g_trailD[tt];
         if(nivel > rec.trStop[tt]) rec.trStop[tt] = nivel;
         if(exc <= rec.trStop[tt]) rec.trOut[tt] = rec.trStop[tt];
      }
      for(int h = 0; h < N_HZ; h++)
         if(!rec.doneA[h] && now >= rec.tSig + HZ_SEC[h])
         { rec.mfeA[h] = rec.favA; rec.maeA[h] = rec.advA; rec.doneA[h] = true; }

      //--- entrada B (existe apos a resolucao)
      if(rec.hasB)
      {
         double excB = (bid - rec.priceB) / g_point * rec.dir;
         if(excB > rec.favB)  rec.favB = excB;
         if(-excB > rec.advB) rec.advB = -excB;
         for(int h = 0; h < N_HZ; h++)
            if(!rec.doneB[h] && now >= rec.tB + HZ_SEC[h])
            { rec.mfeB[h] = rec.favB; rec.maeB[h] = rec.advB; rec.doneB[h] = true; }
      }

      g_recs[k] = rec;

      //--- completo? escreve e remove (troca com o ultimo)
      bool cycFechado = (rec.cycBars > 0) ||
                        (now >= rec.tBar0 + 200 * g_ps);   // cap de seguranca [v1.12]
      if(rec.resolvido && rec.doneA[N_HZ-1] && (!rec.hasB || rec.doneB[N_HZ-1]) && cycFechado)
      {
         WriteRec(rec);
         if(g_lastRec == k) g_lastRec = -1;            // o rec removido era o ultimo sinal
         g_recs[k] = g_recs[g_nRecs - 1];
         if(g_gateRec == g_nRecs - 1) g_gateRec = k;   // gate seguia o ultimo
         if(g_lastRec == g_nRecs - 1) g_lastRec = k;   // idem p/ o rastreador de ciclo
         g_nRecs--;
         ArrayResize(g_recs, g_nRecs);
      }
   }
}

//+------------------------------------------------------------------+
//| OnDeinit — resumo honesto                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_incompleteAtEnd = g_nRecs;   // horizonte nao completou ate o fim do teste

   Print("=== Test_ConsistencyGate: resumo ===");
   Print("Linhas escritas: ", g_written,
         " | incompletas descartadas no fim: ", g_incompleteAtEnd,
         " | sinais descartados por overflow: ", g_dropped);
   Print("Diag: barras=", g_barsSeen,
         " leituras OK=", g_readOK,
         " falhas CopyBuffer=", g_readFail,
         " sinais nao-zero=", g_nonZero);
   if(g_b0Max > -DBL_MAX)
      Print("Diag: buffer0 (TMO main) min=", DoubleToString(g_b0Min, 2),
            " max=", DoubleToString(g_b0Max, 2),
            "  (v4 esperado: oscilar dentro de aprox -15..+15, nao constante)");

   Print("PASS=", g_cnt[GATE_PASS],
         " FAIL_CONSIST=", g_cnt[GATE_FAIL_CONSIST],
         " FAIL_DIR=", g_cnt[GATE_FAIL_DIR],
         " TIMEOUT=", g_cnt[GATE_TIMEOUT],
         " ABORT=", g_cnt[GATE_ABORTED]);

   if(g_nPass15 > 0)
   {
      double tmp[];
      ArrayResize(tmp, g_nPass15);
      ArrayCopy(tmp, g_mfe15B_pass, 0, 0, g_nPass15);
      ArraySort(tmp);
      double med = (g_nPass15 % 2 == 1) ? tmp[g_nPass15/2]
                   : 0.5 * (tmp[g_nPass15/2 - 1] + tmp[g_nPass15/2]);
      Print("Mediana MFE 15min (entrada B, grupo PASS): ",
            DoubleToString(med, 1), " pts (n=", g_nPass15, ")");
      Print("Lembrete do gate de custo: viavel se mediana >= 2-3x custo round-trip medido.");
   }

   if(g_csv != INVALID_HANDLE) { FileClose(g_csv); g_csv = INVALID_HANDLE; }
   if(g_hTMO != INVALID_HANDLE) { IndicatorRelease(g_hTMO); g_hTMO = INVALID_HANDLE; }
   if(g_hSP    != INVALID_HANDLE) { IndicatorRelease(g_hSP);    g_hSP    = INVALID_HANDLE; }
   if(g_hSPsig != INVALID_HANDLE) { IndicatorRelease(g_hSPsig); g_hSPsig = INVALID_HANDLE; }
   if(g_hStLocal != INVALID_HANDLE) { IndicatorRelease(g_hStLocal); g_hStLocal = INVALID_HANDLE; }
   if(g_hStReg   != INVALID_HANDLE) { IndicatorRelease(g_hStReg);   g_hStReg   = INVALID_HANDLE; }
   Print("CSV (Common\\Files): ", g_csvPath);
}
//+------------------------------------------------------------------+