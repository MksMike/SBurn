# CHECKPOINT — S-EA-Pullback_Live v2.03

**Data:** 2026-08-19 | **Maquina:** PC-Escritorio (`MIKE-PC`) | **Autor:** sessao Claude Code

> Nome fora da convencao `S-Doc-*.md` da CLAUDE.md secao 2 — foi pedido
> explicitamente como `docs/CHECKPOINT.md` no prompt desta tarefa.

---

## 1. O que mudou no codigo

Um unico arquivo: `MQL5\Experts\SBurn\S-EA-Pullback_Live.mq5`, v2.02 -> **v2.03**.
Alteracao restrita ao bloco de identificacao do ticket em `PiramideAbrir()` e aos
contadores. `Abre()`, `AplicaBreakeven()`, o R2 e o `OnTick` nao foram tocados.
**Nenhum default de input mudou.**

**[B16] — identificacao do ticket da adicao.** Antes: `ResultDeal()` ->
`HistorySelect()` -> `DEAL_POSITION_ID`. Agora, em ordem:

1. `g_tradePir.ResultOrder()`, confirmado por `PositionSelectByTicket()` +
   `POSITION_MAGIC == InpPirMagic`. Em conta hedging o ticket da POSICAO e' igual
   ao ticket da ORDEM de abertura, e ele existe na hora, sem depender do historico.
2. `ResultDeal()` + `DEAL_POSITION_ID` — o metodo da v2.02, mantido como fallback.
3. Varredura por `POSITION_MAGIC`, pegando a posicao **mais recente** (maior
   `POSITION_TIME`) e ignorando ticket ja' atribuido a outra adicao. Pegar "a
   primeira encontrada" era o defeito original do `[B14]`.
4. So' entao conta como `sem_ticket`.

**[B17] — contadores separados.** `g_pirFalhas` somava dois casos de implicacao
oposta. Agora sao `g_pirRejeitadas` (ordem rejeitada: a adicao nao existe) e
`g_pirSemTicket` (adicao aberta mas nao identificada: existe e fica sem BE). O log
final passou a imprimir `piramide: adicoes=%d rejeitadas=%d sem_ticket=%d`.
Alem disso a rejeicao agora conta **uma unica vez por adicao** (`g_pirRejCont[]`,
zerado em `PiramideFechar()`): `g_pirAbertas` nao avanca quando a ordem falha,
entao o alvo do passo continuava valido e `PiramideAbrir()` era chamada — e
contada — a cada tick.

Compilacao: **0 erros, 0 warnings**.

---

## 2. O diagnostico do prompt estava errado

O prompt supunha que as 234 falhas da v2.02 eram o caso `[B15]` (adicao aberta sem
BE). O log da propria rodada (`C:\MT5\Exness\Tester\logs\20260818.log`, 84 MB)
diz outra coisa:

| Evidencia | Contagem |
|---|---|
| Linhas `adicao N aberta mas NAO identificada` | **0** |
| Linhas `falha ao abrir adicao N` | 702 (= 3 rodadas x 234) |
| Retcodes distintos nessas 702 | **1**: `10018 market closed` |
| Datas distintas nessas 702 | **1**: `2026.01.06` |

Ou seja: a busca por `DEAL_POSITION_ID` da v2.02 **acertou o ticket nas 106
adicoes**. Nenhuma rodou sem breakeven. As 234 eram tentativas de abrir a "adicao
2" durante a pausa diaria do ouro em 2026.01.06, repetidas a cada tick — o unico
defeito real ali era a contagem repetida, que o `[B17]` corrige.

Consequencia: **a expectativa pre-registrada no prompt esta' vazia**. Ela previa
lucro entre $2.200 e $2.400 e DD entre $300 e $350 porque o BE das adicoes
"passaria a funcionar". Ele ja' funcionava.

---

## 3. Rodadas

XAUUSDm M5, 2026.01.01 - 2026.08.18 (mesma janela das rodadas anteriores — o cache
do tester confirma: `S-EA-Pullback_Live.XAUUSDm.M5.20260101_20260818.4.*.tst`),
"Every tick based on real ticks" (qualidade do historico: **100% de ticks reais**),
0.01 lote, C_HIST, deposito $10.000, alavancagem 1:100, sem atraso de execucao.
Rodadas por linha de comando (`terminal64.exe /config:...`), com `.set` explicito —
o `.set` auto-salvo do tester **nao** foi alterado.

| Rodada | Lucro | DD saldo | DD capital | PF | Negociacoes | Contadores da piramide |
|---|---|---|---|---|---|---|
| **v2.03 piramide ON** | **$2.617,25** | $123,38 | **$426,52** | 4,63 | 254 | `adicoes=106 rejeitadas=1 sem_ticket=0` |
| **v2.03 controle (OFF)** | **$1.387,20** | **$71,58** | $187,34 | 4,64 | 148 | `adicoes=0 rejeitadas=0 sem_ticket=0` |
| v2.02 piramide ON (hoje) | $2.617,25 | $123,38 | $426,52 | 4,63 | 254 | `adicoes=106 falhas=234` |
| v2.02 controle (hoje) | $1.387,20 | $71,58 | $187,34 | 4,64 | 148 | `adicoes=0 falhas=0` |

