# SBurn — Base historica Dukascopy e o custom symbol de backtest
**Versao:** 1.0 | **Criado:** 2026-08-20 | **Status:** CONSTRUIDO E VERIFICADO

Este documento e' a referencia operacional do que passou a existir em
2026-08-20: uma base de tick real **independente de corretora**, uma camada de
custo medida, e um **custom symbol de 24 meses** ja' registrado no MT5 e testado
pelo tester.

Ele responde tres perguntas: **o que existe**, **onde esta'** e **como rodar um
backtest nele sem tirar conclusao errada**.

> **A leitura mais importante deste documento esta' na secao 6.** O simbolo serve
> para **comparacao relativa** (config x config, mes x mes, regime x regime) e
> **nao** para prever a magnitude de P&L na Exness. Isso nao e' cautela retorica:
> foi medido, e o numero esta' na secao 5.

---

## 1. Por que isto existe

A Exness so' tem tick real a partir de **2026-01**, e 2026-01 esta' reprovado
(armadilha 13). Sobravam **6,5 meses** e **76 operacoes** na configuracao de
referencia, com dois meses de zero operacao. Isso nao valida nada.

A Dukascopy tem tick real de ouro desde 1999, em UTC. A base existe para dar
**profundidade historica com origem conhecida**, e sob a **R8** deixa de ser
desejavel: e' a unica forma de medir sem depender do historico de um broker.

---

## 2. A cadeia completa

    base BRUTA (imutavel)  +  perfil de corretora  ->  SIMBOLO GERADO  ->  MT5

| Etapa | Artefato | Estado |
|---|---|---|
| 1. Tick bruto | `C:\dev\Historico\bruto\XAUUSD\dukascopy\<ano>\<mes>\<dia>\<hora>h_ticks.bi5` | **24 meses, 156.638.854 ticks, ZERO horas ausentes** |
| 2. Camada de custo | `C:\dev\Historico\perfis\exness_standard_xauusdm.json` | medida (secao 5) |
| 3. Fabrica | `C:\dev\Historico\ferramentas\fabrica_simbolos.py` | 24 `.bin`, 3,6 GB |
| 4. Importador | `C:\dev\Historico\MQL5\Scripts\Historico\S-Scr-Importa_Simbolo.mq5` v1.01 | compila 0 erros / 0 warnings |
| 5. Custom symbol | **`XAUUSD_EXNESS_STANDARD`** | **registrado; 156.638.854 ticks + 704.636 barras M1** |

**Janela coberta: 2024-08-01 a 2026-07-31.**

---

## 3. Onde tudo mora

O repositorio da base e' **`C:\dev\Historico`** (SEM acento). Existe tambem um
`C:\dev\Histórico` (COM acento) que guarda apenas o export de ticks do MT5
(`XAUUSDm_202601012305_202608171359.csv`, 2,97 GB). **Nao confundir.**

### Junctions criados em 2026-08-20

    C:\MT5\Exness\MQL5\Scripts\Historico
        -> C:\dev\Historico\MQL5\Scripts\Historico

    ...\MetaQuotes\Terminal\Common\Files\Historico
        -> C:\dev\Historico\simbolos

