# SBurn — Checkpoint de 2026-08-18
**Maquina:** PC-Escritorio (`MIKE-PC`) | **Commits do dia:** 11 (`5b24aeb` -> `7eb8e93`)
**Proxima sessao:** PC de casa. A secao 0 e' o que fazer ao chegar.

---

## 0. Chegando no PC de casa

    git clone https://github.com/MksMike/SBurn.git C:\dev\SBurn
    cd C:\dev\SBurn
    powershell -ExecutionPolicy Bypass -File setup\S-Ps-Setup_Maquina.ps1
    git config --local user.name  "Mike Inoue"
    git config --local user.email "<email da conta do GitHub>"
    python -m pip install pandas scipy

Se o repositorio JA' existir la', **nao clonar por cima**: `git status` primeiro.
Se houver arquivo modificado, ler o que e' antes de qualquer `pull` — ver a
secao 2.3 deste documento, que e' exatamente sobre isso ter dado errado hoje.

Depois: compilar `Ctrl+Shift+B` (indicadores primeiro, EAs por ultimo) e
**registrar a maquina** em `docs\S-Doc-Maquinas.md` com o apelido dela
(sugestao: `PC-Casa`) e o `COMPUTERNAME`, seguindo a tabela do PC-Escritorio.

---

## 1. O que foi feito hoje

### 1.1 Infraestrutura — PC-Escritorio parametrizado

Repositorio clonado em `C:\dev\SBurn`, ligado ao MetaTrader por 3 junctions,
compilacao verificada de ponta a ponta (4 fontes, 0 erros, 0 warnings), pandas e
scipy instalados, extensao que faltava no VS Code instalada.

O problema real que apareceu aqui: **arquivo versionado carregava caminho de
maquina.** O `.vscode\settings.json` apontava para `C:\Users\mikem\...`, que nao
existe neste PC. Resolvido com o alias `C:\MT5\Exness` (junction para a pasta de
dados do terminal, criada por maquina), e um script que faz isso sozinho:
`setup\S-Ps-Setup_Maquina.ps1`. Registro das maquinas em `docs\S-Doc-Maquinas.md`.

### 1.2 Medicao de spread e a descoberta do janeiro carimbado

Export de 3,03 GB, **64.395.916 ticks** de XAUUSD @ Exness-MT5Real3 (conta
238363456), 2026.01-08. Ferramenta nova: `analise\S-Py-Perfil_Spread.py`.

Achado principal: **2026.01 tem spread constante.** 99,7% dos ticks em exatamente
37 pontos e **178 trocas de valor por milhao de ticks**, contra 26.104 no mes
seguinte — 150x abaixo. Num trecho contiguo de 4 dias corridos: **5 trocas em 2
milhoes de ticks.**

O discriminador e' TROCAS/1M, **nao** a contagem de valores distintos. Essa foi
uma correcao de metodo no meio do caminho: julho tem so' 11 valores distintos e
mesmo assim e' feed vivo (6.473 trocas em 2M ticks, alargando para 130 as
14:00:01). Spread quantizado real existe; spread carimbado e' outra coisa.

Confirmado depois com trades reais do tester (368 ops, C_HIST, XAUUSD): **janeiro
entregou 47% do lucro com 17% dos trades**, a 4,5x a media/trade dos demais meses,
sem suporte de ATR, com 1 valor distinto de spread na entrada e derrapagem no BE
**220x menos dispersa**. Sem janeiro: +$679,14, PF 1,74, dois meses negativos.

Virou a **armadilha 13** do CLAUDE.md. A licao: dado carimbado nao gera erro nem
aviso — **gera lucro**, concentrado, e some dentro do total.

### 1.3 Decisao: desenvolver na Standard

Registrada em `docs\S-Doc-Spread_Contas.md`. O motivo nao e' custo — a Standard e'
~2,9x mais cara em spread. E' que o filtro `spread <= 260` **nao e' filtro de
custo**: o proprio registro do projeto diz que 99% do efeito dele e' condicao de
mercado. Na conta de spread apertado esse corte aprova 99,98% dos ticks e o sensor
morre. A comparacao com a Raw saiu do caminho critico e virou divida documentada.

### 1.4 Codigo

| Arquivo | de | para |
|---|---|---|
| `S-EA-Pullback_Live.mq5` | 1.07 | **2.02** |
| `S-EA-Test_ConsistencyGate.mq5` | 1.20 | **1.28** |

