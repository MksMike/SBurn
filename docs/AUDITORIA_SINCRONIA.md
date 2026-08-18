# Auditoria de sincronia — repositorio x PC x MetaTrader

**Executada em:** 2026-08-18, 15:59-16:07 JST (PC-Escritorio, `MIKE-PC`)
**Modo:** somente leitura. Nenhum arquivo do projeto foi copiado, editado, apagado
ou commitado. Unico arquivo criado: este relatorio.
**Auditor:** Claude Opus 5, a pedido do Mike.

---

## 0. AVISO QUE PRECEDE TODO O RESTO — o alvo se moveu durante a auditoria

Esta auditoria rodou sobre um repositorio que **estava sendo modificado por outra
sessao ao mesmo tempo**. Isso nao e' ruido: invalida qualquer leitura instantanea
feita sem carimbo de hora. As medicoes:

| Hora | `S-EA-Pullback_Live.mq5` | HEAD do git |
|---|---|---|
| 15:58:19 | v2.01, 43.424 bytes, md5 `42f0ad4c` | `ff59bc8` |
| ~16:02 | 46.022 bytes, com CRLF (estado transitorio) | `ff59bc8` |
| 16:04:16 | **v2.02**, 46.976 bytes, md5 `224e55db` | `ff59bc8` |
| 16:05:29 | v2.02, 47.110 bytes, md5 `9e07353f` | — |
| 16:05:57 | — | `213efdc` (commit da v2.02) |
| 16:06:19 | v2.02, estavel | `a1e35c4` (README) |

Evidencia de suporte: `MetaEditor64.exe` PID 16596 ativo, quatro processos
`claude.exe` ativos, `.git/FETCH_HEAD` reescrito as 16:06:01, e o commit `213efdc`
assinado `Co-Authored-By: Claude Opus 5`.

**Consequencia pratica:** o estado de referencia que motivou esta auditoria (v2.01)
ficou obsoleto DURANTE a auditoria. Nao ha' divergencia por atraso no EA
operacional — ha' avanco. Ver secao 4.1.

---

## 1. Tabela comparativa dos tres lugares

Os tres locais sao:

1. **Repo local** — `C:\dev\SBurn` (working tree)
2. **MetaTrader** — pasta de dados `C:\Users\Mike Inoue\AppData\Roaming\MetaQuotes\Terminal\53785E099C927DB68A545C249CDBCE06`, alcancada pelo alias `C:\MT5\Exness`
3. **GitHub** — `https://github.com/MksMike/SBurn.git`, branch `main`

### 1.1 O vinculo repo <-> MetaTrader esta' correto

Confirmado por **dois testes independentes**, nao por nome de arquivo:

    Indicators   LinkType=Junction   Target=C:\dev\SBurn\MQL5\Indicators\SBurn
    Experts      LinkType=Junction   Target=C:\dev\SBurn\MQL5\Experts\SBurn
    Include      LinkType=Junction   Target=C:\dev\SBurn\MQL5\Include\SBurn

E comparacao de hash MD5 lado a lado, no mesmo instante:

| Arquivo | Repo | MT5 | Veredito |
|---|---|---|---|
| `S-Ind-ScalpPullback.mq5` | `8a359282...` | `8a359282...` | **igual** |
| `S-Ind-TMO_Scalper.mq5` | `ea250848...` | `ea250848...` | **igual** |
| `S-EA-Pullback_Live.mq5` | `9e07353f...` | `9e07353f...` | **igual** |
| `S-EA-Test_ConsistencyGate.mq5` | `c111efea...` | `c111efea...` | **igual** |
| `S-Include-ConsistencyGate.mqh` | `af77062b...` | `af77062b...` | **igual** |
| `S-Include-MovConsistency.mqh` | `51dfbeef...` | `51dfbeef...` | **igual** |

**Nao existe copia independente.** O cenario perigoso (duas versoes do mesmo
arquivo divergindo em silencio) NAO ocorre nesta maquina. Os `.ex5` compilados
tambem vivem dentro do repo, pelo mesmo junction, e estao corretamente ignorados
pelo git.

### 1.2 Versoes por arquivo

Como repo e MT5 sao o mesmo byte, as colunas "PC" e "MT5" sao uma so'.