O segundo evita copiar 3,6 GB: o MQL5 so' le de `MQL5\Files` ou `Common\Files`,
e o junction expoe `simbolos\` la' dentro. Remover com
`cmd /c rmdir "<caminho>"` (sem `/s`) — `Remove-Item -Recurse` SEGUE o link e
apaga os fontes.

### Dado do simbolo dentro do MT5

    C:\MT5\Exness\bases\Custom\ticks\XAUUSD_EXNESS_STANDARD\   768 MB, 24 .tkc
    C:\MT5\Exness\bases\Custom\history\XAUUSD_EXNESS_STANDARD\  41 MB

---

## 4. Como rodar um backtest no simbolo

### 4.1 Configuracao minima

| Campo do `.ini` | Valor |
|---|---|
| `Symbol` | `XAUUSD_EXNESS_STANDARD` |
| `Model` | `4` (Every tick based on real ticks) |
| `FromDate` / `ToDate` | dentro de `2024.08.01` - `2026.07.31` |
| `Report` | **nome SIMPLES**, nunca caminho absoluto (armadilha 17) |
| `ShutdownTerminal` | `1`, senao o terminal fica aberto e o proximo `/config` e' ignorado |

Templates prontos, usados no teste acido:

    C:\MT5\Exness\MQL5\Profiles\Tester\_acido_acB_custom_ref.ini      (filtro <=260)
    C:\MT5\Exness\MQL5\Profiles\Tester\_acido_acD_custom_livre.ini    (sem filtro)

**Nunca inventar `.ini`.** Partir de um que o proprio tester salvou em
`MQL5\Profiles\Tester\` e trocar so' o necessario. Nos inputs, `Nome=A||B||C||D||N`
usa **A** como valor corrente.

### 4.2 O terminal tem de estar FECHADO

Com instancia viva, o MT5 **ignora `/config` em silencio**: o teste nao roda,
nenhum relatorio nasce, e nada no log diz por que. Medido em 2026-08-20.

    # fechar
    taskkill //PID <pid>          # SEM /F  -- ver secao 8
    # conferir que saiu ANTES de lancar o tester
    tasklist | grep -i terminal64
    # rodar
    "C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe" /config:"<ini>"

### 4.3 Inputs do EA — o que muda neste simbolo

**`InpMaxSpread` NAO funciona aqui.** O spread e' constante dentro de cada mes,
entao o filtro vira **interruptor mensal**. Com `260`, o simbolo opera **so'
junho e julho** de 2026 (spreads 260 e 240); fevereiro a maio ficam acima do
corte e sao 100% barrados.

Para medir qualquer coisa que nao seja o proprio filtro, rodar com
`InpMaxSpread=99999`. Foi assim que se produziu a comparacao valida da secao 5.

Os demais inputs sao adimensionais (multiplos de ATR, barras) e portam sem
mudanca — ver `S-Doc-Portabilidade.md`.

---

## 5. As medicoes que sustentam a camada

Todas em **julho/2026**, mes validado nos dois canais (1.750 trocas/1M, passo
p90 do BID = 202), contra o feed real da Exness.

### 5.1 Fuso: UTC+0

Correlacao de retornos M5 Dukascopy x Exness: pico em **+0 min, r = 0,997936**;
vizinhos a +-5 min com `abs(r) < 0,01`. **Quarta confirmacao independente** de
que o `Exness-MT5Trial5` roda em UTC+0 fixo (as outras tres: fronteiras semanais
do export, fechamentos de feriado da CME, e o 1o tick do simbolo aparecendo no
terminal com o mesmo carimbo do arquivo).

### 5.2 Preco: NAO ha' o que corrigir

Discordancia de MID **com sinal**, 132.744 pares: p50 **+1 pt**, media **+1,0
pt**, p10 -227 / p90 +227. Simetrica em torno de zero.

**A fabrica preserva o MID da Dukascopy e substitui so' o spread.** Nao se
compara BID entre feeds de spread diferente — isso mede spread, nao preco.

### 5.3 Spread: nivel constante por mes

| mes | 2026-02 | 03 | 04 | 05 | 06 | 07 |
|---|---|---|---|---|---|---|
| p50 Exness (medido) | 264 | 360 | 308 | 308 | 260 | 240 |

Nos **18 meses sem referencia** (2024-08 a 2026-01) usa-se **290 pts** — media
aritmetica das seis medianas mensais, cada mes valendo um voto. Decisao do Mike
em 2026-08-20.

> O p50 agrupando os 46,9M de ticks daria **308**. Ficam os 290 porque o
> agrupado pesa por contagem de ticks e deixaria marco dominar; para estimar um
> mes **nao observado**, o voto por mes e' o estimador adequado.

### 5.4 Modelo REPROVADO: spread como razao do da Dukascopy

**Hipotese pre-registrada:** se a razao Exness/Dukascopy for estavel, ela
justifica extrapolar.

| Modelo | CV entre meses | Erro absoluto medio |
|---|---|---|
| A — nivel constante | **15,1%** | **35 pts** |
| B — razao x spread Dukascopy (0,415) | 19,4% | 43 pts |

E a premissa falha na raiz: **correlacao entre os dois spreads r = +0,125
(p=0,81)**, spearman +0,232 (p=0,66). O spread do livro institucional nao
carrega informacao sobre o markup da corretora. Fica o A.

*Ressalva (R3): n=6 meses; 35 contra 43 pts sozinho nao decidiria. Quem decide
e' a correlacao nula — com r ~ 0 o parametro extra nao compra nada.*

### 5.5 Estrutura intradiaria: medida e NAO aplicada

O rollover das 21h UTC alarga o spread (p50 **360** contra 308; p90 **500**
contra 396) — justo a hora em que um breakeven de degrau ZERO e' colhido.

**Nao entrou de proposito.** Nos 18 meses sem referencia, qualquer variacao
intra-mes seria **inventada**, e o `InpMaxSpread` passaria a selecionar sobre um
RNG nosso — selecao fabricada, armadilha 10. Fica registrada no perfil para quem
quiser um perfil de estresse dedicado.

---

## 6. O TESTE ACIDO — e a consequencia que muda como se cita numero

Mesmo EA, mesma janela (**2026.02.01-07.31**), mesma config (C_HIST, 0.01 lote,
ticks reais 100%), dois feeds.

| | simbolo | filtro | trades | lucro | DD saldo | PF | recup |
|---|---|---|---|---|---|---|---|
| A | XAUUSDm | <=260 | 69 | 704,46 | 19,81 | 8,23 | 3,76 |
| B | gerado | <=260 | 54 | 221,28 | 39,28 | 3,00 | 2,31 |
| **C** | **XAUUSDm** | **livre** | **272** | **742,79** | **196,06** | **1,96** | **1,81** |
| **D** | **gerado** | **livre** | **286** | **451,88** | **178,65** | **1,48** | **1,10** |

**C vs D e' o par que vale.** A vs B mede o filtro degenerado, nao o feed.

### 6.1 Nao ha' defeito na camada

| | C (real) | D (gerado) |
|---|---|---|
| trades | 272 | 286 (+5,1%) |
| taxa de acerto | 19,49% | 18,88% |
| **maior ganho** | **267,14** | **266,65** |

**O trade de 2026.03.19 — sozinho 34,7% do lucro da referencia — aparece nos
dois com $0,49 de diferenca.** O feed independente ve o mesmo evento, gera quase
o mesmo numero de sinais e acerta na mesma proporcao.

### 6.2 O buraco de $290,93 e' CAMINHO, nao custo

| | ganhos | perdas | liquido |
|---|---|---|---|
| C | 53 x 28,58 = +1.514,74 | 219 x -3,53 = -773,07 | 741,67 |
| D | 54 x 25,79 = +1.392,66 | 232 x -4,06 = -941,92 | 450,74 |
| **delta** | **-122,08 (42%)** | **-168,85 (58%)** | **-290,93** |

1 ponto @ 0.01 lote = $0,001. O spread **inteiro** de D custa $82,94; o de C,
$78,88. Diferenca **$4,06 = 1,4% do buraco**. O buraco e' **3,5x o custo total
de spread de D** — nao cabe em custo.

A perda media cresce 15% e a **pior perda dobra** (-36,24 -> -77,35): mais
posicoes indo ao stop cheio em vez de raspar no breakeven.

### 6.3 O que isto significa

O mid dos dois feeds correlaciona **0,998** em retornos M5: **as barras sao
praticamente as mesmas**. So' o caminho INTRABAR difere — e so' isso move o
lucro em **39%**.

E' a medicao mais direta que o projeto ja' teve da fragilidade que a secao 3 do
`CLAUDE.md` declara: *"63% dos trades saem pelo breakeven, que depende do
caminho intrabar"*. Ate' aqui isso era razao para **exigir tick real**. Agora ha'
numero: **dois feeds reais do mesmo ativo, na mesma janela, com as mesmas
barras, dao 742,79 e 451,88.**

> **Regra que sai daqui: nenhum numero de lucro deste projeto deve ser citado
> sem dizer em que feed foi medido.** O sinal transfere, a direcao transfere, a
> **magnitude nao**.

### 6.4 Limites deste teste (R3)

- Uma janela (6 meses), um ativo, uma configuracao.
- A camada de custo de D e' aproximada; responde por 1,4% do buraco, entao nao
  muda a conclusao, mas nao e' zero.
- **Nao prova que um feed esteja certo e o outro errado.** Prova que o desenho e'
  sensivel ao caminho intrabar em grau alto.
- D usa o p50 mensal, que cobra acima da moda em fev (240) e mar (308). Vies de
  direcao unica: **D e' pessimista, nao otimista**.

---

## 7. 2026-01 e' LEGITIMO na Dukascopy

Teste do passo p90 do BID (armadilha 15d), contra meses **contemporaneos**:

| Referencia | ref p90 | 2026-01 | razao |
|---|---|---|---|
| meses de 2026 (02..07) | 160 | 187 | **1,17x** |
| regime de preco >= 4000 (2025-10..2026-07) | 150 | 187 | **1,25x** |

Criterio de reprovacao: < 0,6x. **Janeiro esta ACIMA da referencia.** No feed da
Exness o mesmo mes da' **0,34x**.

**O defeito de 2026-01 e' do historico da Exness, nao do mes.** No simbolo
gerado janeiro entra com tick real e spread extrapolado de 290 pts — nunca com
os 160 carimbados que aprovavam 100% dos sinais no filtro.

> **Cuidado de metodo, medido:** o p90 cru **nao** se compara ao longo dos 24
> meses. O ouro foi de ~2.464 para ~4.987 na janela e passo em PONTOS escala com
> o nivel de preco — 2024 da' 60-70 e 2026 da' 130-260 sem que isso signifique
> nada. Normalizar por pts/min tambem nao resolve: cria tendencia propria e faz
> janeiro parecer 0,62x da mediana da janela quando contra os vizinhos ele e'
> 0,85x. **So' vale contra meses do mesmo regime.**
>
> Janeiro tem a MAIOR densidade dos 24 meses (316,9 ticks/min) **e** passo acima
> da referencia: mes movimentado, nao reconstruido. Densidade alta sozinha nao
> acusa nada (armadilha 15).

**O que NAO se afirma:** os numeros de janeiro ja' medidos pelo SBurn continuam
invalidos — sairam do feed da Exness. O que se afirma e' que **re-rodar** janeiro
no simbolo gerado e' legitimo.

---

## 8. Operacao

### 8.1 ARMADILHA: `taskkill /F` apaga o registro do custom symbol

Medido em 2026-08-20, custou uma rodada e uma acao manual do Mike.

- **O dado sobrevive**: `bases\Custom\ticks\` com 768 MB e os 24 `.tkc` intactos.
- **O registro nao**: o tester passa a dizer `symbol XAUUSD_EXNESS_STANDARD not
  exist` / `cannot select symbol in market watch`.
- **Abrir e fechar o terminal normalmente NAO reconstroi o registro.** Testado.

**Fechar sempre com `taskkill /PID <pid>` SEM `/F`.**

### 8.2 Re-registrar o simbolo (se isso acontecer)

Script MQL5 **nao tem entrada por linha de comando**, e `CustomSymbolCreate`
**nao funciona dentro do tester**. Nao ha' registro de servico em arquivo
editavel (`Services=` no `common.ini` e' bitmask, nao lista).

Entao: **Navigator -> Scripts -> Historico -> arrastar `S-Scr-Importa_Simbolo`
para qualquer grafico.** Defaults corretos. ~145 s. O `Conferir()` da v1.01
reporta tick e barra M1 no fim — se vier zero barra, ele grita.

### 8.3 Regerar os ticks do simbolo

    cd C:\dev\Historico
    .venv\Scripts\python.exe -u ferramentas\fabrica_simbolos.py --perfil exness_standard_xauusdm

~13 min para 24 meses. **Deterministico**: mesmo perfil + mesma base = mesmo
MD5, conferido byte a byte.

### 8.4 Verificacoes que ja' passaram

Contra o `.bi5` de origem, nos dois caminhos (mes medido e mes extrapolado):

- contagem identica de ticks
- **fuso: diferenca 0 ms em TODOS os ticks**
- spread exatamente o do perfil (240 no medido, 290 no extrapolado)
- mid preservado com desvio <= 0,5 pt — o minimo aritmetico ao impor spread par
  sobre mid meio-inteiro; media +0,0000, sem vies
- ordem temporal nao-decrescente
- dentro do MT5: `lidos == gravados` nos 24 meses, e **704.636 barras M1** contra
  709.320 minutos possiveis = **99,3%** (nao precisa de `CustomRatesUpdate`)

---

## 9. O que o simbolo NAO resolve

| Item | Situacao |
|---|---|
| **Filtro de spread** | degenerado aqui. A fila 3b continua precisando do feed real |
| **Comissao** | NUNCA medida. Zero e' suposicao (fila 3) |
| **Magnitude de P&L na Exness** | nao transfere — secao 6 |
| **Backtest de 24 meses de ponta a ponta** | **nunca rodado.** As duas rodadas foram de 6 meses. 156M ticks e' outra escala |
| **2022-01 a 2024-07** | 31 meses ainda faltam; travam no 429 da Dukascopy |
| **XAUUSDm de 2026.01 a 2026.02.16** | sem export; a condenacao segue por inferencia forte, nao medicao |

---

## 10. Para que serve, entao

Os 24 meses sao **internamente consistentes** — mesmo feed, mesmo metodo, mesma
camada de custo, sem mes de zero operacao. Isso torna o simbolo forte
exatamente onde a base de 76 trades nao sustentava nada:

- **comparar configuracoes entre si** (candidato A x B x C x D)
- **comparar meses e regimes** com 24 pontos, nao 6
- **medir estabilidade mensal**, que a secao 4 exige para promocao e que a base
  atual nao tem
- **testar sensores e filtros** em amostra 4x maior

O que ele **nao** faz e' dizer quanto a estrategia renderia na Exness.

**Comparacao relativa: sim. Nivel absoluto: nao.**