O EA operacional ganhou a reentrada R2 e a piramide como estrategia secundaria
(v2.00/v2.01, vindos de voce), mais a correcao `[B14]`/`[B15]` na identificacao do
ticket da piramide (v2.02, ver secao 3). O EA de medicao ganhou sete versoes de
sensores novos (liquidez, alternativas ao ATR, Supertrend, calendario, piramide e
reentrada instrumentadas) mais a correcao da assinatura (v1.28, ver secao 2.4).

---

## 2. O PROBLEMA DE VERSIONAMENTO — ele apareceu de quatro formas

Nenhuma delas deu erro. Todas teriam passado despercebidas.

### 2.1 Caminho de maquina dentro de arquivo versionado

`settings.json` com `C:\Users\mikem\...`. Em outro PC, o Ctrl+F7 simplesmente nao
resolve os includes. **Fechado:** alias `C:\MT5\Exness`, criado por maquina pelo
script de setup. Nenhum arquivo versionado carrega mais nome de perfil do Windows.

### 2.2 CRLF entrando num repositorio de bytes congelados

O `.gitattributes` usa `* -text` de proposito: o git grava **exatamente** os bytes
do disco, para o repositorio ser identico em qualquer maquina. Mas o
`.vscode\settings.json` tinha `"files.eol": "\r\n"`. Quando o editor reescrevia um
arquivo inteiro, ele voltava em CRLF — e o git gravaria assim.

Custo observado: o `S-EA-Pullback_Live.mq5` v2.01 chegou em CRLF e o diff apareceu
como **907 linhas trocadas em vez das 263 reais**. Um diff assim e' ilegivel; uma
revisao em cima dele nao acontece.

**Fechado:** `files.eol` para `"\n"` (commit `187ba5c`). Rotina que ficou: antes de
commitar fonte, `git ls-files --eol <arquivo>` tem que dizer `i/lf  w/lf`.

### 2.3 O working tree sobrescrito por buffer velho — a v2.02 foi engolida

O caso mais serio do dia. Sequencia:

1. Commitei a v2.02 do EA operacional, com a correcao `[B14]`/`[B15]`. Push feito.
2. Algum tempo depois, o arquivo em disco estava **de volta na v2.01**, em CRLF,
   byte-a-byte igual ao commit anterior. A correcao sumiu do working tree.
3. Causa provavel: editor com o texto antigo aberto salvando por cima — havia
   **duas sessoes de agente e o MetaEditor** mexendo no mesmo working tree.
   O relatorio `docs\AUDITORIA_SINCRONIA.md` registra o arquivo mudando de tamanho
   tres vezes em oito minutos.
4. Recuperado com `git checkout --`, porque **estava commitado e no GitHub**.

O que salvou foi ter commitado cedo. Se a v2.02 ainda estivesse so' em disco,
teria evaporado sem deixar rastro — e um F7 teria compilado a versao com o bug.

**Regra que fica:** commitar antes de sair do arquivo, e **nunca duas sessoes
escrevendo no mesmo working tree**. Sessao que so' audita ou le deve rodar em
worktree separado.

### 2.4 A assinatura mentindo a versao

O `S-EA-Test_ConsistencyGate` tinha o numero da versao em **tres lugares mantidos
a mao**, e dois estavam para tras:

| Onde | Dizia |
|---|---|
| Cabecalho de instalacao | `v1.04` |
| `#property version` | `1.27` |
| `Print` do `OnInit` | `v1.07` |

O do `Print` e' o que aparece no Diario — e' por ele que a armadilha 2 manda provar
qual build rodou. **Todo CSV ja' gerado por esse EA carrega no log um numero de
versao errado.** Nao afeta comportamento; afeta rastreabilidade, que neste projeto
e' o produto.

**Fechado (v1.28):** o `Print` passou a derivar de um `#define S_VER` colado no
`#property version`. De tres pontos espalhados por 700 linhas para **dois,
vizinhos**. O MQL5 nao deixa ler o proprio `#property version` em runtime, entao
zerar nao da'.

### O fio comum

Nas quatro, o erro **nao produziu erro**. Produziu diff ilegivel, arquivo silen-
ciosamente velho, log com numero errado e caminho quebrado so' na outra maquina.
E' o mesmo padrao da armadilha 13 e do bug das colunas `liq_*` zeradas: neste
projeto o modo de falha caro nao e' o que quebra — e' o que continua rodando.

