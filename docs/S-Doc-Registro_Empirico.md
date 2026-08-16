# SBurn — Registro Empirico do Projeto
**Atualizado:** 2026-08-14 | **Base:** ~21.000 sinais, 5 timeframes, jan–ago/2026, XAUUSDm (Exness Standard, ouro 3 digitos)

---

## Estado em uma frase
Um filtro validado (veto de zona do TMO), duas classes de inimigo identificadas (perna longa adversa: morta pelo veto; whipsaw curto: em caca via geometria), um gatilho candidato na camara (pullback do SP), e a licao central: **assimetria de entrada so vira lucro com motor de saida assimetrico.**

---

## 1. Infraestrutura (v atual)

| Arquivo | Pasta | Versao | Papel |
|---|---|---|---|
| S-Ind-TMO_Scalper.mq5 | Indicators\SBurn | 4.02 | Oscilador + sensores (buffers 9-16), zero-repaint, sem input group |
| S-Ind-ScalpPullback.mq5 | Indicators\SBurn | 2.01 | Pullback tool, sinal no buffer 26, trendDir no 27 |
| S-Include-MovConsistency.mqh | Include\SBurn | — | Sensor validado do MKS-Engine (copia fiel) |
| S-Include-ConsistencyGate.mqh | Include\SBurn | 1.02 | Gate de coleta tick-based (relogio de mercado) |
| S-EA-Test_ConsistencyGate.mq5 | Experts\SBurn | 1.08 | EA de MEDICAO (nao opera): fontes TMO1/TMO2/SP, contexto, geometria |
| S-Py-Analise_ConsistGate.py | local | — | Analise: custo, A/B, quintis, regime, exaustao, geometria |
| S-Py-Compara_TFs.py | local | — | Comparacao entre timeframes |

**Padroes:** horizontes em BARRAS do TF (5/15/30); entrada A = bid do 1o tick da barra seguinte; entrada B = pos-janela de 75 ticks; CSV em Common\Files\SBurn; real ticks obrigatorio; assinaturas de versao no log.

---

## 2. Achado VALIDADO

**Veto de zona (TMO buffer 14):** nao operar cruzamento que reverte extremo (OS->compra / OB->venda).
- Assimetria fora de zona vs reversao: OOS jan-abr **+460 / -458**; IS mai-ago **+569 / -1114** (M5, 15 barras)
- Reversao de extremo negativa em **5 de 5 timeframes**, piorando com o TF (M1 -60 ... H1 -15.197)
- Mensal (fora de zona, M5): 6 de 8 meses positivos
- No SAR: leva o liquido de -377 para **-34 pts/ciclo** (recupera ~90% da sangria)

## 3. Hipoteses MORTAS (com atestado)

| Hipotese | Veredito | Numero-chave |
|---|---|---|
| TMO-cruzamento como gatilho direcional | Morto em 5 TFs | Assimetria ~0 em todos; SAR liquido -377/ciclo |
| SAR (cruzamento a cruzamento) puro | Morto | 8 meses: -2,34M pts liquidos; 1,61M pagos em spread |
| MovConsistency como filtro de entrada | Morto neste contexto | rho=+0.042 (p=0.23), n=807; +0.445 nao transferiu |
| SP trendDir(M30) como regime p/ TMO | Morto | OOS -154 / IS -306; Desenho A: +30/-5 |
| TMO-state como regime p/ TMO | Dilui | Mais fraco que "fora de zona" sozinho nas 2 janelas |
| Trocar por oscilador primo (MACD etc.) | Nao testar | Mesma familia de evento; funeral coletivo |

## 4. Descobertas ESTRUTURAIS

- **Duas classes de inimigo:** perna longa adversa (em zona: 49% de ciclos longos, -742/ciclo) e whipsaw curto (54% dos ciclos, -2.066/ciclo). O veto mata a primeira; nada atual preve a segunda.
- **Concentracao:** os 10% melhores ciclos somam +15,4M pts; os 90% restantes, -16,1M. O olho amostra a cauda; o CSV conta tudo.
- **Duracao x resultado (M5, liquido/ciclo):** <=30min: -2.066 | 31-60min: +1.293 | >60min: +3.257. Alvo = perna longa NA DIRECAO.
- **Custo por TF (pedagio/movimento tipico):** M1 ~14% | M5 ~6% | M15 ~4%. Materia-prima: 12,6x (M1) a 101x (H1) o custo em MFE.
- **Sessao:** NY mais fraca no ouro (medMFE15B 2.594 vs Asia 3.844) — candidato a veto secundario, nao validado.
- **Spread real:** mediana 260 pts, p10 240 (regua de viabilidade: mediana MFE >= 520-780 pts).

## 5. FILA pre-registrada (ordem)

1. **Rodada SIG_SP** (M5, jan->ago, v1.08). Criterio de "promissor": assimetria15 positiva em OOS **e** IS, >= +1x spread no agregado. Fatias pre-registradas: interacao com zona (re-derivar, nao herdar) e razao MFE30/MFE15 vs baseline TMO (previsao do ciclo longo). n esperado: centenas — veredito sera promissor/nao, nunca "validado".
2. **Caca ao whipsaw** (rodada TMO v1.08): posicao de nascimento (m1 x dir) e profundidade (histograma) — simular offline "um sinal por perna" e MinCross.
3. **Motor de saida** (onde assimetria vira dinheiro): corte rapido por MAE, time-stop de estagnacao, trailing (Trailing_Engine.mqh, 6 ancoras); histograma pico-e-encolhe como sensor de aperto (hipotese).
4. Barra-1 (+0.294, validado noutro contexto) e sessao como vetos secundarios.
5. S/R via fractais do SP (familia de informacao nova).
6. **Dukascopy** se algo passar de "promissor": anos de historico, coluna de proveniencia, spread da Exness por cima.

## 6. Regras aprendidas (custo alto — nao repetir)

- **Indicador consumido via iCustom NAO usa `input group`** (desalinha parametros posicionais; sintomas: M7, TMOLen=2, zero sinais).
- Assinatura de versao + eco de parametros no OnInit de todo programa (prova de identidade no log).
- `tester_indicator` obrigatorio quando o nome vem de input.
- Relogio de gate = time_msc do tick (mercado), nunca GetTickCount (maquina).
- CSV nomeado pela data de INICIO: renomear antes de re-rodar o mesmo periodo.
- FILE_COMMON grava em Terminal\Common\Files, nao na pasta do terminal.
- MFE = excursao maxima, nao lucro. Longo != bom (perna longa adversa existe).
- Toda hipotese: OOS separado, mensal, pre-registro. Achado sem isso = pesca.
