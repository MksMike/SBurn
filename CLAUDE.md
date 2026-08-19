# CLAUDE.md — Projeto SBurn
**Versao:** 4.0 | **Atualizado:** 2026-08-18
Leia por completo antes da primeira acao. Em conflito, este arquivo vence.

---

## 0. O que e' o projeto

Pesquisa empirica de sistemas de trading para **XAUUSDm** (ouro) no MetaTrader 5.
O objetivo NAO e' "fazer um EA que lucre no backtest". E' **descobrir, com medicao
honesta, onde existe e onde nao existe vantagem estatistica** — e so' entao construir.

Interlocutor: Mike, dev MQL5, PT-BR, no Japao.
**Responder em portugues do Brasil. Comentarios de codigo em portugues SEM acentos.**

---

## 1. Regras de conduta (R1-R7)

**R1 — Nenhum parametro sem medicao.** Todo valor ou vem de medicao documentada, ou
e' input marcado `NAO CALIBRADO`. Chutar parametro e' a falha mais grave aqui.

**R2 — Hipotese antes do teste.** Escrever o que se espera e qual criterio decide,
ANTES de rodar. Sem pre-registro, padrao encontrado e' pesca.

**R3 — Zero distorcao silenciosa.** Nunca arredondar a favor, omitir limitacao de
metodo ou apresentar numero sem ressalva. Erro do assistente: assumir explicitamente.

**R4 — Critica direta.** Contraditorio, nao validacao. Resultado negativo
documentado vale tanto quanto achado positivo.

**R5 — Checkpoint.** Etapas verificaveis; ao fim de cada uma dizer o que foi feito,
o que ficou pendente e o proximo passo.

**R6 — Anti-scope-creep.** Antes de criar algo novo: isso mede o que os sensores
atuais NAO medem? Ferramenta nova so' entra depois que o existente foi medido.

**R7 — Medir antes de construir.** Toda ideia vira primeiro coluna no EA de medicao
e passa pelo tribunal. So' o que passa vira codigo operacional. Ja' evitou dois EAs
perdedores (contra-trade pos-BE e cruzamento de medias).

---

## 2. Ambiente de desenvolvimento

### Estrutura do repositorio

O repositorio ESPELHA o caminho da pasta de dados do MT5. O que esta' escrito no
cabecalho de cada arquivo (`PASTA: <PastaDeDados>\MQL5\...`) e' literalmente o
caminho dele dentro do repositorio.

    C:\dev\SBurn\                              <- raiz do repositorio git
      CLAUDE.md
      README.md
      .gitignore
      .gitattributes                           <- * -text (congela os bytes)
      .vscode\                                 <- settings, extensions, task de compilacao
      MQL5\
        Indicators\SBurn\  S-Ind-*.mq5         -> junction para o MT5
        Experts\SBurn\     S-EA-*.mq5          -> junction para o MT5
        Include\SBurn\     S-Include-*.mqh     -> junction para o MT5
      analise\             S-Py-*.py
      setup\               S-Ps-*.ps1          <- parametrizacao de maquina
      docs\                S-Doc-*.md
      dados\               CSVs (nao versionados)

### Parametrizacao de maquina (uma vez por PC)

    powershell -ExecutionPolicy Bypass -File setup\S-Ps-Setup_Maquina.ps1

O script acha a pasta de dados do terminal EXNESS pelo `origin.txt` (o hash da
pasta vem do caminho de instalacao — nunca chutar), cria o alias
`C:\MT5\Exness` -> pasta de dados e os 3 junctions (`Indicators\SBurn`,
`Experts\SBurn`, `Include\SBurn`) apontando para dentro do repositorio, e
verifica. Idempotente; `mklink /J` NAO exige administrador.

O alias existe para que arquivo VERSIONADO nao carregue nome de perfil do Windows:
`.vscode\settings.json` e `tasks.json` apontam para `C:\MT5\Exness\MQL5` em
qualquer PC. **Caminho real de maquina so' aparece em `docs\S-Doc-Maquinas.md`** —
que tambem lista os PCs do projeto e o estado medido de cada um. Antes de confiar
em qualquer numero rodado numa maquina, conferir la' a secao dela.

Para REMOVER um junction use `cmd /c rmdir "<caminho>"` (sem `/s`): apaga so' o
link. `Remove-Item -Recurse` do PowerShell SEGUE o link e apaga os fontes.

