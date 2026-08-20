# CLAUDE.md — Projeto SBurn
**Versao:** 5.0 | **Atualizado:** 2026-08-19
Leia por completo antes da primeira acao. Em conflito, este arquivo vence.

---

## 0. O que e' o projeto

Pesquisa empirica de sistemas de trading para **ouro** (XAUUSD e variantes) no
MetaTrader 5. O objetivo NAO e' "fazer um EA que lucre no backtest". E' **descobrir,
com medicao honesta, onde existe e onde nao existe vantagem estatistica** — e so'
entao construir.

### O projeto e' PORTAVEL por desenho (decisao do Mike, 2026-08-19)

**O sistema tem de operar em qualquer corretora e em qualquer tipo de conta**
(Standard, Raw, Zero, Pro). Isso nao e' um objetivo futuro: e' criterio de aceite
de tudo que se escreve aqui, e vira a regra **R8**.

Consequencia imediata: **nenhum parametro absoluto amarrado a uma conta pode ser
default.** Hoje o EA falha nisso em dois pontos medidos — `InpMaxSpread=260`
(numa conta Raw, cujo spread mediano e' 90, ele nunca morde: PF cai de 7,41 para
1,80 e o drawdown multiplica por 8) e o **degrau ZERO do breakeven**, que ignora o
custo e por isso e' estruturalmente um prejuizo de um spread por scratch.

A resposta e' **auto-configuracao por conta**: um script identifica corretora,
servidor, conta e tipo, varre o historico DAQUELA conta, mede spread e comissao,
e calibra o que depende de conta — inclusive o degrau do breakeven, para que sair
no BE nao seja prejuizo. Especificacao completa, com o conflito medido que ela
precisa resolver, em **`docs\S-Doc-Portabilidade.md`**. Nada disso esta
implementado.

Interlocutor: Mike, dev MQL5, PT-BR, no Japao.
**Responder em portugues do Brasil. Comentarios de codigo em portugues SEM acentos.**

---

## 1. Regras de conduta (R1-R8)

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

