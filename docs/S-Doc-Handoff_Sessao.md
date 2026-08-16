# SBurn — Handoff de Sessao (contexto completo)
**Sessao encerrada:** 2026-08-14 | **Para:** proxima sessao (Claude ou humano)
**Como usar:** ler as secoes 1-3 antes de qualquer acao. Secao 9 = o que fazer a seguir.

---

## 1. Contexto operacional (imutavel — nao re-descobrir)

| Item | Valor |
|---|---|
| Trader | Mike, dev MQL5, PT-BR, vive no Japao |
| Ativo | **XAUUSDm** (Exness Standard, conta real 419168436, servidor Exness-MT5Real41) |
| Ouro | **3 digitos** (point = 0.001) |
| Spread real medido | **mediana 260 pts, p10 240** (NAO 80 — valor antigo, corrigido) |
| Custo round-trip | = spread (Standard, sem comissao) -> regua 2-3x = **520-780 pts** |
| Conta | JPY-denominada, hedging |
| Pasta de dados | `C:\Users\fabul\AppData\Roaming\MetaQuotes\Terminal\53785E099C927DB68A545C249CDBCE06\MQL5` |
| CSV de saida | `...\MetaQuotes\Terminal\**Common**\Files\SBurn\` (FILE_COMMON, pasta IRMA) |
| Cache do agente | `...\MetaQuotes\Tester\53785...\Agent-127.0.0.1-3000` |
| Idioma | Respostas em PT-BR; comentarios de codigo em portugues SEM acentos |

**Metodologia do Mike (respeitar sempre):** nenhum parametro sem medicao documentada; hipotese pre-registrada antes do teste; entrega por checkpoint; backtest so com **real ticks**; critica direta e honesta; sem distorcao silenciosa. Historico: ja teve perda real por backtest superajustado (Open Price Only) — dai o rigor.

---

## 2. Infraestrutura (estado final desta sessao)

| Arquivo | Pasta de instalacao | Versao | Papel |
|---|---|---|---|
| `S-Ind-TMO_Scalper.mq5` | `MQL5\Indicators\SBurn\` | **4.02** | Oscilador TMO + sensores (buffers 9-16) |
| `S-Ind-ScalpPullback.mq5` | `MQL5\Indicators\SBurn\` | **2.01** | PAC/EMA ribbon; sinal buf 26, trendDir buf 27 |
| `S-Include-MovConsistency.mqh` | `MQL5\Include\SBurn\` | — | Sensor do MKS-Engine (copia fiel) |
| `S-Include-ConsistencyGate.mqh` | `MQL5\Include\SBurn\` | 1.02 | Gate tick-based (relogio de mercado) |
| `S-EA-Test_ConsistencyGate.mq5` | `MQL5\Experts\SBurn\` | **1.13** | EA de MEDICAO — nao opera, so grava CSV |
| `S-Py-Analise_ConsistGate.py` | local (Python 3 + pandas) | — | Analise de um CSV |
| `S-Py-Compara_TFs.py` | local | — | Comparacao entre timeframes |
| `S-Doc-Registro_Empirico.md` | doc | — | Registro consolidado (atualizar!) |

**Ordem de compilacao:** os 2 indicadores primeiro (F7), o EA por ultimo. Os `.mqh` nao se compilam.

### Colunas do CSV (v1.13 — todas preenchidas e verificadas)
`time_sig; dir; price_A; spread_sig_pts; status; coleta_ms; price_B; spread_res_pts; consist; dir_sensor; alinhado; desloc_pts; dist_pts; n_ticks; mfe5_A; mae5_A; mfe15_A; mae15_A; mfe30_A; mae30_A; mfe5_B; mae5_B; mfe15_B; mae15_B; mfe30_B; mae30_B; state2; state3; conflu; exhaust; sp_trend; m1_cross; hist_cross; sp_trend_tf; bs_below; bs_above; zpos; pac_w; cyc_bars; cyc_mfe; cyc_mae; ret1; ret2; ret3; ret5; ret8; sig_high; sig_low`

Semantica-chave: **A** = bid do 1o tick da barra seguinte ao sinal (entrada executavel). **B** = bid quando o gate de 75 ticks resolve. Horizontes 5/15/30 = **BARRAS do TF do grafico**. `cyc_*` = ate o proximo sinal (ciclo real). `ret1..8` = resultado direcional no fecho das barras 1/2/3/5/8. `exhaust` = zona OB/OS do TMO no sinal. `sp_trend` = regime do SP no `InpSPTF`; `sp_trend_tf` = regime do SP no TF do grafico. `zpos` = posicao no canal PAC (0 = centro). `bs_below`/`bs_above` = frescor do recuo.

### Inputs criticos do EA (o tester GUARDA os da rodada anterior — sempre conferir)
- `InpSigSource`: **0 = SIG_TMO1** (buffer 9, base historica), 1 = SIG_TMO2, **2 = SIG_SP** (buffer 26)
- `InpTF2` / `InpTF3`: cascata do TMO. **Nunca igual ao TF do grafico** (gera artefato "sempre-contra")
- `InpSPTF`: TF de regime do SP
- Gate em modo medicao: `InpMinConsist=0`, `InpRequireAlign=false`, `InpWindowTicks=75`, `InpFeedMid=false` (BID)
- `InpShowCycle=false` no tester

**Verificacao obrigatoria no Diario apos o Start:** linha de init deve mostrar `v1.13 | fonte=<esperado> | TF=<esperado> | SPregime=<esperado>`, e o indicador imprime `S-Ind-TMO_Scalper v4.02 ... TF2=... TF3=... TMOLen=7 ...`.

---

## 3. ACHADO PRINCIPAL — a celula promissora (unica candidata a estrategia)

**Definicao:** gatilho = sinal de pullback do **ScalpPullback no M5** (buffer 26) + **regime do SP no M30 concordando** com a direcao. Saida = segurar ate o proximo sinal do SP.

| Metrica | Valor |
|---|---|
| Assimetria (medMFE15B − medMAE15B) | **OOS jan-abr +1.290 (+5.0x spread) / IS mai-ago +2.210 (+8.5x)** |
| Estabilidade mensal | **5/8 meses positivos** |
| Replicacao no M15 | **+5.142** (n=167) — sobrevive a troca de relogio |
| Escada de alcance real (cyc_mfe) | 75% >= 4.577 | 50% >= 12.077 | 25% >= 27.165 pts |
| **Baseline segurando ate o proximo sinal** | **+1.637 pts liquidos/trade** (n=337, ~1,6 trades/dia) |
| Frequencia | 644 sinais SP no M5 em 8 meses; 373 na celula alinhada |

**Ressalvas honestas:** o +1.637 e agregado — **falta o split OOS/IS e o mensal do baseline de hold** (primeira tarefa da proxima sessao). n=337 = meses, nao anos. Parte de jan-abr pode ter ticks simulados. O lucro vive na **cauda gorda** -> sequencias longas de trades medianos entre os grandes (realidade psicologica e de risco).

**Veredito:** promissor forte — o primeiro achado que justifica o investimento em dados Dukascopy.

**TP por quantil: PIORA tudo** (q25 +563, q50 +908, q75 −639, instaveis entre janelas) vs +1.637 do hold. Regra derivada: **proteger a cauda, nunca podar** — nada de take-profit fixo; se houver trailing, largo.

---

## 4. Outros achados VIVOS

**Veto de zona (TMO buffer 14) — VALIDADO.** Nao operar cruzamento que reverte extremo (OS->compra / OB->venda).
- Fora de zona vs reversao: OOS **+460/−458**; IS **+569/−1.114**
- Reversao de extremo negativa em **5 de 5 timeframes**, piorando com o TF (M1 −60 ... H1 −15.197)
- Mensal (fora de zona, M5): 6/8 positivos
- No SAR do TMO: leva o liquido de −377 para **−34 pts/ciclo**
- **Nota:** o evento do SP ja nasce 100% fora de zona (embute o veto por construcao)

**Sessao (nao validado, sinal de vida):** NY (16-23h servidor) mais fraca no ouro — medMFE15B 2.594 vs Asia 3.844 / Londres 3.758.

---

## 5. Hipoteses MORTAS (com atestado — NAO repetir)

| Hipotese | Numero que matou |
|---|---|
| TMO-cruzamento como gatilho direcional | Assimetria ~0 nos 5 TFs (M1..H1) |
| SAR puro (cruzamento a cruzamento) | 8 meses: **−2,34M pts liquidos**; 1,61M so de spread |
| MovConsistency como filtro de entrada | rho=+0,042 (p=0,23), n=807 — o +0,445 do MKS-Engine nao transferiu |
| SP trendDir(M30) como regime para o TMO | OOS −154 / IS −306 (mas VIVE sobre o gatilho SP — ver secao 3) |
| TMO-state como regime para o TMO | Dilui: pior que "fora de zona" sozinho |
| Freio de sequencia (whipsaw em cachos) | P(curto)=54,4% base vs 56,3% apos curto — sem cacho |
| **Prove-it barra 5** (sair se nao provou) | Com preco exato: −413/−460/−410 vs baseline −376. Informacao real, mas o custo ja foi pago |
| **Barra-1 como regra** (+0,294 noutro contexto) | (a) entrada confirmada: −422/trade; (b) corte na b1: −391 vs −376. **O calculo ingenuo dava +2.880 — vies de selecao** |
| TP por quantil na celula promissora | Todos abaixo do hold (+1.637); q75 negativo |
| Piramide (somar cedo) | Curva INVERTIDA no M5 (#1 −652 ... #4 +1.383) mas **nao replica** em M15/M30 — estacionada |
| Trocar por oscilador primo (MACD, TrendWave, CyberCycle) | Mesma familia de evento; funeral coletivo — nao gastar rodada |

---

## 6. Descobertas estruturais (o mapa do terreno)

- **Duas classes de inimigo:** perna longa adversa (em zona: 49% de ciclos longos, −742/ciclo — morta pelo veto) e whipsaw curto (54% dos ciclos, −2.066/ciclo — nada atual preve).
- **Concentracao 10/90:** os 10% melhores ciclos somam +15,4M pts; os outros 90%, −16,1M. O olho amostra a cauda; o CSV conta tudo. (Foi assim que se resolveu a duvida do Mike ao ver o grafico: "o preco realmente andou" e "maquina de pagar spread" sao ambos verdadeiros.)
- **Duracao x resultado (M5, liquido/ciclo):** <=30min **−2.066** | 31-60min **+1.293** | >60min **+3.257**. Alvo = perna longa NA DIRECAO (longo != bom).
- **Custo relativo por TF:** M1 ~14% | M5 ~6% | M15 ~4% do movimento tipico. Materia-prima: 12,6x (M1) a 101x (H1) o custo em MFE.
- **Licao central:** no ciclo do TMO em M5, **nenhuma regra de timing ancorada em barras e monetizavel** (barra 1, barra 5, proximo cruzamento — todas pagam mais do que salvam).
- **Licao de metodo:** filtro que "olha" uma barra sempre paga essa barra no preco de entrada. Sempre simular com preco exato de saida.
- **Filtro nao e bom/ruim em abstrato — e bom/ruim PARA UM EVENTO:** o mesmo regime M30 morreu sobre cruzamentos do TMO e vive sobre pullbacks do SP.

---

## 7. Regras aprendidas (custo alto — nunca repetir)

1. **Indicador consumido via `iCustom` NAO pode ter `input group`.** Os grupos ocupam posicao na passagem de parametros -> desalinhamento total. Sintomas vistos: erro `M7`, `TMOLen=2` (main travado em ±7,50), **zero sinais**. Custou uma madrugada. Provavelmente e a mesma causa do "Nenhum sinal coletado" do `Validate_MFE_MAE` em sessao anterior.
2. **Assinatura de versao + eco de parametros no `OnInit`** de todo programa — prova de identidade no log. Sem isso nao se sabe qual codigo esta rodando.
3. **`#property tester_indicator`** obrigatorio quando o nome do indicador vem de input (o tester nao detecta a dependencia).
4. **Relogio do gate = `time_msc` do tick** (mercado), nunca `GetTickCount64` (maquina) — no tester o timeout nunca dispararia.
5. **CSV nomeado pela data de INICIO** -> re-rodar o mesmo periodo SOBRESCREVE. Renomear antes.
6. **`FILE_COMMON` grava em `Terminal\Common\Files`**, nao na pasta do terminal.
7. **O tester guarda os inputs da rodada anterior** — conferir `InpSigSource` sempre (ja causou 2 rodadas erradas).
8. **Ao aplicar patch no EA, verificar que o gravador (`WriteRec`) foi realmente alterado** — nas v1.10-1.12 o cabecalho do CSV declarava colunas que o writer nao gravava, e saiu vazio (bug do assistente, corrigido na v1.13).
9. **MFE = excursao maxima, nao lucro.** Conferir sempre se ha vies de selecao ao filtrar por informacao futura.