### Convencao de nomes (o nome diz onde instalar)

| Prefixo | Destino | Compila? |
|---|---|---|
| `S-Ind-*.mq5` | `MQL5\Indicators\SBurn\` | Sim (F7), primeiro |
| `S-EA-*.mq5` | `MQL5\Experts\SBurn\` | Sim (F7), por ultimo |
| `S-Include-*.mqh` | `MQL5\Include\SBurn\` | Nao |
| `S-Py-*.py` | `analise\` | — |
| `S-Ps-*.ps1` | `setup\` | — |
| `S-Doc-*.md` | `docs\` | — |

Todo arquivo leva no cabecalho: pasta de instalacao, se compila, e a assinatura que
imprime no log.

### Git

- Nao versionar: `*.ex5`, `*.log`, `dados/*`.
- Commit por unidade logica; mensagem `tipo(escopo): descricao`.
- Toda mudanca de comportamento sobe o `#property version` e ganha entrada no
  CHANGELOG do cabecalho do proprio arquivo.

---

## 3. Contexto operacional (nao re-descobrir)

| Item | Valor |
|---|---|
| Simbolo | XAUUSDm, Exness Standard, servidor Exness-MT5Real41 |
| Digitos | **3** (point = 0.001); 1 ponto com 0.01 lote = **$0.001** |
| Spread real | mediana **260 pts**, p25 240, p75 280, p90 360 |
| Conta | JPY, hedging |
| Pasta de dados MT5 | alias `C:\MT5\Exness\MQL5` (junction por maquina) |
| CSV de saida | `...\MetaQuotes\Terminal\`**`Common`**`\Files\SBurn\` (pasta IRMA) |
| Maquinas | ver `docs\S-Doc-Maquinas.md` (PC-Escritorio = `MIKE-PC`) |
| **Tick real Exness** | **so' a partir de 2026.01** |

**Backtest so' com "Every tick based on real ticks".** O desenho e' path-dependent
(63% dos trades saem pelo breakeven, que depende do caminho intrabar): qualquer teste
antes de 2026.01 e' **invalido**, nao apenas impreciso. Assinaturas de tick simulado:
spread com poucos valores distintos (3 vs 8), derrapagem no BE proxima de zero, P&L
repetido em muitos trades.

---

## 4. Padroes de medicao

- **Entrada A** = bid do 1o tick da barra seguinte ao sinal.
- **Horizontes** = 5/15/30 **barras do TF do grafico**.
- **Assimetria** = medMFE − medMAE. Condicao necessaria, nao suficiente.
- **MFE e' excursao maxima, nao lucro.**
- **Promocao:** positivo em OOS **e** IS, com estabilidade mensal. Meses, nao anos
  = "promissor", nunca "validado".
- **Teste do descartado:** o valor de um filtro e' o desempenho dos trades que ele
  REMOVE. Se o descartado rende bem, o filtro so' joga lucro fora.
- **Vies de selecao:** filtro que "olha" uma barra paga essa barra no preco de
  entrada. Simular sempre com preco exato de saida.
- **Ordem importa:** MFE/MAE dizem o QUE aconteceu, nunca em QUE ORDEM. "88% dos
  casos alcancam 1 ATR" nao e' "chegam la antes do stop" (foram 36%).

---

## 5. Estado empirico

### 5.1 A estrategia validada (titular)

**Entrada:** pullback do ScalpPullback no M5 (buffer 26, barra fechada) COM o regime
do SP no M30 (buffer 27) concordando.
**Saida:** stop 3,67xATR(14); ao lucro atingir 0,73xATR o stop vai para o **nivel BID
da entrada** (degrau ZERO); qualquer sinal novo do SP fecha.
**Filtros:** histograma do TMO |main-signal| < 2,20 e spread <= 260.

Backtest real, ticks reais, 2026.01.01-08.12, 0.01 lote:

| Config | n | media$ | total$ | DD$ | ret/DD | PF |
|---|---|---|---|---|---|---|
| sem filtros | 370 | +3.15 | +1163.82 | 206.33 | 5.6x | 2.06 |
| + histograma | 247 | +4.75 | +1173.88 | 157.57 | 7.5x | 2.69 |
| **+ histograma + spread** | **137** | **+9.55** | **+1308.59** | **49.25** | **26.6x** | **5.83** |

Perfil: ~63% scratch (-$0.50), ~25% ganho (+$32), ~12% stop (-$20). Duracao mediana
35 min. Stop mediano 20.077 pts ($20); BE arma em 3.993 pts ($4).
**Status: promissor, NAO validado.** 137 trades em 8 meses.

### 5.2 O problema aberto: participacao

A estrategia fica no mercado **9% do tempo** e participa de **31%** do movimento
direcional que ela mesma identifica (captura 1,24M pts; perde 2,79M enquanto fora).
Apos um scratch o preco retoma a direcao original em **71%** dos casos (~10.000 pts);
apos um stop, **83%** (~17.000 pts). Nada no momento do scratch prediz isso (MFE,
duracao, ATR: 66-77%, rho ~0,1).

Reprovado: reentrada por rompimento do extremo (stop sobe de 8% para 20%; ret/DD cai
de 26,6x para 21,4x), com ou sem filtro de expansao de ATR, com 1 ou 3 reentradas.

**Aprovada no lugar dela — R2, "range congelado no esgotamento"** (v2.00 do EA):
apos o scratch o EA acompanha o recuo; quando o preco para de fazer extremo adverso
novo por `InpR2Calma` barras, CONGELA o topo do range formado desde o scratch, e a
reentrada dispara no rompimento desse topo. E' confirmacao de ESTADO, nao relogio —
coerente com a lei 1. Medido: **+19% de lucro, ret/DD de 8,8x para 9,1x**.

**Piramide (v2.00/v2.01) — estrategia SECUNDARIA, magic e lote proprios. LIGADA
por padrao desde a v2.04** (era desligada; ver o bloco de 2026-08-19 abaixo).
Adiciona posicoes conforme o movimento anda a favor, cada uma com BE e stop
proprios. Inicio em 1,0xATR: +64% de lucro mas ret/DD de 9,1x para 6,3x. A v2.01
separou ONDE comeca de QUAL o espacamento: inicio 2,0xATR da' $2.333 / DD $226 /
ret/DD 10,3x contra $2.279 / DD $360 / 6,3x do inicio 1,0 — otimo NO MEIO da grade,
com queda dos dois lados (assinatura de estrutura, nao de pico de sobreajuste).

> **Procedencia destes tres blocos:** vieram do CHANGELOG do proprio
> `S-EA-Pullback_Live` v2.00/v2.01, **nao foram re-verificados**. As bases nao sao a
> mesma da tabela 5.1 (26,6x): sao outra janela/config. O proprio changelog registra
> que a medicao vem saindo OTIMISTA contra o backtest real — com inicio 1,0 projetou
> DD $360 e a execucao deu $509. Tratar como **hipotese medida**, nao como validado.

> **INVALIDADO em 2026-08-18 — todo numero de piramide acima foi medido na v2.01,
> com o bug `[B14]` ATIVO.** O `[B14]` fazia o breakeven de uma adicao mover o stop
> de OUTRA adicao, e deixava a adicao certa sem BE nenhum. Numero de piramide medido
> antes da v2.02 **nao descreve o codigo atual** e nao da' para inferir o sinal da
> correcao sem rodar: BE na posicao errada tanto pode ter protegido cedo demais
> quanto tarde demais. Vale o mesmo para o backtest de `InpPirEnabled=true`
> registrado como $2.195,53 / DD $324,04 / PF 4,69 / 227 operacoes.
> **Re-medir na v2.02 antes de citar qualquer um deles.**
> O controle `InpPirEnabled=false` ($1.494,35 / DD $187,34 / PF 4,85 / 160
> operacoes) **continua valido**: `[B14]` e `[B15]` vivem inteiramente dentro do
> caminho da piramide, que fica dormente no default.

> **RESOLVIDO em 2026-08-19 — o `[B14]` nunca mudou numero nenhum.** Medido, nao
> deduzido: v2.01 e v2.02 dao o mesmo saldo final (12616.32) no log de 2026-08-18,
> e v2.02 e v2.03 dao o mesmo (12617.25) hoje. O log da rodada v2.02 tem **zero**
> linhas de "NAO identificada" — a busca por `DEAL_POSITION_ID` acertou o ticket
> nas 106 adicoes, e nenhuma rodou sem breakeven. As "234 falhas" eram 234
> rejeicoes `10018 market closed` de um unico dia (2026.01.06), contadas a cada
> tick. A v2.03 separou os contadores (`rejeitadas` / `sem_ticket`).
>
> **Numero corrente, medido na v2.03 e reproduzido pela v2.02** — XAUUSDm M5,
> 2026.01.01-**08.18**, ticks reais 100%, 0.01 lote, C_HIST:
>
> | Config | Lucro | DD capital | PF | Negociacoes | Fator de recuperacao |
> |---|---|---|---|---|---|
> | piramide ON | $2.617,25 | $426,52 | 4,63 | 254 | 6,14 |
> | so' a principal | $1.387,20 | $187,34 | 4,64 | 148 | 7,40 |
>
> +$1.230,05 de lucro por +$239,18 de DD: ~5,1x na margem, contra 7,4x da
> principal. **Decisao do Mike em 2026-08-19: ligar por padrao** (v2.04), com o
> trade-off na mesa. Segue **hipotese medida, nao validada** — 8 meses, e a janela
> inclui 2026.01, que ainda carrega a ressalva da armadilha 13.

**Em aberto:** `SIG_PBSHALLOW` (pullback raso dentro do regime, sem exigir retorno ao
canal PAC) — implementado no EA de medicao v1.20, **ainda nao rodado**.

### 5.3 Filtros — o que agrega

| Filtro | Descartados rendem | t | Veredito |
|---|---|---|---|
| Histograma TMO nao-profundo | -$0.08 | +2.06 | **usar** |
| Spread <= 260 | -$0.54 | — | **usar** (99% e' condicao de mercado, nao custo) |
| Confluencia MTF do TMO | **+$2.86** | +0.62 | nao usar — joga lucro fora |
| Veto de zona (OB/OS) | — | — | validado, mas redundante (sinais do SP nascem 100% fora de zona) |

### 5.4 Hipoteses MORTAS (nao re-testar)

TMO-cruzamento como gatilho (assimetria ~0 em 5 TFs) · SAR cruzamento-a-cruzamento
(-2,34M pts em 8 meses) · MovConsistency como filtro de entrada (rho +0,042) ·
SP trendDir como regime para o TMO (OOS -154 / IS -306) · prove-it barra 5 ·
barra-1 como regra (-$422/trade; o calculo ingenuo dava +2.880 — vies de selecao) ·
TP por quantil e parcial · trailing (4 distancias + modulacao ATR; familia dominada) ·
degrau de BE acima de zero (+0,05xATR custa 1.700 pts/trade) · folga de BE abaixo de
zero (grade 4x5: o zero e' o maximo) · contra-trade pos-breakeven (0 de 12
combinacoes) · MACROSS/cruzamento PAC x EMAs (-2.972/trade, 8/8 meses negativos) ·
osciladores primos (MACD/RSI/TrendWave) · USDJPY (assimetria -0,251 ATR).

### 5.5 Leis empiricas

1. **Evento de mudanca nao tem direcao; ESTADO tem.** Cinco confirmacoes.
2. **Proteger ajuda; limitar destroi.** BE no zero e' otimo global: degrau acima poda
   a cauda, folga abaixo aumenta a perda. 10% dos ciclos somam +15,4M pts; os outros
   90% somam -16,1M.
3. **Filtro e' bom ou ruim PARA UM EVENTO**, nunca em abstrato.
4. **A volatilidade do ouro paga a conta.** Custo/ATR: XAUUSD 4,8% vs USDJPY 23,1%.
5. **O olho amostra a cauda; o CSV conta tudo.**

---

## 6. Armadilhas conhecidas (custaram caro)

1. **`input group` + `iCustom` = desalinhamento posicional.** Indicador consumido por
   EA NAO pode ter `input group`. Sintomas: erro `M7`, `TMOLen=2`, zero sinais.
2. **Assinatura obrigatoria:** todo programa imprime versao + eco dos parametros no
   `OnInit`.
3. **`#property tester_indicator`** quando o nome do indicador vier de input.
4. **`BarsCalculated` NAO forca o calculo** de indicador de outro timeframe — quem
   forca e' `CopyBuffer`. Usar como portao antes de qualquer CopyBuffer = DEADLOCK
   silencioso (zero trades, nenhum erro no log).
5. **O tester GUARDA os inputs da rodada anterior.** Ja' causou 3 rodadas erradas.
   Mitigacao: um unico enum seletor por EA.
6. **Ao aplicar patch, verificar que o GRAVADOR mudou.** Cabecalho de CSV declarando
   colunas que o `WriteRec` nao grava = 3 rodadas perdidas.
7. **CSV nomeado pela data de inicio** -> re-rodar o mesmo periodo sobrescreve.
8. **`FILE_COMMON` grava em `Terminal\Common\Files`.**
9. **SL de VENDA dispara no ASK; de COMPRA no BID.** A medicao define tudo sobre o
   BID: niveis de venda somam o spread.
10. **Filtro de conveniencia na analise e' selecao disfarcada.** `gap<=3000` e
    `cyc_bars>0` inflaram a medicao em 26% vs o backtest real.
11. **Refatorar codigo validado e' a atividade de maior risco.** Sempre reproduzir o
    resultado anterior apos refatorar.
12. **Buffer de sensor acoplado a input visual.** Corrigido no TMO (B8) e no
    ScalpPullback v2.02 (B4): buffers sempre calculados, visibilidade por
    `PLOT_DRAW_TYPE`.
13. **Tick "real" do broker pode vir com spread CARIMBADO.** Medido em 2026-08-18
    no XAUUSD da Exness-MT5Real3: 2026.01 tem 99,7% dos ticks em exatamente 37
    pts e **5 trocas de spread em 2M ticks ao longo de 4 dias**, contra 26.104
    trocas/1M no mes seguinte. Com spread constante o custo intrabar nao varia e
    o BE nunca derrapa: backtest path-dependent nesse periodo e' **invalido**.
    Contar valores DISTINTOS nao detecta isso — spread quantizado real tambem da'
    poucos valores. O teste e' **trocas por milhao de ticks**, e ele roda em
    `analise\S-Py-Perfil_Spread.py`. **Verificar todo periodo novo antes de usar**,
    inclusive os que ja' passaram por rodada anterior.

---

## 7. Fila

**ABERTO, ADIADO por decisao do Mike em 2026-08-18** — nao e' bloqueio, e' ressalva
que anda junto do numero: rodar o teste de trocas/1M (`S-Py-Perfil_Spread.py`)
sobre os ticks de **XAUUSDm** em 2026.01. A armadilha 13 foi medida no XAUUSD da
Real3, onde janeiro entregou 47% do lucro com 17% dos trades. Se o mesmo defeito
estiver no XAUUSDm, o resultado de referencia (137 trades, +$1.308,59, janela
2026.01.01-08.12) inclui um mes invalido e precisa ser re-medido em 2026.02-08.

**Enquanto nao for respondido:** o desenvolvimento segue normalmente sobre a
referencia atual, mas **todo numero cuja janela inclua 2026.01 carrega essa
ressalva** — inclusive comparacoes entre candidatos, que herdam o mesmo mes.
Comparacao entre configuracoes na MESMA janela continua valida (o vies e' comum
as duas); o que nao vale e' tratar o nivel absoluto como medido.
Ver `docs\S-Doc-Spread_Contas.md`.

1. **Rodar `SIG_PBSHALLOW`** (EA de medicao v1.20) — 4 configuracoes + 1 controle.
   Objetivo: mais trades/dia sem perder qualidade.
2. **Estrutura de mercado** (`est_micro`/`est_macro`/`est_acordo`, ja' gravadas pelo
   v1.20) — medir cada componente ISOLADO. Voto ponderado so' depois: peso e'
   parametro, e parametro sem medicao viola a R1.
3. **Modulo de dados historicos (Dukascopy)** — 4 anos, base universal reutilizavel,
   custom symbol no MT5, coluna de **proveniencia** por periodo e modelo de spread da
   Exness por cima. Unica forma de validar em anos.
4. **StressLab** — slippage, spread elevado e latencia sobre a base historica.
5. **Antes de conta real:** trava de simbolo/TF, limite de perda diaria, CSV em modo
   append (`FILE_WRITE` trunca e perde historico se o terminal reiniciar), sizing em
   JPY (o stop escala com ATR: p90 = 2x a mediana).
6. **Conta Raw/Zero:** ganho direto ~5%; recalibrar o filtro de spread para termos
   RELATIVOS (percentil ou multiplo de ATR), senao nunca dispara.

**Nao fazer:** varrer timeframes antes de ter desenho validado; testar osciladores da
mesma familia; re-testar a lista de mortos; OOP antes de existir uma segunda
estrategia que compartilhe codigo.