**R8 — Portabilidade por desenho.** O sistema tem de rodar em qualquer corretora e
qualquer tipo de conta. Nenhum default pode ser um valor absoluto valido so' numa
conta. Todo parametro e' (a) adimensional — multiplo de ATR, barras, percentil —,
ou (b) **derivado por medicao do historico da conta em uso**, nunca fixado no
codigo. Custo (spread + comissao) e' variavel de conta, jamais constante do
projeto. Um parametro absoluto nao falha com erro: falha em silencio, e o filtro
de spread ja' mostrou como. Ver `docs\S-Doc-Portabilidade.md`.

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
      analise\             S-Py-*.py  S-Ref-*.json
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
| `S-Ref-*.json` | `analise\` | — (artefato de medicao GERADO, nunca digitado) |

Todo arquivo leva no cabecalho: pasta de instalacao, se compila, e a assinatura que
imprime no log.

### Git

- Nao versionar: `*.ex5`, `*.log`, `dados/*`.
- Commit por unidade logica; mensagem `tipo(escopo): descricao`.
- Toda mudanca de comportamento sobe o `#property version` e ganha entrada no
  CHANGELOG do cabecalho do proprio arquivo.

---

## 3. Contexto operacional (nao re-descobrir)

> **Sob a R8, esta secao mudou de natureza.** Ela NAO lista constantes do projeto:
> lista **a conta em que se mediu ate' aqui**. Todo valor marcado *(de conta)* e'
> uma medicao daquela conta e tem de ser re-medido em qualquer outra. Quem faz
> isso e' a auto-configuracao (`docs\S-Doc-Portabilidade.md`), ainda nao escrita.

| Item | Valor |
|---|---|
| Simbolo medido | XAUUSDm (ouro; o desenho nao e' especifico deste sufixo) |
| **Servidor que produziu as medicoes** | **`Exness-MT5Trial5` — servidor de DEMO** |
| Servidor que a doc declarava | `Exness-MT5Real41` (Standard real) — **so' tem 202608 baixado** |
| Digitos | **3** (point = 0.001); 1 ponto com 0.01 lote = **$0.001** *(de conta)* |
| Spread | mediana **260 pts**, p25 240, p75 280, p90 360 *(de conta — Trial5)* |
| Comissao | **NAO medida.** Zero e' suposicao, nao dado *(de conta)* |
| Conta | JPY, hedging *(de conta)* |
| Pasta de dados MT5 | alias `C:\MT5\Exness\MQL5` (junction por maquina) |
| CSV de saida | `...\MetaQuotes\Terminal\`**`Common`**`\Files\SBurn\` (pasta IRMA) |
| Maquinas | ver `docs\S-Doc-Maquinas.md` (PC-Escritorio = `MIKE-PC`) |
| **Tick utilizavel (Trial5)** | **2026-01-30 em diante.** A linha antiga dizia "so' a partir de 2026.01" e foi ELA que autorizou usar janeiro. O caminho do BID e' defeituoso ate' 2026-01-29 (ver armadilha 13). Corta-se em 2026.02.01 por conveniencia: refinar ganha 1 pregao. |

> **DESCOBERTO em 2026-08-19:** todas as medicoes do projeto rodaram contra
> `Exness-MT5Trial5`, um servidor de **demo**, e nao contra o `Exness-MT5Real41`
> que esta secao declarava. Prova: o cabecalho de todo relatorio do tester diz
> `Exness-MT5Trial5 (Build 6090)`, o log do terminal diz `demo account`, e
> `bases\Exness-MT5Trial5	icks\XAUUSDm\` tem 202601..202608 (87 a 31 MB)
> enquanto `bases\Exness-MT5Real41	icks\XAUUSDm\` tem **so' 202608, 0,6 MB**.
> Consequencia: a mediana de spread de 260 e' a do Trial5. Sob a R8 isso deixa de
> ser um problema a corrigir e passa a ser o caso de uso normal — mas **tem de
> estar declarado**, e estava errado.

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

> **A tabela abaixo foi APOSENTADA em 2026-08-19**: a janela dela comeca em
> 2026.01.01, e 2026-01 esta reprovado (armadilha 13). Janeiro respondia por 49%
> dos trades e 44% do lucro — nao por render mais (rende MENOS: $8,47/trade contra
> $10,26), mas porque o spread carimbado em 160 fazia **100%** dos sinais dele
> passarem o filtro `<=260`. Fica registrada como historico.

| Config (janela INVALIDA 2026.01.01-08.12) | n | total$ | DD$ | ret/DD | PF |
|---|---|---|---|---|---|
| sem filtros | 370 | +1163.82 | 206.33 | 5.6x | 2.06 |
| + histograma | 247 | +1173.88 | 157.57 | 7.5x | 2.69 |
| + histograma + spread | 137 | +1308.59 | 49.25 | 26.6x | 5.83 |

**REFERENCIA CORRENTE — janela valida 2026.02.01-08.18**, XAUUSDm M5 @ Trial5,
100% ticks reais, 0.01 lote, piramide off:

| Config | n | total$ | DD saldo$ | PF | Fator de recuperacao |
|---|---|---|---|---|---|
| sem filtros | 477 | +853.32 | 284.71 | 1.54 | 2.08 |
| + histograma (sem filtro de spread) | 301 | +719.23 | 196.06 | 1.80 | 1.75 |
| **+ histograma + spread <= 260** | **76** | **+777.23** | **23.37** | **7.41** | **4.15** |

O desenho sobrevive — os dois filtros levam o PF de 1,54 a 7,41 — mas **a magnitude
era metade janeiro**. Repare tambem na **lei 3 em acao**: sem o filtro de spread o
histograma PIORA o lucro ($853 -> $719); com ele, melhora ($738 -> $777).

> **CORRECAO (R3) — eu apresentei a exclusao de janeiro como degradacao e ela nao
> e'.** `1387,20/7,40 = $187,46` e `777,23/4,15 = $187,28`: as duas razoes dividem
> pelo **mesmo** drawdown. O pior rebaixamento de capital da janela mora inteiro em
> fev-ago. Excluir janeiro tirou **$609,97 de lucro e $0,06 de risco**. Na curva de
> trades fechados a direcao **se inverte**: ret/DD 19,27 -> **32,92**, PF 4,62 ->
> **7,34**, media/trade $9,38 -> **$10,26**. A exclusao **melhorou** todo indicador
> de qualidade. O que ela custou foi AMOSTRA, nao desempenho — ela corrigiu
> procedencia, nao otimismo de nivel.

**Status: promissor, NAO validado, e a amostra e' pior condicionada do que o "76"
sugere. Publicar sempre com a concentracao na manchete:**

- **abril e maio: ZERO operacoes** (o corte absoluto de 260 barra 100% dos sinais;
  mediana do mes 308). Marco: 2. Julho: 40 de 76 (**53%**), e e' o pior mes por
  trade ($3,42).
- **tres dias fazem 61% do lucro**; um unico trade (2026.03.19) rende $267,14 =
  34,7% do total.
- A estabilidade mensal que a secao 4 exige para promocao **nao existe**.
- **Excluir janeiro mantendo o corte 260 tira da amostra os meses de tendencia
  forte** — exatamente o regime que a estrategia captura. Todo veredito tirado
  desta janela herda esse vies. Por isso a grade de `InpMaxSpread` vem ANTES de
  qualquer veredito novo (fila).

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
> principal. **Decisao do Mike em 2026-08-19: ligar por padrao** (v2.04).
>
> **RE-MEDIDO no mesmo dia, na janela VALIDA (2026.02.01-08.18):**
>
> | Config | Lucro | DD capital | PF | Negoc. | Recuperacao |
> |---|---|---|---|---|---|
> | so' a principal | $777,23 | $187,34 | 7,41 | 76 | **4,15** |
> | + piramide | $962,49 | $426,52 | 4,25 | 141 | **2,26** |
>
> Na margem: **+$185,26 de lucro por +$239,18 de DD = 0,77x.** Marginal ON-OFF por
> mes: **jan +1.044,79** | fev +3,35 | mar -0,57 | jun -34,43 | jul +69,51 |
> ago +147,40. **Janeiro sozinho e' 84,9% de toda a evidencia que ligou a
> piramide** — e o DD extra ($239,18) e' IDENTICO nas duas janelas: o risco dela
> esta fora de janeiro, o lucro dela esta dentro.
>
> **Ha causa medida, nao so' correlacao.** Cada adicao morre quando o preco encosta
> de volta no proprio nivel de entrada dela; o caminho do BID de janeiro e'
> anomalamente liso (armadilha 13), entao a adicao nao encosta. Medido na simulacao
> **BID-pura** do EA de medicao (colunas `pir_b*`, zero spread): adicao a 3,0xATR
> nunca volta ao nivel em **29,5% em janeiro contra 18,1% no resto** (OR 1,90,
> p=0,011). *Ressalva: a 2,0xATR o efeito NAO sobrevive a deduplicacao — 25,6%
> contra 20,9%, p=0,135.* Ou seja: janeiro nao e' amostra a favor da piramide, e'
> **anti-evidencia** — o defeito de dado premia exatamente o mecanismo que ela
> monetiza.
>
> **Decisao: default revertido para `false` na v2.05** (2026-08-19).
> **Status: INDECIDIVEL, nao "reprovada"** — 65 adicoes em 5 meses efetivos, dois
> deles com zero operacao. E o numero vem do relatorio do MT5: o gravador filtra
> por `InpMagic` e **nao escreve as pernas da piramide**, entao `ops_pirON.csv` e
> `ops_pirOFF.csv` sao byte-identicos. Efeito colateral util: esta **provado** que
> ligar a piramide nao altera um unico trade da principal.

**`SIG_PBSHALLOW`: RODADO em 2026-08-19** — 4 configuracoes + controle,
pre-registro em `docs\S-Doc-PreReg_PBSHALLOW.md`. A frequencia sobe de verdade
(3,3x a 5,1x sinais/dia), mas a assimetria desaba.

| | assim30 janela cheia | s/ janeiro | IC95 (s/ jan) | P(assim>custo) |
|---|---|---|---|---|
| P1 | 329 vs custo 260 | 207,5 vs 280 | [-899, +1.320] | 0,55 -> **0,44** |
| P2 | -108 | -284 | — | 0,25 -> 0,12 |
| P3 | -219 | -482 | — | 0,17 -> 0,16 |
| P4 | -476 | -644,5 | — | 0,09 -> 0,07 |

**P2, P3 e P4: REPROVADOS**, robustamente, nas duas janelas. **P1: INDECIDIVEL**,
nao reprovado — cara ou coroa nas duas. Eu escrevi "4 de 4" e isso e' **precisao
falsa (R3)**: o veredito do P1 vira conforme o mes que se tira, e o proprio
criterio se moveu junto (o custo mediano do arquivo sobe de 260 para 280 quando
janeiro sai — **a trave andou com a medida**). Para escala: a assimetria30 mensal
varia de -2.975 (abr) a +1.916 (jun), ~10x o efeito de janeiro.

**A H0 do pre-registro — "o canal PAC nao e' burocracia, e' o que separa recuo de
reversao" — sai confirmada de forma FRACA, nunca refutada.** P1 exige OOS, nao
outro recorte da mesma janela.

### 5.3 Filtros — o que agrega

| Filtro | Descartados rendem | t | Veredito |
|---|---|---|---|
| Histograma TMO nao-profundo | -$0.08 | +2.06 | **usar** |
| Spread <= 260 | -$0.54 | — | **RESSALVADO em 2026-08-19 — ver abaixo** |
| Confluencia MTF do TMO | **+$2.86** | +0.62 | nao usar — joga lucro fora |
| Veto de zona (OB/OS) | — | — | validado, mas redundante (sinais do SP nascem 100% fora de zona) |

> **O achado mais incomodo de 2026-08-19.** O teste do descartado do filtro de
> spread, refeito **so' na janela valida** (CTRL, fev-ago): mantidos assimetria30
> = **1.428** (n=210), descartados = **1.710** (n=358), Mann-Whitney **p=0,431**;
> `spearman(spread, assimetria30)` rho = -0,050 (p=0,239). **Sem janeiro, o filtro
> que sustenta a melhor configuracao ja' medida nao tem valor de selecao
> detectavel — e os descartados sao, se algo, marginalmente melhores.**
>
> A linha "99% e' condicao de mercado, nao custo" foi medida numa janela em que
> janeiro dominava o lado MANTIDO **com o filtro inerte** (aprovava 100% la'). Ela
> precisa de re-medicao antes de continuar sendo citada. Isso e' mais grave que a
> propria exclusao de janeiro: poe em duvida o filtro que separa a config de 26,6x
> das outras.
>
> **ACRESCIMO DE 2026-08-20 — razao independente, e nao substitui a de cima.**
> Mesmo re-medido, o achado tem **n efetivo perto do numero de MESES, nao dos
> sinais**. Medido nos 568 sinais da janela valida: **64,6% da variancia de
> aceito/rejeitado e' explicada pelo MES** (eta^2); so' 35,4% mora dentro dos
> meses. Taxas de rejeicao mensais: 54 / 96 / 100 / 100 / 56 / 0 / 5%. O filtro
> quase nao seleciona DENTRO do mes — ele liga e desliga meses inteiros, e
> apenas **2 dos 7** (fev, jun) tem os dois grupos com n>=20. Qualquer conclusao
> do tipo "condicao de mercado, nao custo" se apoia em contraste ENTRE MESES com
> ~6 unidades independentes. Continua plausivel; o suporte e' muito menor do que
> 568 sinais sugerem.

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
    **CONFIRMADO no XAUUSDm em 2026-08-19 — mas o criterio que decide NAO e' o
    do spread.** Um teste barato e' contar **valores distintos de spread por mes**
    no CSV do EA de medicao.
    2026-01 @ Trial5 tem **UM unico valor — exatamente 160,0 pts — em 100% dos
    sinais**, nos 25 dias de pregao, em 5 arquivos independentes; os outros 7
    meses tem de 3 a 20. **Um valor unico num mes inteiro e' veredito, nao
    suspeita** — nenhum feed real produz isso. **Mas ele erra nos dois sentidos:**
    julho tem so' 3 valores distintos e 99,7% de aprovacao no filtro, e julho e'
    **BOM**. Quem separa os dois e' o teste abaixo.

    **>>> O CRITERIO QUE DECIDE: passo do BID por tick.** `dist_pts/(n_ticks-1)`
    do `CMovConsistencySensor`, que le `tk.bid` (`InpFeedMid=false`) e **nunca
    toca no ask**. Pool dos 5 CSVs, 5.228 sinais:

    | mes | 01 | 02 | 03 | 04 | 05 | 06 | 07 | 08 |
    |---|---|---|---|---|---|---|---|---|
    | pts/tick | **43,1** | 107,5 | 104,4 | 97,3 | 103,7 | 97,8 | **97,2** | 105,9 |

    Invariante a tudo que se testou: razao jan/resto 0,405-0,437 nos 5 quintis de
    ATR (p de 3e-111 a 6e-72) e 0,387-0,445 nas 23 horas. AUC 0,985. **Densidade
    nao explica**: `spearman(ticks/s, passo)` = -0,020 (p=0,18) dentro da janela
    valida, e no decil mais denso do pool janeiro da' 45,3 contra 104,3 do resto.
    Confirmacao no P&L **imune a spread** (so' COMPRAS, cujo `pnl_pts` independe
    do spread por construcao): derrapagem na saida por BE tem **0 de 36** casos
    acima de 100 pts em janeiro contra **9 de 20 (45%)** no resto; reescalando o
    limiar pela propria densidade, 8% contra 45%, Fisher p=0,0024.

    **TROCAS/1M medido na FONTE em 2026-08-19** (export de ticks do MT5,
    `S-Py-Perfil_Spread.py`), XAUUSDm @ Trial5:

    | mes | ticks | p50 | dominante | **trocas/1M** | veredito |
    |---|---|---|---|---|---|
    | 2026.05 | 3,6M | 280 | 280 = 96,3% | 2.131 | ok |
    | 2026.06 | 8,0M | 260 | 280 = 44,2% | 40.703 | ok |
    | **2026.07** | 6,7M | 240 | 240 = 97,0% | **1.750** | **ok** |
    | 2026.08 | 3,4M | 260 | 260 = 71,0% | 6.225 | ok |

    **Julho esta' VALIDADO e isso importa** — ele e' 53% da referencia atual, e o
    criterio de "valores distintos" (11 valores, 97% num so') o teria condenado.

    E no MESMO dia mediu-se o XAUUSD @ Real3 na janela COMPLETA (13,4M ticks so'
    em janeiro, contra a amostra de 2M/4 dias que gerou o numero antigo):

    | mes | ticks | p50 | **distintos** | dominante | **trocas/1M** |
    |---|---|---|---|---|---|
    | **2026.01** | 13,4M | 37 | **343** | 37 = 99,7% | **178** <- suspeito |
    | 2026.02 | 8,0M | 77 | 178 | 77 = 39,9% | 26.104 |
    | 2026.03 | 12,3M | 137 | 25 | 97 = 42,2% | 9.443 |
    | 2026.04 | 6,8M | 97 | 13 | 97 = 66,9% | 18.219 |
    | 2026.05 | 6,0M | 100 | 9 | 100 = 87,4% | 6.437 |
    | 2026.06 | 8,0M | 90 | 11 | 100 = 44,2% | 40.626 |
    | 2026.07 | 6,7M | 80 | 11 | 80 = 96,9% | **1.745** |
    | 2026.08 | 3,1M | 90 | 10 | 90 = 68,3% | 6.706 |

    **>>> PROVA DEFINITIVA DE QUE A CONTAGEM DE DISTINTOS E' O TESTE ERRADO:**
    2026.01 tem **343 valores distintos — o MAIOR de todos os oito meses** — e e'
    o mes podre. Julho tem **11** e e' bom. O teste de distintos **absolveria
    janeiro e condenaria julho, invertendo os dois vereditos.** Quem separa e'
    trocas/1M: 178 contra mediana de 8.074 (45x abaixo) em janeiro; 1.745 em
    julho. Nao usar contagem de distintos para decidir, nunca.

    Correcao de numero: a armadilha citava "5 trocas em 2M ticks" (2,5/1M) para
    janeiro. Aquilo era amostra de 4 dias; o mes inteiro da' **178/1M**. Continua
    45x abaixo da mediana, continua reprovado — mas o numero certo e' 178.

    **CAMINHO DO BID medido na FONTE** (`S-Py-Perfil_Spread.py` v1.05, secao 4),
    XAUUSD @ Real3, 64,4M ticks — o unico export que alcanca janeiro:

    | mes | passo p50 | **passo p90** | ticks/min | pts/min |
    |---|---|---|---|---|
    | **2026.01** | **40** | **82** | **467,5** | 18.699 |
    | 2026.02 | 87 | 209 | 292,5 | 25.450 |
    | 2026.03 | 79 | 241 | 404,9 | 31.984 |
    | 2026.04 | 68 | 238 | 236,7 | 16.095 |
    | 2026.05 | 66 | 236 | 208,9 | 13.786 |
    | 2026.06 | 61 | 210 | 265,1 | 16.168 |
    | 2026.07 | 60 | 200 | 214,9 | 12.891 |
    | 2026.08 | 65 | 221 | 198,4 | 12.896 |

    Janeiro tem o **mesmo caminho total por minuto** (18.699, no meio da faixa)
    partido em **1,86x mais ticks, cada um muito menor e SEM SALTO** (p90 82
    contra 200-241). Assinatura de tick reconstruido de barra M1: preserva OHLC
    — por isso MFE/MAE e ATR de barra ficam normais — e **inventa o caminho
    intraminuto**, que e' onde o BE e o stop vivem.

    **XAUUSDm 2026.02.17 - 08.19 (v1.05): a JANELA DE REFERENCIA INTEIRA passa,
    nos DOIS canais, no proprio simbolo.**

    | mes | p50 spread | trocas/1M | passo p50 | **passo p90** | ticks/min |
    |---|---|---|---|---|---|
    | 2026.02 (17-28) | 360 | 26.697 | 85 | 275 | 175,2 |
    | 2026.03 | 360 | 9.431 | 79 | 249 | 405,4 |
    | 2026.04 | 280 | 18.278 | 68 | 247 | 236,6 |
    | 2026.05 | 280 | 6.457 | 66 | 238 | 208,7 |
    | 2026.06 | 260 | 40.703 | 61 | 218 | 264,8 |
    | 2026.07 | 240 | 1.750 | 61 | 202 | 214,7 |
    | 2026.08 | 260 | 6.216 | 65 | 230 | 197,4 |

    Referencia p90 = 238; razoes de 0,85 a 1,16. **Zero alertas.** Marco sai como
    nota informativa (405 ticks/min = 1,89x, mas p90 1,05x = salto normal): mes
    movimentado, nao reconstruido — exatamente o falso positivo que a v1.05
    conserta.

    **Consistencia entre dois exports independentes:** os meses 06, 07 e 08
    aparecem nos dois arquivos e dao numeros **identicos** (61/218, 61/202,
    65/230). Maio difere por 1 ponto so' porque o export novo inclui 01-13/05.

    **LACUNA QUE RESTA: 2026.01.01 - 2026.02.16 no XAUUSDm nao tem export.** A
    condenacao de 2026.01 **neste simbolo** segue por INFERENCIA a partir do
    XAUUSD@Real3 — inferencia forte (nos meses sobrepostos os dois feeds sao
    praticamente o mesmo), mas nao medicao. Para fechar: exportar XAUUSDm de
    2026.01.01 a 2026.02.17.
    (O export baixado comeca em 2026-05-14, entao 2026.01 do XAUUSDm ainda nao
    passou por este teste na fonte — segue apoiado no passo do BID e no proxy de
    janelas de 75 ticks.)

    **Assinatura:** o mesmo movimento real partido em ~2x mais passos, ~2,4x
    menores. E' tick RECONSTRUIDO a partir de barra M1 — preserva OHLC (por isso
    MFE/MAE e ATR de barra ficam normais: `vol_eff` p=0,284) e **inventa o caminho
    intraminuto**, que e' exatamente onde o BE e o stop vivem.

    **Consequencia que muda a fila: janeiro NAO e' recuperavel re-precificando.**
    Modelo de spread conserta o ask; nao reconstroi um caminho de BID 2,35x mais
    fino. Item 3 da fila serve para **substituir** o tick, nao para re-precificar.
    Nao substitui trocas/1M (spread que varia pouco escapa), mas dispensa export
    de ticks. Efeito medido no desenho:
    `pnl_pts` mediano das saidas por BE = **-20 em janeiro contra -47 no resto**;
    e o filtro `<=260` passa **100%** de janeiro (contra 0% de abril e maio),
    inflando janeiro para **49% da amostra**. O mesmo mes ja' vinha carimbado a 37
    pts no Real3: **e' defeito do historico de janeiro da Exness, nao da conta.**
    **O dano do spread congelado NAO e' custo — e' SELECAO.** Re-precificando
    exato, o mes inteiro muda **-$10,66** (1,7%). O que contamina e' o
    `InpMaxSpread=260` ter aprovado **100,0%** dos sinais de janeiro contra 45,7 /
    3,6 / **0,0** / **0,0** / 43,8 / 100 / 95,1% em fev-ago: em janeiro o filtro
    mais valioso da estrategia estava **inerte**, e 49% da referencia veio dali.
14. **O tester pode estar rodando contra um servidor que a doc nao declara.**
    Oito meses de medicao sairam do `Exness-MT5Trial5` (DEMO) enquanto a secao 3
    afirmava `Exness-MT5Real41`. Onde conferir, em ordem de custo: cabecalho do
    relatorio do tester (`Exness-MT5Trial5 (Build 6090)`), `logs\<data>.log`
    (`demo account`), e `bases\<servidor>	icks\<simbolo>\*.tkc` — o servidor
    que tem os arquivos e' o que alimentou o backtest. **Conferir antes de citar
    qualquer numero como sendo "da conta X".**
15. **Teste de autenticidade calibrado no indicador errado erra na CAUDA — que
    e' onde o defeito mora.** O criterio para reprovar um periodo passou por
    quatro versoes em um dia, e cada uma so' caiu porque foi rodada em dado real:
    (a) **valores distintos de spread** — erra nos DOIS sentidos: 2026.01 tem 343
    valores (o maior dos 8 meses) e e' podre; julho tem 11 e e' bom;
    (b) **trocas/1M** — correto, mas so' enxerga o canal do ASK;
    (c) **passo p50 do BID** — quase deixa janeiro passar (0,61x contra um corte
    de 0,6), porque feed interpolado tem muitos ticks pequenos e isso puxa a
    mediana de TODOS os meses para baixo, comprimindo o contraste;
    (d) **passo p90 do BID** — separa limpo: 0,38x contra 0,93-1,12x dos outros.
    E o alerta da v1.04 usava OR com densidade e deu **falso positivo em
    2026.03** (405 ticks/min mas p90 normal = mes movimentado). **Densidade alta
    sozinha nao acusa nada.** O sinal e' a AUSENCIA DE SALTO. Corrigido na v1.05:
    so' o p90 dispara; densidade e' contexto que reforca.
16. **Parametro absoluto nao falha com erro; falha em silencio.** `InpMaxSpread=260`
    numa conta Raw (spread mediano 90) deixa passar 100% dos sinais: o filtro
    desaparece e o log nao diz nada. Medido na janela valida, o EA sem esse filtro
    cai de PF 7,41 para 1,80 e o drawdown de saldo vai de $23,37 para $196,06.
    Ver R8 e `docs\S-Doc-Portabilidade.md`.
17. **`Report=` com caminho ABSOLUTO no `.ini` do tester e' descartado em silencio.**
    O teste roda, termina com "successfully finished", e nenhum relatorio nasce —
    nem erro, nem aviso. Com nome SIMPLES (`Report=rel_v205_trial5_ref`) o MT5
    grava na **raiz da pasta de dados**, junto com 4 `.png`. Build 6090, medido
    nas duas formas em 2026-08-19. **Foi isto que apagou o drawdown e o PF das
    rodadas de 2026-08-18** — e sem DD nao ha' ret/DD, que e' o criterio de
    avaliacao da piramide. Nunca concluir "o teste falhou" pela ausencia do
    relatorio: conferir `Tester\logs\` antes.
17b. **Assimetria em PONTOS premia volatilidade por construcao.** Grupo mais
    volatil tem MFE maior E MAE maior: a diferenca cresce so' por escala, sem
    vantagem nenhuma. Medido em 2026-08-19 na triagem de sensores — em pontos,
    8 sensores "passavam" e a familia `vol` inteira estava entre eles; em ATR,
    tres cairam e dois entraram, e `est_micro` foi de 5 para 3 meses de
    consistencia. **Reportar assimetria sempre em ATR.** Corolario que me pegou:
    o custo de 260 pts vale **0,048 ATR** — um crivo "acima do custo" escrito em
    pontos parece exigente e em ATR nao filtra quase nada (lei 4).
17c. **Corte pela MEDIANA em variavel CICLICA nao mede nada.** `cal_asia`,
    `cal_lon` e `cal_ny` valem `(minutos_do_dia - abertura) mod 1440`. A
    assimetria por hora do servidor **oscila e troca de sinal quatro vezes** ao
    longo do dia (+0,23 / +0,54 / -0,32 / -0,29 / +0,43 / +0,61 / -0,08 / -0,51
    em blocos de 3h): cortar isso num ponto so' da' um resultado que depende
    inteiramente de ONDE o corte cai. Medido em 2026-08-20 deslizando a
    referencia de `cal_lon`: em `InpSrvLon=7` o efeito **INVERTE** (+0,105
    contra -0,227); em 9 cai a um terco. So' passava no crivo no valor exato que
    estava assumido. **A familia calendario sai da triagem como TESTE INVALIDO,
    nao como hipotese reprovada** — a distincao importa: instrumento quebrado
    nao produz veredito em direcao nenhuma. E ha' evidencia apontando para o
    outro lado dentro do proprio achado: a oscilacao de quatro trocas de sinal
    E' estrutura, e a codificacao linear a destruiu em vez de demonstrar
    ausencia. `(minutos - 480) mod 1440` poe 07:59 e 08:00 nos extremos opostos
    da escala sendo instantes vizinhos. Remedicao pendente — ver a fila 5c.
18. **Falha ao armar o breakeven nao entra em NENHUM contador.** A linha de resumo
    reporta `sinal/contexto/abrir/fechar`; BE nao esta' la'. `g_tentBE` e' por
    posicao e o `Print` so' sai na 1a tentativa. Pior: apos `InpMaxTentBE` falhas
    o EA **desiste em definitivo** daquela posicao (linha 636), que segue viva sem
    protecao ate' o stop ou o proximo sinal. Na rodada de referencia foi **1 de
    76** (entrada 2026.02.11 20:50, `10018 market closed` as 21:19, 5 modifies
    recusados; saiu por SINAL em +$7,12 — nao foi punida, mas correu exposta).
    Instrumentado na v2.06: contador no resumo e colunas `be_armado`/`be_falhas`.
    A lei 2 diz que o BE no zero e' o otimo global: posicao que corre sem BE nao
    e' a estrategia medida.
    **Como eu errei este numero, para nao repetir:** contei `grep -c` no log do
    agente, que **acumula todas as rodadas do dia** — tres rodadas de 1 posicao
    viraram "2 posicoes" numa leitura e 15 modifies noutra. Log de tester nao e'
    unidade de medida: contar sempre pelo contador do proprio EA, que zera a cada
    rodada, ou delimitar o trecho da rodada antes de contar.

---

## 7. Fila

**Reordenada em 2026-08-19 pela R8.** O que decide a ordem agora e' portabilidade,
nao mais o proximo experimento interessante.

### Resolvido nesta data (nao re-abrir)

- **O item ABERTO/ADIADO sobre 2026.01 esta RESPONDIDO, e negativo.** Mas nao pelo
  spread: o que decide e' o **caminho do BID** (43,1 pts/tick contra 97-108),
  defeituoso ate' **2026-01-29**. Ver armadilha 13. **Janeiro nao e' recuperavel
  re-precificando** — so' substituindo o tick.
- **`SIG_PBSHALLOW`:** P2/P3/P4 **reprovados**; **P1 indecidivel** (P(assim>custo)
  = 0,44). "4 de 4" era precisao falsa. Ver 5.4.
- **Piramide:** default de volta a `false` (v2.05). Status **indecidivel**.

### Caminho critico (R8)

1. **Auto-configuracao por conta.** Script que identifica corretora/servidor/conta/
   tipo, varre o historico DAQUELA conta, mede **spread e comissao**, e calibra o
   que depende de conta — inclusive o **degrau do breakeven, para que sair no BE
   nao seja prejuizo**. Especificacao, com o conflito medido que ela precisa
   resolver (lei 2: degrau acima de zero foi medido como negativo NA STANDARD),
   em `docs\S-Doc-Portabilidade.md`. **Pela R7, comeca como coluna no EA de
   medicao, nao como codigo operacional.**
2. **Filtro de spread em termos RELATIVOS.** Tres formas candidatas medidas lado a
   lado no EA de medicao. Estado: `spread/ATR` **nao** escolhe melhor que o
   absoluto (descartado -455 contra -491, IC95 cruzando zero nos dois) e e' MENOS
   estavel entre meses (CV 18,0% contra 9,8%); percentil movel ainda nao medido.
   O ganho da forma relativa e' **portabilidade**, nao selecao.
2b. **Fuso do servidor.** `analise\S-Py-Fuso_Servidor.py` mede o offset a partir
   do export, por ancora de mundo real (fronteira semanal), e devolve TABELA DE
   PERIODOS, nao um numero — o offset muda dentro da janela porque o DST europeu
   e o americano nao viram no mesmo dia. **Validado em controle de resposta
   conhecida** (dado Dukascopy, UTC): devolveu +0 nas 4 semanas, residuo -1 min,
   desvio 0,0 min. **Falta rodar no que importa** — export MT5 de XAUUSDm, que
   exige a GUI. Ate' la', `InpSrvAsia=0 / InpSrvLon=8 / InpSrvNY=15` do EA de
   medicao seguem sendo tres constantes NAO MEDIDAS, e `cal_lon` (um dos cinco
   que passaram na triagem de sensores) pode estar medindo a janela errada.
3. **Comissao.** Nunca foi medida. Zero e' suposicao. Numa Raw/Zero ela e' o custo
   dominante e entra direto no degrau do BE.
3a-bis. **Filtro de spread — estado em 2026-08-20.** Teste do descartado:
   **INCONCLUSIVO**, nao favoravel. IC95 [-453, +381] pts contra custo de 260
   (3,2x o custo de largura) no teste confundido por mes, e SEM PODER no teste
   limpo. A frente segue **por ausencia de evidencia contraria, nao por
   evidencia a favor**. Ressalva: o desfecho usado (`tr_1`) foi escolhido por
   disponibilidade e e' trailing de 0,37xATR — familia MORTA na 5.4; nao
   transfere para a titular. **E o desenho muda:** com 2 a 12 valores distintos
   de spread por mes (19 em 568 sinais), **percentil movel e' DEGENERADO** — nao
   ha' selecao dentro do mes, o filtro relativo vira **INTERRUPTOR MENSAL**. A
   pergunta deixa de ser "qual percentil" e passa a ser "operar ou nao em mes de
   spread alto": instrumento mais cru, que exige justificativa propria.
   **Contagem de distintos NAO invalidou mes nenhum** — e' exatamente o teste
   que a armadilha 13 enterrou por inverter vereditos (janeiro tem 343 e e'
   podre; julho tem 11 e e' bom).
3b. **Re-medir o valor do filtro de spread** (5.3). Na janela valida ele nao tem
   valor de selecao detectavel (p=0,431). E' o achado mais incomodo do dia e poe
   em duvida a config de referencia.
3c. ~~`S-Py-Perfil_Spread.py` sobre os ticks de XAUUSDm~~ — **FEITO em 2026-08-19**
   (export em `C:\dev\Historico\`, fora do repo por tamanho). **Julho esta'
   VALIDADO.** Ver a tabela na armadilha 13. Falta so' o mesmo teste em 2026.01
   do XAUUSDm: o export baixado comeca em **2026-05-14** e nao alcanca janeiro.
3c-bis. ~~Verificacao pos-rodada manual~~ — **FEITO em 2026-08-19**:
   `analise\S-Py-Verifica_Rodada.py` reconcilia CSV x relatorio, compara o
   perfil de falhas e faz regressao de metricas E inputs contra
   `S-Ref-Referencia.json`. Sai com codigo != 0. **Rodar em TODA rodada** — foi
   escrito porque dois erros de 2026-08-19 (um numero transcrito errado e a
   v2.06 gravando 63 de 65 pernas) escaparam da conferencia manual e so'
   apareceram por acaso. A comparacao de inputs e' o detector da armadilha 5.
3d. **Consertar o gravador de CSV.** `S-EA-Pullback_Live.mq5` filtra por `InpMagic`
   e nao grava as pernas da piramide nem o fechamento forcado de fim de teste.
   Ou grava, ou os relatorios `.htm` passam a ser versionados.
4. **`InpHistMax = 2,20` porta?** E' o segundo parametro nao adimensional do EA.
   Testar em outro instrumento antes de chamar o desenho de portavel.
5. **Base historica independente de corretora (Dukascopy)** — 4 anos, custom symbol,
   coluna de **proveniencia** por periodo, modelo de spread por cima. Sob a R8
   deixa de ser desejavel e vira **a unica forma de validar** sem depender do
   historico de um broker. A base atual e' de **76 trades em 6,5 meses**, com dois
   meses de zero trade: nao sustenta validacao de nada.

### Depois

5b. ~~Analisar os seis sensores ja' gravados~~ — **TRIAGEM FEITA em 2026-08-19**,
   `docs\S-Doc-Retrato_Sensores.md`. O CSV de 712 sinais que se citava era inutil
   duas vezes: janeiro inteiro E `SIG_TMO1` (hipotese morta). Coleta refeita com
   `SIG_SP` na janela valida: **568 sinais, 7 meses, distribuicao uniforme**.
   Sobreviveram ao crivo: `vol_std` (+0,606 ATR, 6/7 meses), `vol_eff`
   (Efficiency Ratio, +0,367, 5/7), `est_macro` (-0,288, 6/7) e `liq_r50`
   (-0,237, 5/7). **A familia calendario saiu como TESTE INVALIDO** em
   2026-08-20 (armadilha 17c), nao como reprovada — ver 5c. **E' peneira, nao achado**:
   ~20 sensores testados, sem correcao para comparacoes multiplas. Proximo passo
   e' pre-registrar UMA hipotese.
5c. **Remedir a familia calendario com codificacao adequada.** NAO esta'
   enterrada: o teste de 2026-08-20 foi invalido, nao negativo (armadilha 17c).
   **Pre-registro, CORRIGIDO em 2026-08-20:** blocos cujas fronteiras sao
   **FRONTEIRAS DE SESSAO MEDIDAS** (Toquio, Londres, Nova York, pelo fuso que o
   `S-Py-Fuso_Servidor.py` apurar), **nunca grade aritmetica**. Teste
   **OMNIBUS** — um teste so' sobre todos os blocos, nao bloco a bloco.
   Criterio: omnibus significativo E direcao consistente em >=5 dos 7 meses.
   **Por que bloco e nao seno/cosseno:** o perfil troca de sinal QUATRO vezes por
   dia; um par seno/cosseno representa UM ciclo diario e perderia a estrutura por
   construcao.
   **Duas correcoes ao que eu tinha escrito:** (i) o argumento de multiplicidade
   NAO fechava — 8 blocos sao 8 celulas, nao menos superficie que 4-6 colunas
   harmonicas; o que resolve e' o teste ser omnibus, e ai' os dois viram um teste
   so'. (ii) grade de 3h alinhada a' meia-noite do servidor carrega **parametro
   escondido de origem** (por que 3h? por que essa ancora?) — o mesmo defeito que
   derrubou o H8. Fronteira de sessao tem origem justificavel.
   **Depende da fila 2b:** sem o fuso medido, as fronteiras dos blocos nao tem
   ancora e o teste nasce com o mesmo defeito de origem.
6. **Estrutura de mercado** (`est_micro`/`est_macro`/`est_acordo`, ja' gravadas) —
   medir cada componente ISOLADO. Voto ponderado so' depois: peso e' parametro, e
   parametro sem medicao viola a R1.
7. **StressLab** — slippage, spread elevado e latencia sobre a base historica.
8. **Antes de conta real:** trava de simbolo/TF, limite de perda diaria, CSV em modo
   append (`FILE_WRITE` trunca e perde historico se o terminal reiniciar), sizing na
   moeda da conta (o stop escala com ATR: p90 = 2x a mediana).
9. **Baixar o historico do servidor real** (`Exness-MT5Real41` tem so' 202608) e
   refazer o teste de autenticidade la'. Se 2026-01 vier limpo no real, o mes volta.

**Nao fazer:** varrer timeframes antes de ter desenho validado; testar osciladores da
mesma familia; re-testar a lista de mortos; OOP antes de existir uma segunda
estrategia que compartilhe codigo; **fixar no codigo qualquer valor que dependa da
conta** (R8).
