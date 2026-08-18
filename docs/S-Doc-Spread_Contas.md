# SBurn — Spread por tipo de conta (Standard x Raw/Pro)
**Versao:** 1.1 | **Medido em:** 2026-08-18 | **Maquina:** PC-Escritorio

Pergunta que originou: **em qual conta desenvolver?**
**Resposta (secao 4): Standard.** Decidido em 2026-08-18.

A medicao que sustentou a decisao esta' nas secoes 1 e 2. Ela tambem produziu um
achado que NAO era o objetivo da pergunta e que virou o item mais urgente do
projeto: um mes inteiro de tick "real" da corretora veio com spread constante.
Ver armadilha 13 no CLAUDE.md.

---

## 1. O que foi medido

Export de ticks do MT5, `C:\dev\Historico\XAUUSD_202601012305_202608180514.csv`,
3,03 GB, **64.395.916 ticks validos**, 2026.01.01 -> 2026.08.18.

Procedencia (verificada, nao suposta): simbolo **XAUUSD** (sem sufixo), servidor
**Exness-MT5Real3**, conta real **238363456**. Confirmado por tres evidencias
independentes: o nome do simbolo bate; `bases\Exness-MT5Real3\ticks\XAUUSD\` tem
exatamente os 8 meses `202601..202608`; o log do terminal registra a conta
238363456 autorizada nesse servidor no mesmo dia do export.

Ferramenta: `analise\S-Py-Perfil_Spread.py` v1.02.
Saida bruta: `dados\S-Rel-Perfil_Spread_XAUUSD_Real3.txt` (nao versionada).

### 1.1 Distribuicao (arquivo inteiro)

| | p1 | p10 | p25 | p50 | p75 | p90 | p99 | media | max |
|---|---|---|---|---|---|---|---|---|---|
| **XAUUSD @ Real3** | 37 | 37 | 77 | **90** | 100 | 137 | 207 | 88,6 | 960 |
| **XAUUSDm Standard** (registro do projeto) | — | — | 240 | **260** | 280 | 360 | — | — | — |

Pontos; 1 pt = $0,001 com 0,01 lote. **Ressalva de metodo:** a linha Standard vem
da medicao por CSV do EA (CLAUDE.md secao 3), nao de um export de ticks. As duas
linhas NAO foram produzidas do mesmo jeito nem na mesma janela — servem para
ordem de grandeza, nao para o veredito.

Ordem de grandeza: o spread desta conta e' **~2,9x menor** que o da Standard.

### 1.2 Autenticidade do feed, por mes

| mes | ticks | p50 | p90 | valores distintos | dominante | trocas/1M |
|---|---|---|---|---|---|---|
| 2026.01 | 13.430.391 | 37 | 37 | 343 | 37 = 99,7% | **178** |
| 2026.02 | 8.009.052 | 77 | 137 | 178 | 77 = 39,9% | 26.104 |
| 2026.03 | 12.310.228 | 137 | 139 | 25 | 97 = 42,2% | 9.443 |
| 2026.04 | 6.839.960 | 97 | 137 | 13 | 97 = 66,9% | 18.219 |
| 2026.05 | 6.010.270 | 100 | 100 | 9 | 100 = 87,4% | 6.437 |
| 2026.06 | 7.970.953 | 90 | 100 | 11 | 100 = 44,2% | 40.626 |
| 2026.07 | 6.731.896 | 80 | 80 | 11 | 80 = 96,9% | 1.745 |
| 2026.08 | 3.093.166 | 90 | 90 | 10 | 90 = 68,3% | 6.706 |

**O discriminador e' TROCAS/1M, nao a contagem de valores distintos.** Foi um
falso positivo do primeiro corte: "poucos valores distintos" acusa como sintetico
um spread que a corretora simplesmente quota em degraus. Confirmacao por trecho
contiguo:

- **Julho** (2M ticks a partir de 2026.06.30): **6.473 trocas**, alternando
  80<->90 tick a tick e abrindo para 130 exatamente as 14:00:01, com cauda ate'
  310. Isso e' mercado real com spread quantizado.
- **Janeiro** (2M ticks, 2026.01.19 17:55 -> 2026.01.23 16:03, quatro dias
  corridos): **5 trocas**. Cinco. 99,99% dos ticks em exatamente 37 pontos.

### 1.3 Consequencia imediata: 2026.01 esta' fora

Janeiro tem 178 trocas/1M contra 26.104 no mes seguinte — **~150x abaixo**. Nesse
mes o spread e' uma constante carimbada no dado: o custo intrabar nao varia e o
breakeven nunca derrapa. Como o desenho e' path-dependent (63% dos trades saem
pelo BE), backtest em janeiro nesta conta e' **invalido, nao apenas impreciso** —
mesma regra que ja' vale para tick simulado (CLAUDE.md secao 3).

Sobram **2026.02 a 2026.08** de dado utilizavel: 51,0M ticks, ~6,5 meses.

---

## 2. O achado que muda a pergunta

O filtro `spread <= 260` da estrategia titular **aprova 99,98% dos ticks desta
conta**. Ele deixa de filtrar.

Isso nao e' detalhe de calibracao. O registro do projeto (secao 5.3) diz que esse
filtro leva a configuracao de ret/DD **7,5x para 26,6x** e PF de 2,69 para 5,83 —
e que **99% do efeito dele e' condicao de mercado, nao custo**. Ou seja: o spread
nao esta' sendo usado como preco, esta' sendo usado como **sensor de regime**.

Entao a troca de conta nao mexe so' no custo. Ela mexe na resolucao do sensor:

| | Standard (XAUUSDm) | Esta conta (XAUUSD @ Real3) |
|---|---|---|
| Distribuicao | continua (p25 240, p50 260, p75 280, p90 360) | quantizada, 9 a 25 valores/mes |
| Concentracao | espalhada | um valor pega 40% a 97% dos ticks do mes |
| Como sensor | discrimina | resolucao baixa, e **instavel entre meses** |

A instabilidade e' o problema serio. Em 2026.07, 96,9% dos ticks estao num unico
valor: qualquer corte de spread nesse mes aprova quase tudo ou quase nada. Em
2026.06, o valor dominante pega 44,2%: o mesmo corte discrimina. Um sensor cujo
poder de separacao varia assim de mes para mes ataca de frente o criterio de
promocao do projeto (**positivo em OOS e IS, com estabilidade mensal**).

---

## 3. O que AINDA NAO foi medido (e por que nada esta' decidido)

1. **Comissao.** Conta Raw/Zero cobra por lote e isso NAO aparece em export de
   ticks. Custo round-trip = spread + comissao. Comparar so' pelo spread favorece
   a Raw artificialmente. Sem esse numero, o "2,9x mais barato" da secao 1.1 e'
   um teto, nao o custo.
2. **Tipo real da conta 238363456.** O simbolo nao tem sufixo (`XAUUSD`),
   enquanto a Standard usa `XAUUSDm`. No mesmo servidor existem tambem `XAUUSDc`,
   `XAUUSDr` e `XAUUSDz`. Qual sufixo corresponde a qual tipo de conta nao foi
   verificado — nao chutar (R1).
3. **A metade Standard da comparacao.** Falta o export de ticks de `XAUUSDm` na
   MESMA janela, medido pela MESMA ferramenta. Enquanto nao existir, a comparacao
   e' entre uma medicao tick a tick e um resumo de CSV — metodos diferentes.
4. **O que decide de verdade:** rodar `S-EA-Test_ConsistencyGate` nas duas contas
   na mesma janela e comparar os sinais, nao os spreads. R7 — medir antes de
   construir. Spread e' insumo; o que importa e' quanto trade sobrevive e com que
   assimetria.

---

## 4. DECISAO (2026-08-18): desenvolver na Standard

**Decidido pelo Mike: o desenvolvimento continua na Standard (XAUUSDm).**
Motivo que sustentou a escolha: nao e' a conta mais barata — nao e' — mas o
sensor de spread, que sustenta a melhor configuracao ja' medida, tem resolucao
continua nela e resolucao baixa e instavel na outra.

O que a decisao FECHA: a comparacao de contas sai do caminho critico. Nao e'
mais necessario exportar ticks de XAUUSD@Real3 nem levantar a comissao da Raw
para seguir. A secao 3 fica como divida tecnica, nao como bloqueio.

O que a decisao NAO fecha, e passa a ser o item mais urgente do projeto:

> **A armadilha 13 foi medida no XAUUSD da Real3. Ela tambem esta' no XAUUSDm?**

O resultado de referencia (137 trades, +$1.308,59, PF 5,83) cobre
**2026.01.01-08.12** — inclui janeiro. Se o janeiro do XAUUSDm tiver o mesmo
spread carimbado que o do XAUUSD, esse mes e' invalido e o numero de referencia
precisa ser re-medido sobre 2026.02-08. Isso nao e' ajuste fino: janeiro e' ~1/8
da janela, e o desenho e' path-dependent justamente no custo intrabar.

**Como responder:** exportar os ticks de XAUUSDm da mesma janela pelo MT5
(Simbolos > XAUUSDm > Ticks > Exportar) e rodar

    python analise\S-Py-Perfil_Spread.py <export_XAUUSDm.csv> --rotulo "XAUUSDm Standard"

Ler a coluna `trocas/1M` da secao 3 do relatorio. Milhares = feed vivo; janeiro
do XAUUSD deu 178.

**Status em 2026-08-18: ADIADO por decisao do Mike.** O desenvolvimento segue
sobre a referencia atual, na conta Standard. A pergunta continua aberta e a
ressalva anda junto do numero: comparar candidatos na MESMA janela continua
valido (o vies de janeiro e' comum aos dois lados), mas o nivel absoluto de
qualquer resultado que inclua 2026.01 nao esta' medido — esta' pendente.

---

## 5. Confirmacao com trades reais do tester (2026-08-18)

Rodada do `S-EA-Pullback_Live`, candidato **C_HIST**, **XAUUSD** (nao XAUUSDm),
M5, 2026.01-08, 0,01 lote.
Saida: `Common\Files\SBurn\ops_C_HIST_XAUUSD_PERIOD_M5_2026-01-08.csv`, 368 trades.

**Geral:** n=368, total **+$1.286,70**, media +$3,50, DD $170,91, ret/DD 7,5x, PF 2,18.

**Janeiro contra o resto:**

| | n | total | media/trade | DD | PF |
|---|---|---|---|---|---|
| 2026.01 | 61 | **+$607,56** | **+$9,96** | $60,31 | 4,72 |
| 2026.02-08 | 307 | +$679,14 | +$2,21 | $170,91 | 1,74 |

**Janeiro entrega 47% do lucro com 17% dos trades, a 4,5x a media por trade de
qualquer outro mes.** Tres assinaturas independentes dizem que isso nao e' mercado:

1. **Spread congelado.** Nos 61 trades de janeiro, `spread_ent` tem **1 valor
   distinto** (37). Nos demais meses, 2 a 7 valores por mes.
2. **Derrapagem no BE proxima de zero** — a assinatura que o CLAUDE.md ja'
   listava. Saidas por BE: desvio-padrao de `pnl_pts` de **10,5 pts em janeiro**
   contra **2.318 pts** em 2026.02-08. Fator **220x**.
3. **Nao e' volatilidade.** ATR mediano de janeiro = 5.112, no meio da tabela
   (marco 9.844, fevereiro 5.942, abril 5.688). Marco teve ATR 1,9x maior e
   amplitude parecida, e rendeu +$7,71/trade contra +$9,96 de janeiro.

O caminho de preco de janeiro reforca: 4.328 (dia 1) -> 5.281 (dia 28) -> 4.759
(dia 30, 14 horas depois), **com spread exatamente 37 o tempo inteiro**.

### O que esta rodada estabelece — e o que nao estabelece

**Estabelece:** a infraestrutura desta maquina funciona ponta a ponta (EA compila,
resolve os indicadores por `iCustom`, roda no tester e grava o CSV na pasta
COMMON). E estabelece o mecanismo do dano: um mes com dado carimbado nao produz
erro nem aviso — produz **lucro**, concentrado, e passa despercebido no total.

**NAO estabelece nada sobre o resultado de referencia.** Esta rodada foi em
**XAUUSD**, e a referencia (137 trades, +$1.308,59) foi em **XAUUSDm**, outro
simbolo e outro feed. A pergunta da secao 4 continua aberta e continua sendo a
primeira da fila.

**Resultado negativo a registrar (R4):** em XAUUSD, sem janeiro, o C_HIST rende
+$679,14 em 6,5 meses com PF 1,74 e **dois meses negativos** (2026.05 -$45,60 e
2026.08 -$82,27). Contra o C_HIST de referencia em XAUUSDm — 247 trades,
+$1.173,88, PF 2,69 — e' materialmente pior. Nao da' para atribuir a diferenca ao
simbolo ou ao dado sem rodar os dois na mesma janela limpa.

### Divida que continua aberta (para quando a Raw voltar a pauta)

Se um dia o destino for operar na Raw, desenvolver na Standard entrega um filtro
que **nao transfere**: `spread <= 260` aprova 99,98% dos ticks da outra conta.
Nesse dia a ordem correta nao e' trocar de conta, e' primeiro re-expressar o
corte em termos que sobrevivam a troca — percentil da propria conta, ou multiplo
de ATR. Item 6 da fila do CLAUDE.md.

Traducao direta ja' disponivel para quando isso for testado: na Standard o corte
260 e' aproximadamente a **mediana** da propria distribuicao (p50 = 260; a taxa de
aprovacao medida no backtest, 137 de 247 trades = 55%, bate com corte na mediana).
O equivalente relativo nesta conta seria **spread <= 90**. Isso e' uma hipotese a
testar, **NAO CALIBRADO** — o proprio numero 260 nunca foi promovido como
percentil, foi promovido como valor absoluto.