| Arquivo | Esperado | Repo = MT5 | GitHub (`a1e35c4`) | Veredito |
|---|---|---|---|---|
| `S-EA-Pullback_Live.mq5` | 2.01 | **2.02** | **2.02** | **adiante** (nao e' atraso) |
| `S-EA-Test_ConsistencyGate.mq5` | **1.27** | **1.20** | **1.20** | **DIVERGENTE — atrasado** |
| `S-Ind-ScalpPullback.mq5` | 2.02 | 2.02 | 2.02 | igual |
| `S-Ind-TMO_Scalper.mq5` | 4.02 | 4.02 | 4.02 | igual |
| `S-Include-ConsistencyGate.mqh` | 1.02 | 1.02 | 1.02 | igual |
| `S-Include-MovConsistency.mqh` | — | presente | presente | igual |
| `S-Py-Duka_Download.py` | — | **AUSENTE** | **AUSENTE** | **ausente nos tres** |
| `CLAUDE.md` | **4.0** | **3.2** | **3.2** | **DIVERGENTE — atrasado** |

Datas e tamanhos (repo, snapshot 16:06:19):

| Arquivo | mtime | bytes | linhas |
|---|---|---|---|
| `S-EA-Pullback_Live.mq5` | 16:05:29 | 47.110 | 969 |
| `S-EA-Test_ConsistencyGate.mq5` | 14:11:16 | 53.996 | 1.082 |
| `S-Ind-ScalpPullback.mq5` | 14:11:16 | 22.394 | 489 |
| `S-Ind-TMO_Scalper.mq5` | 14:11:16 | 31.478 | 713 |
| `S-Include-ConsistencyGate.mqh` | 14:11:16 | 9.438 | 214 |
| `S-Include-MovConsistency.mqh` | 14:11:16 | 5.088 | 133 |
| `CLAUDE.md` | 15:59 | 15.430 | — |

---

## 2. O MD5 de referencia — resolvido, e a explicacao importa

MD5 esperado do EA v2.01: `c274ef7205ae733887ab2190df7afe8e`.

O arquivo v2.01 **como commitado** (blob de `ff59bc8`) da' `42f0ad4c...` — nao bate.
Testando variantes de codificacao sobre esse mesmo blob:

| Variante | MD5 |
|---|---|
| LF, como esta' no repo | `42f0ad4c5a1b8660880ade4f5c6a243c` |
| **LF + newline final** | **`c274ef7205ae733887ab2190df7afe8e`** (bate) |
| CRLF | `a2663d54d5959a8a27382d797d51eaae` |
| BOM + LF | `5f76f04208b895b29fa9f85bbb3b98b8` |
| BOM + CRLF | `9b706475e3aa0ede60f7f3dcbb6b0175` |
| UTF-16LE + BOM + CRLF | `180e0be3fbcdc93c67cb402a740d9364` |

**Conclusao: o conteudo e' identico, byte por byte, exceto pela ausencia de uma
quebra de linha no fim do arquivo.** O v2.01 do repo tinha 907 linhas
(`grep -c ''` = 907) e 43.424 bytes, e continha `InpPirInicioATR` sem conter
`InpReentryK` — exatamente os marcadores da tabela de referencia. A reentrada por
rompimento do extremo, que foi medida e reprovada, **nao esta' presente**.

Registro para o futuro: comparar MD5 de fonte de texto entre maquinas so' e'
confiavel se o terminador final e o EOL forem fixados junto. O `.gitattributes`
deste repo tem `* -text`, o que congela os bytes dentro do git, mas o MetaEditor
grava sem newline terminal — e' dai' que vem a diferenca de um byte.

---

## 3. Estado do git

| Verificacao | Resultado |
|---|---|
| `git status` | **limpo** (nenhuma alteracao, nenhum arquivo nao rastreado) |
| HEAD local | `a1e35c4153f7f1026d47de501f969c42ebf14116` |
| `refs/heads/main` no GitHub (`git ls-remote`) | `a1e35c4153f7f1026d47de501f969c42ebf14116` |
| Commits locais nao enviados | **nenhum** |
| Commits no GitHub ausentes localmente | **nenhum** |
| `.ex5` / `.log` / `.csv` / `.html` versionados | **nenhum** — correto |

Ultimos commits:

    a1e35c4 docs(readme): S-EA-Pullback_Live 2.01 -> 2.02
    213efdc fix(experts): v2.02 - [B14][B15] identificacao do ticket da piramide
    ff59bc8 docs: registra R2 e piramide no estado empirico; versao do EA no README
    187ba5c fix(vscode): files.eol para LF - estava brigando com a invariante do repo
    4a54e25 feat(experts): S-EA-Pullback_Live v2.01 - reentrada R2 e piramide separada
    e8059fe docs: decisao Standard x Raw e armadilha do spread carimbado
    7086532 feat(analise): perfil de spread com teste de autenticidade do feed

Arquivos versionados: 23. Nao versionados e corretamente ignorados: os quatro
`.ex5`, e `dados/S-Rel-Perfil_Spread_XAUUSD_Real3.txt`.

**O git esta' perfeitamente sincronizado nos dois sentidos.** Este e' o resultado
mais limpo da auditoria.

---

## 4. Divergencias, classificadas

### 4.1 `S-EA-Pullback_Live.mq5` — v2.02, nao v2.01 — **MEDIA (com ressalva de medicao)**

Nao e' codigo velho em uso; e' codigo mais novo que a referencia. Marcadores de
conteudo continuam corretos na v2.02: `InpPirInicioATR` presente (6 ocorrencias),
`InpReentryK` ausente (0). O risco de rodar backtest com a reentrada reprovada
**nao existe**.

O que muda — e por que isso nao e' cosmetico:

O commit `213efdc` corrige `[B14]` e `[B15]`, ambos na **piramide**. O `[B14]` e'
substantivo: o ticket de cada adicao vinha de uma varredura que aceitava qualquer
posicao do magic da piramide aberta depois da principal — condicao que todas as
adicoes satisfazem. Como a lista de posicoes do MT5 nao e' cronologica,
`g_pirTicket[k]` podia apontar para outra adicao: **o breakeven de uma movia o stop
da outra**, e a adicao certa ficava sem BE.

> **Consequencia direta para os numeros de referencia.** O resultado
> `InpPirEnabled=true`: **$2.195,53 | DD $324,04 | PF 4,69 | 227 operacoes** foi
> medido na v2.01, ou seja, **com o bug do BE cruzado ativo**. Esse numero nao
> descreve o comportamento da v2.02 e **precisa ser re-medido**. Nao ha' como saber
> o sinal da mudanca sem rodar: BE aplicado na posicao errada tanto pode ter
> protegido cedo demais quanto tarde demais.
>
> O resultado `InpPirEnabled=false`: **$1.494,35 | DD $187,34 | PF 4,85 | 160
> operacoes** **permanece valido** — `[B14]` e `[B15]` estao inteiramente dentro do
> caminho da piramide, que esta' dormente com `InpPirEnabled=false` (default).

Ambas as janelas herdam a ressalva aberta da secao 7 do `CLAUDE.md`: incluem
2026.01, mes ainda nao testado quanto a spread carimbado no XAUUSDm.

### 4.2 `S-EA-Test_ConsistencyGate.mq5` — v1.20 contra v1.27 esperada — **MEDIA**

Classificada MEDIA, e nao CRITICA, por um motivo especifico: **este EA nao decide
operacao nenhuma.** Ele so' grava CSV de medicao. Rodar a v1.20 nao produz backtest
errado — produz um CSV com menos colunas. O risco e' de trabalho perdido, nao de
conclusao falsa. Vira CRITICA no instante em que alguem rodar a fila e concluir
"medi os sensores novos" tendo medido os antigos.

Medicao do desvio:

| Marcador esperado na v1.27 | Presente? |
|---|---|
| `liq_frac` | **nao** |
| `vol_eff` | **nao** |
| `st_acordo` | **nao** |
| `cal_asia` | **nao** |
| `pir_a0` | **nao** |
| `re_g2` | **nao** |

**Header do CSV: 99 colunas. Esperado: 139. Faltam 40.**
(Contagem sobre a string do `FileWriteString` da linha 498, campos separados por
`;`.)

Presentes e corretos na v1.20: `SIG_PBSHALLOW` (item 1 da fila, implementado e
ainda nao rodado) e o trio `est_micro` / `est_macro` / `est_acordo` (item 2 da
fila). Ou seja, das seis familias novas de sensores citadas — liquidez,
Supertrend, calendario, alternativas ao ATR, estrutura de mercado, e
piramide/reentrada instrumentadas — **a unica presente e' estrutura de mercado, e
ela ja' existia na v1.20.** As outras cinco nunca chegaram a este repositorio.

**A v1.27 nao existe em lugar nenhum**: nao esta' no working tree, nao esta' no
GitHub, e nao aparece em nenhum dos 16 commits do historico. Nao e' um caso de
"esqueceram de commitar" — e' codigo que nunca foi escrito neste repo.

### 4.3 Assinatura do EA de medicao mente a versao — **MEDIA**

    linha 202:  #property version   "1.20"
    linha 520:  Print("S-EA-Test_ConsistencyGate v1.07 inicializado | fonte=", ...)

O `#property version` diz 1.20; a assinatura que vai para o log diz **v1.07**.
Isso viola a armadilha 2 do `CLAUDE.md` ("todo programa imprime versao + eco dos
parametros no `OnInit`") no ponto exato em que ela existe para ajudar: o log de uma
rodada antiga nao permite saber qual codigo a produziu. Qualquer CSV ja' gerado por
este EA carrega no log um numero de versao errado.

Nao afeta comportamento. Afeta rastreabilidade — que neste projeto e' o produto.

### 4.4 `CLAUDE.md` v3.2 contra v4.0 esperada — **BAIXA**

O conteudo esta' la': a secao 5.2 descreve a reentrada R2 ("range congelado no
esgotamento") e a piramide como estrategia secundaria com magic proprio, com a nota
de procedencia marcando os tres blocos como hipotese medida e nao validada.

O que nao bate sao os marcadores literais:

| Marcador | Presente? |
|---|---|
| `REENTRADA R2` (maiusculas) | nao — o texto usa `R2, "range congelado no esgotamento"` |
| `ESTRATEGIA SECUNDARIA` (maiusculas) | nao — o texto usa `estrategia SECUNDARIA` |
| numero de versao `4.0` | nao — esta' `3.2` |

Diagnostico: o documento **recebeu o conteudo** da sessao (commit `ff59bc8`) mas
**nao foi renumerado** para 4.0. Divergencia de rotulo, nao de substancia. Nada a
recuperar; so' um numero a acertar — junto com o registro da v2.02, que o
`CLAUDE.md` ainda nao menciona (o `README.md` ja' foi atualizado em `a1e35c4`).

### 4.5 `analise/S-Py-Duka_Download.py` — ausente nos tres lugares — **MEDIA**

Nao existe no working tree, nao existe no GitHub, nao existe no historico. Busca por
`*Duka*` em todo o repositorio: zero resultados. A pasta `analise/` contem apenas
`S-Py-Analise_ConsistGate.py`, `S-Py-Compara_TFs.py` e `S-Py-Perfil_Spread.py`.

Isto corresponde ao **item 3 da fila** (modulo de dados historicos Dukascopy, com
manifesto e `.bi5`), que continua aberto. Nao e' perda: e' trabalho ainda nao feito.

### 4.6 Nada classificado como CRITICA

Nenhuma versao antiga esta' em uso onde importa:

- `S-Ind-ScalpPullback.mq5` v2.02 — contem `[B4] sensor SEMPRE gravado`, e o padrao
  de buffer sempre calculado aparece em 5 pontos do arquivo. **Correto.**
- `S-Ind-TMO_Scalper.mq5` v4.02 — **zero `input group` em codigo executavel**.
  Existem duas ocorrencias da palavra `group` no arquivo, ambas nas linhas 15 e 20,
  ambas dentro do bloco de comentario do CHANGELOG, documentando justamente a
  remocao dos grupos. Os 22 `input` do arquivo sao todos declaracoes simples. A
  armadilha 1 — a que custou a madrugada de depuracao — **esta' fechada.**
- `S-Include-ConsistencyGate.mqh` v1.02 — `time_msc` presente (4 ocorrencias).
- `S-Include-MovConsistency.mqh` — `CMovConsistencySensor` presente.
- O EA operacional nao contem `InpReentryK` em nenhuma versao presente no repo.

---

## 5. Acoes recomendadas — em ordem, NENHUMA EXECUTADA

Ordenadas por custo de errar, nao por esforco.

**1. Antes de tudo: confirmar que a outra sessao terminou.**
Esta auditoria viu o repo mudar tres vezes em oito minutos. Qualquer acao das
seguintes tomada com outra sessao ativa pode colidir. Verificar que o
`MetaEditor64.exe` nao tem edicao pendente e que `git status` segue limpo.

**2. Re-medir a piramide na v2.02.**
Rodar `InpPirEnabled=true` na v2.02, XAUUSDm M5, 2026.01.01-08.14, real ticks, 0.01
lote, e comparar com `$2.195,53 | DD $324,04 | PF 4,69 | 227 operacoes`. Esse numero
foi medido com o BE cruzado do `[B14]` e nao vale mais. Enquanto nao for refeito, a
piramide nao tem resultado atribuivel a nenhuma versao do codigo.
Rodar tambem `InpPirEnabled=false` como controle: deve reproduzir
`$1.494,35 | DD $187,34 | PF 4,85 | 160 operacoes`. Se nao reproduzir, ha' algo
alem de `[B14]`/`[B15]` na v2.02 — investigar antes de seguir.

**3. Decidir o destino da v1.27 do EA de medicao.**
Ela nao existe em lugar nenhum. Duas leituras possiveis, e a diferenca importa:
(a) foi escrita em outra maquina ou outra sessao e nunca chegou aqui — nesse caso,
localizar a origem antes de reescrever; (b) nunca foi escrita — nesse caso a
referencia estava descrevendo intencao, e as cinco familias de sensores ausentes
(liquidez, Supertrend, calendario, alternativas ao ATR, piramide/reentrada
instrumentadas) sao trabalho a fazer. Conferir `docs\S-Doc-Maquinas.md` e as outras
maquinas do projeto antes de assumir (b).

**4. Corrigir a assinatura do EA de medicao.**
Linha 520: `v1.07` -> a versao real. Um caractere de risco, alto retorno em
rastreabilidade. Fazer junto com o proximo toque no arquivo, nao em commit isolado.

**5. Atualizar o `CLAUDE.md`.**
Renumerar 3.2 -> 4.0 e registrar a v2.02 na secao 5.2, incluindo a nota de que o
resultado da piramide medido na v2.01 esta' pendente de re-medicao. O `README.md`
ja' esta' correto.

**6. Rodar o item 1 da fila (`SIG_PBSHALLOW`).**
Ja' esta' implementado na v1.20 presente e nunca foi rodado — e' o unico item da
fila que nao depende de escrever codigo novo. Independe da decisao sobre a v1.27.

**7. Item 3 da fila: `S-Py-Duka_Download.py`.**
Trabalho novo, nao recuperacao. Sem urgencia de sincronia.

**Nao recomendo:** mexer nos junctions, no `.gitattributes` ou no EOL. Estao
corretos e sao a razao de nao haver divergencia repo/MT5. O `187ba5c` (`files.eol`
para LF) ja' fechou essa frente.

---

## 6. Veredito

**Sincronia entre os tres lugares: perfeita.** Repo local, MetaTrader e GitHub
carregam exatamente os mesmos bytes. Junctions corretos e verificados por
`LinkType`/`Target` e por hash. Git limpo, sem pendencia em nenhum dos dois
sentidos. Nenhum binario ou dado versionado por engano. A infraestrutura montada em
`4188e09`/`4ee7312` esta' fazendo o trabalho dela.

**Sincronia com o estado de referencia da sessao: parcial.** O EA operacional passou
a referencia (v2.02 > v2.01) com uma correcao real na piramide que invalida um dos
dois numeros de backtest citados. O EA de medicao ficou sete versoes atras de uma
v1.27 que nao existe em lugar nenhum — cinco das seis familias novas de sensores
nunca chegaram ao repositorio. `CLAUDE.md` tem o conteudo certo com o numero errado.
O modulo Dukascopy nunca foi criado.

**Nada classificado como CRITICO.** Nenhuma versao antiga em posicao de produzir
backtest errado: a reentrada por rompimento reprovada nao esta' presente, o
`input group` do TMO nao esta' presente, e o `[B4]` do ScalpPullback esta'.