---

## 8. Cronologia resumida desta sessao

1. Refatoracao dos 2 indicadores (zero-repaint real, lookahead MTF corrigido, sensores desacoplados do visual).
2. Renomeacao para o padrao SBurn (`S-Ind-*`, `S-Include-*`, `S-EA-*`) + cabecalhos com pasta de instalacao.
3. Batalha longa contra o erro `M7` -> causa raiz: `input group` + `iCustom` (regra 1).
4. EA de medicao evoluiu v1.00 -> **v1.13**, acumulando: contexto, geometria, localizacao do pullback, escada de ciclo, trilha de decisao.
5. ~21.000 sinais medidos em 5 TFs (M1/M5/M15/M30/H1), jan-ago/2026.
6. Funeral do TMO-gatilho; nascimento do TMO-sensor (veto de zona).
7. Duvida do Mike sobre o grafico -> analise 10/90 e duracao x resultado.
8. Teste do gatilho SP -> **celula promissora** (SP M5 + M30 alinhado).
9. Bug do `WriteRec` (v1.10-1.12) detectado e corrigido -> rerun -> vereditos exatos de prove-it, barra-1 e TP.

---

## 9. FILA — o que fazer na proxima sessao (ordem)

1. **Split OOS/IS e mensal do baseline de hold da celula** (+1.637). Dado ja disponivel no CSV `_SP13` — nenhuma rodada nova necessaria. **Se o hold nao passar nas duas janelas, tudo na secao 3 volta a ser hipotese.**
2. **Dukascopy**: baixar ticks reais, montar base historica unica com coluna de **proveniencia** por periodo; aplicar o modelo de spread da Exness por cima (o tick e de outro provedor de liquidez, o custo e o do Mike). Nunca comparar atraves da fronteira de feeds na mesma tabela.
3. **Validacao longa da celula** (anos, nao meses) — evento raro exige historico longo.
4. **Manejo da cauda**: trailing largo (nunca TP fixo), sizing em JPY (padrao do projeto Riser), regra de risco.
5. Vetos secundarios: sessao (NY fraca) e calendario economico (join offline por timestamp — zero mudanca no EA).
6. S/R via fractais do SP (unica familia de informacao realmente nova) e round numbers do ouro.
7. Atualizar `S-Doc-Registro_Empirico.md` com os funerais de 14/08 (prove-it, barra-1, TP, piramide).

**Nao fazer:** varrer TFs antes de ter desenho validado; testar osciladores primos; re-testar as hipoteses da secao 5.