A v2.02 foi recompilada do git e rodada hoje, na mesma configuracao, justamente
para separar o efeito do patch do efeito do ambiente. **Os quatro numeros da v2.03
sao identicos aos da v2.02.** O patch e' neutro no comportamento: ele conserta a
CONTAGEM e adiciona robustez ao caminho de identificacao, nao muda uma ordem.

Relatorios: `C:\MT5\Exness\rel_v203_pir{ON,OFF}.htm` e `rel_v202_pir{ON,OFF}.htm`.
CSV das operacoes da estrategia principal: `dados\ops_v203_pir{ON,OFF}.csv`
(identicos entre si — a piramide tem magic proprio e nao entra no CSV).

---

## 4. Criterio de aceite

**1) `sem_ticket` proximo de zero — PASSOU.** Deu exatamente **0**. Ressalva
honesta: passou porque ja' era 0 na v2.02, nao porque a correcao resolveu algo que
estava quebrado. O que a correcao entrega e' robustez (tres caminhos em vez de um)
e um contador que agora distingue os dois casos.

**2) O controle deve reproduzir — PASSOU no que importa, com uma divergencia
documentada.** O prompt pedia `$1.378,88 / DD $71,58 / 147 operacoes / PF 4,61`.
Obtido: `$1.387,20 / DD $71,58 / 148 operacoes / PF 4,64`.

- **DD bate exatamente** ($71,58).
- O log de ontem registra `final balance 11386.78` para o controle, ou seja
  **$1.386,78** — e nao $1.378,88. O valor do prompt parece ter dois digitos
  trocados na transcricao.
- A diferenca de $1.386,78 para $1.387,20 e' **$0,42, e vale uma operacao**
  (147 -> 148). A janela termina em 2026.08.18: ontem a ultima posicao ainda
  estava aberta no fim do historico de ticks disponivel; hoje ela ja' fechou.
- **A alteracao nao vazou para a estrategia principal.** Prova: a v2.02
  recompilada do git, rodada hoje, da' os mesmos $1.387,20 / 148 / PF 4,64. A
  divergencia contra ontem e' 100% dados de tick, 0% codigo.

---

## 5. Achados registrados, NAO acionados

1. **A piramide tenta abrir durante o mercado fechado.** Em 2026.01.06 a "adicao 2"
   foi rejeitada com `10018 market closed` e o EA re-tentou a cada tick ate' o
   mercado reabrir. Nao e' bug de contabilidade (o `[B17]` so' conserta a
   contagem), mas e' comportamento a decidir: re-tentar indefinidamente, ou
   desistir da adicao quando o alvo foi atingido com o mercado fechado? So' houve
   1 ocorrencia em 8 meses — medir antes de mexer (R7).
2. **`InpPirArmATR` = 0,73 continua herdado da principal, sem grade propria.** O
   prompt levantava a hipotese de grade propria caso o lucro caisse muito mais que
   o DD. Como nada mudou, a hipotese **nao foi testada nem refutada** — segue em
   aberto, sem evidencia em nenhuma direcao.
3. **Toda a secao 3 herda a ressalva de 2026.01** (armadilha 13 / fila da
   CLAUDE.md): a janela inclui janeiro, que ainda nao passou pelo teste de
   trocas/1M no XAUUSDm. Comparacao entre configuracoes na mesma janela continua
   valida; nivel absoluto, nao.

---

## 6. Estado / proximo passo

- v2.03 compilada, commitada, com a piramide **desligada por padrao** (`InpPirEnabled=false`).
- A tabela da secao 5.2 da CLAUDE.md que foi **invalidada em 2026-08-18** por causa
  do `[B14]` continua invalidada — mas por um motivo diferente do que se pensava.
  O `[B14]` **nao mudou nenhum numero** (v2.01 e v2.02 dao o mesmo 12616.32 no log
  de ontem, e v2.02 e v2.03 dao o mesmo 12617.25 hoje). O que existe hoje, medido
  e reprodutivel na janela 2026.01.01-08.18, e':
  `piramide ON $2.617,25 / DD capital $426,52 / PF 4,63` contra
  `controle $1.387,20 / DD capital $187,34 / PF 4,64`.
  Isso e' +89% de lucro por 2,3x de drawdown — **ret/DD cai de 7,4x para 6,1x**
  (fator de recuperacao do proprio relatorio). Segue **hipotese medida**, nao validado.
- Pendente da fila: `SIG_PBSHALLOW`, estrutura de mercado, teste de trocas/1M em
  2026.01 no XAUUSDm.