---

## 3. Numeros que ficaram INVALIDOS hoje

**A piramide inteira.** Todo numero de piramide citado no CHANGELOG do EA e na
secao 5.2 do CLAUDE.md foi medido na **v2.01, com o `[B14]` ativo** — o bug em que
o breakeven de uma adicao movia o stop de OUTRA, deixando a adicao certa sem BE.
Isso inclui `$2.195,53 / DD $324,04 / PF 4,69 / 227 operacoes` e a grade de inicio
(1,0 / 2,0 / 3,0 x ATR). Nao da' para inferir o sinal da correcao sem rodar.

**Continua valido:** o controle `InpPirEnabled=false`
(`$1.494,35 / DD $187,34 / PF 4,85 / 160 operacoes`). `[B14]` e `[B15]` vivem
inteiramente dentro do caminho da piramide, dormente no default.

**Ressalva que atravessa tudo:** qualquer janela que inclua **2026.01** carrega a
armadilha 13, ate' o teste de trocas/1M ser rodado no XAUUSDm. Comparar candidatos
na MESMA janela continua valido (o vies e' comum aos dois lados); o que nao vale e'
tratar o nivel absoluto como medido.

---

## 4. Estado do repositorio ao fim do dia

| | |
|---|---|
| HEAD = `origin/main` | sim |
| Working tree | limpo |
| Fontes: PC = MT5 = GitHub | sim, verificado por hash arquivo a arquivo |
| `.ex5` compilados dos fontes atuais | sim, 0 erros / 0 warnings |

| Arquivo | v |
|---|---|
| `S-Ind-ScalpPullback.mq5` | 2.02 |
| `S-Ind-TMO_Scalper.mq5` | 4.02 |
| `S-EA-Pullback_Live.mq5` | **2.02** |
| `S-EA-Test_ConsistencyGate.mq5` | **1.28** |
| `S-Include-ConsistencyGate.mqh` | 1.02 |

---

## 5. Fila para a proxima sessao

1. **Re-medir a piramide na v2.02.** `InpPirEnabled=true`, XAUUSDm M5, real ticks,
   0,01 lote. Rodar `InpPirEnabled=false` junto, como controle: tem que reproduzir
   `$1.494,35 / DD $187,34 / PF 4,85 / 160 ops`. Se nao reproduzir, ha' algo alem
   de `[B14]`/`[B15]` na v2.02 — investigar antes de seguir.
2. **`SIG_PBSHALLOW`** (item 1 da fila antiga). Ja' esta' implementado e nunca foi
   rodado — e' o unico item que nao depende de escrever codigo novo.
3. **Trocas/1M no XAUUSDm** para fechar a armadilha 13 na conta que importa.
   Exige logar na conta Standard e baixar os ticks. Adiado por decisao sua, mas e'
   o que libera citar nivel absoluto de novo.
4. **Duas decisoes de desenho da piramide**, documentadas no codigo e nao medidas:
   ela **sobrevive** ao BE e ao stop da principal (so' sai em sinal novo do SP), e
   o sentinela `g_r2Topo==0` impede a R2 de disparar quando o recuo nao teve
   excursao favoravel nenhuma. As duas podem estar certas — nenhuma foi medida dos
   dois jeitos.
5. **`S-Py-Duka_Download.py`** (item 3 da fila antiga) nao existe em lugar nenhum:
   nem no working tree, nem no GitHub, nem no historico. E' trabalho a fazer, nao
   trabalho perdido.

---

## 6. Sobre o `AUDITORIA_SINCRONIA.md`

Relatorio de outra sessao, rodado hoje as 15:59-16:07, versionado junto com este
checkpoint. **Duas secoes dele nasceram desatualizadas** porque o repositorio mudou
enquanto ele auditava — ele proprio avisa isso na secao 0:

- **4.2** diz que a v1.27 do EA de medicao "nao existe em lugar nenhum". Ela chegou
  depois e esta' commitada (`a21db93`), ja' na v1.28.
- **4.3** aponta a assinatura mentindo. Corrigida em `7eb8e93`.

O resto vale, em especial a secao 4.1, que e' a origem da invalidacao da secao 3
deste checkpoint.
