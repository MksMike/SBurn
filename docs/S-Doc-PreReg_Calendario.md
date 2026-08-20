# Pre-registro — familia CALENDARIO (fila 5c)
**Versao:** 1.0 | **Escrito em:** 2026-08-20 | **Estado: BLOQUEADO — nao rodar**

Documento escrito ANTES de qualquer desfecho medido. A Etapa 0 (poder) rodou
como parte da redacao e **declarou o teste inviavel antes de ele existir**, que
e' exatamente para o que ela serve.

---

## 1. Por que isto NAO e' pesca

O teste anterior (`cal_lon`, 2026-08-20) foi **INVALIDO**, nao negativo, por
duas causas independentes:

1. **Variavel ciclica cortada pela mediana** (armadilha 17c). `cal_lon` vale
   `(minutos_do_dia − 480) mod 1440`, e a assimetria por hora do servidor troca
   de sinal QUATRO vezes ao longo do dia. Cortar funcao oscilante num ponto da'
   numero que depende de onde o corte cai.
2. **Ancora de relogio errada.** O EA assume "GMT+2/+3 com horario de verao";
   o servidor e' **UTC+0 fixo** (fila 2b, 32 fronteiras semanais).

Instrumento quebrado nao produz veredito em direcao nenhuma. A R2 proibe trocar
de variante depois de ver numero **RUIM** para cacar numero bom; aqui o numero
era **INVALIDO**. Precedente do projeto: o TMO reprovou como gatilho e passou
como veto — veredito e' local a' pergunta.

---

## 2. Ancora: SESSAO DE VERDADE, nao hora de servidor

Fronteira fixa em hora de servidor atravessa a abertura de Londres duas vezes
por ano e passa a descrever **duas populacoes como se fossem uma**. A hipotese
da familia e' que SESSOES tem comportamento distinto: fronteira que desliza em
relacao a' sessao mede o relogio, nao o fenomeno. E' o mesmo argumento que
derrubou o H8.

Conversao **por praca**, nao global — as tres fronteiras se movem em datas
diferentes:

| praca | calendario | vira em |
|---|---|---|
| Londres | Europe/London | ultimo domingo de marco |
| Nova York | America/New_York | segundo domingo de marco |
| Toquio | Asia/Tokyo | **nao vira** |

**Consequencia registrada:** existe o intervalo de ~3 semanas em marco em que
Londres e NY estao dessincronizadas, e nele a DURACAO das sobreposicoes muda.
Isso e' real, nao artefato. Mas faz o bloco perder duracao constante, o que
reintroduz concentracao-confundida-com-duracao: **normalizar dentro da
populacao do MESMO tipo de bloco** (percentil ou z-score entre ocorrencias do
mesmo bloco), nunca entre blocos diferentes.

### 2.1 A escolha que NAO e' livre de parametro

"Abertura de sessao" exige escolher qual hora local conta. Tratado como o
script de fuso tratou o "17:00 NY": **ancora declarada + residuo medido**.

**PRIMARIA (convencao de mercado, externa):**

| praca | convencao adotada | UTC inverno | UTC verao |
|---|---|---|---|
| Toquio | 09:00–15:00 JST (sessao diurna TOCOM) | 00:00–06:00 | 00:00–06:00 |
| Londres | 08:00–16:30 local (mercado de metais) | 08:00–16:30 | 07:00–15:30 |
| Nova York | 08:20–17:00 ET (pregao COMEX; 17:00 = parada diaria) | 13:20–22:00 | 12:20–21:00 |

**VERIFICACAO (variavel DIFERENTE do desfecho, entao nao e' circular):** perfil
de intensidade de ticks por hora UTC, do export de 63,2M ticks. Criterio
declarado antes: concordancia dentro de ~30 min sustenta a ancora.

| praca | convencao | maior salto observado | dif | veredito |
|---|---|---|---|---|
| Nova York | 13:20 / 12:20 | 13:00 (inv) / 12:30 (ver) | 20 / 10 min | **SUSTENTADA** |
| Londres | 08:00 / 07:00 | **nenhuma descontinuidade** | — | **NAO VERIFICAVEL** |
| Toquio | 00:00 | **01:00**, nas duas estacoes | 60 min | **DISCORDA** |

**Londres nao tem degrau nenhum.** O perfil de 05:00 a 10:00 UTC e' plano
(1,7–2,2% por meia hora) em inverno e verao. O "salto" que o argmax achou era
+0,32pp sobre um plato — ruido. A verificacao **nao sustenta nem refuta** a
ancora de Londres: o instrumento nao tem sinal ali.

**Toquio erra por 1h**, e o pico observado (01:00 UTC, 3,6% inverno / 4,1%
verao, o dobro dos vizinhos) e' **estavel entre estacoes** — compativel com uma
praca sem DST. 01:00 UTC = 09:00 CST coincide com a abertura da Shanghai Gold
Exchange, que tambem nao tem DST. **Nao adoto SGE aqui:** trocar a convencao
depois de ver o dado e' escolher a que agrada, que e' o que o desenho proibe.
Fica registrado como ancora CANDIDATA, a ser pre-registrada num documento
proprio se a frente reabrir.

> **Pela regra declarada, isto sozinho ja' manda REGISTRAR E PARAR.** Duas das
> tres ancoras nao passam: uma discorda materialmente, outra nao e' verificavel.

---

## 3. Desenho dos blocos (para o dia em que a ancora fechar)

Seis celulas, todas com significado, nenhuma com origem aritmetica:

`Asia` · `Asia-Londres` · `Londres` · `Londres-NY` · `NY` · `vazio pos-fechamento`

Nao 8 blocos de 3h: com quatro trocas de sinal por dia, 8 celulas podem ser mais
resolucao do que a estrutura tem, e cada celula corta a amostra.

**Achado da particao provisoria:** com a convencao primaria, `Asia-Londres`
sai **VAZIA** — Toquio fecha 06:00 UTC e Londres abre 07:00/08:00, nao se
tocam. O desenho de seis celulas vira de cinco. Isso e' consequencia da
convencao adotada, nao do mercado: com ancora de Xangai (fecha 07:00 UTC) a
sobreposicao existiria. Mais uma razao para nao fechar a ancora no escuro.

---

## 4. ETAPA 0 — poder estatistico (rodou; e' o que bloqueia)

Desfecho: assimetria em ATR (`mfe15_A/atr − mae15_A/atr`), Entrada A.
Teste: **omnibus por permutacao** sobre a variancia entre blocos da assimetria.
Um teste so', sem multiplicidade.

**n por bloco** (particao provisoria, 568 sinais, 2026-02 a 2026-08):

| bloco | n |
|---|---|
| Londres | 151 |
| Asia | 148 |
| Londres-NY | 100 |
| NY | 89 |
| vazio | 80 |
| Asia-Londres | **0** |

**Poder do omnibus**, medido sobre **nulo sintetico** (rotulos embaralhados
antes de injetar o efeito, para nao contaminar com efeito real do dado):

| efeito injetado | poder |
|---|---|
| **0,0 ATR** (controle) | **6%** — calibrado em alfa=5% |
| 0,2 ATR | 2% |
| 0,3 ATR | 4% |
| 0,5 ATR | 11% |
| 0,8 ATR | 27% |

Nos efeitos de referencia (0,2–0,3 ATR, a ordem do que a triagem produziu) o
poder e' **2–4%: ao nivel do falso positivo**. Mesmo a 0,8 ATR — quatro vezes o
efeito de referencia — o poder e' 27%.

**Quanto dado resolveria?** (delta 0,3 ATR, alvo 80%)

| n | meses de coleta | poder |
|---|---|---|
| 568 | 6,5 | 8% |
| 1.136 | 13 | 8% |
| 2.272 | 26 | 18% |
| 4.544 | 52 | 30% |
| 9.088 | **104** | **57%** |

**Nem 8,7 anos de coleta dao 80%.** A causa nao e' o tamanho da amostra: e' a
razao entre a dispersao do desfecho e o efeito procurado. `MFE15/ATR` tem ~2,8
ATR entre quartis contra um efeito de ~0,3. Nenhum volume realista de dado
conserta essa razao para um omnibus baseado em medianas.

> **Primeira contaminacao, registrada:** a primeira versao desta simulacao
> injetava o efeito no dado REAL. A curva saiu 62% / 70% / 78% e nao caia para
> ~5% quando delta -> 0 — sinal de que media efeito existente + delta, nao
> poder. Corrigida embaralhando os rotulos antes de injetar. Os numeros da
> tabela acima sao os corrigidos.

---

## 5. Desfecho — por que nao ha' alternativa instrumentada

`tr_1` esta' **FORA**: trailing de 0,37×ATR, familia enterrada na 5.4, nao
transfere para a titular (BE no zero, stop 3,67×ATR). Foi escolhido por
disponibilidade uma vez e isso ja' custou uma conclusao errada.

A alternativa que resolveria o poder e' um desfecho **limitado** (truncado por
stop), que tem variancia muito menor que MFE. As colunas de escada existentes
nao servem:

- `be_a*l*` — a grade nao tem **degrau ZERO** (a estratégia titular); o menor e'
  +0,05×ATR, hipotese ja' morta na 5.4. E gravam sentinela `-999999`.
- `ct_*`, `tr_4` — sentinela tambem, e familias mortas.

**Portanto a 5c esta' bloqueada por INSTRUMENTACAO, alem de por poder.** Isso e'
resultado legitimo e fica registrado em vez de virar improviso.

---

## 6. Teste, para quando desbloquear

- **Omnibus primeiro.** Permutacao sobre a variancia entre blocos, ou
  Kruskal-Wallis. Um veredito, sem multiplicidade.
- **Omnibus nao passa -> acabou.** Nao olhar bloco individual. Nao existe "mas
  o bloco X estava bom".
- **Omnibus passa ->** descrever quais blocos e em que direcao, explicitamente
  como DESCRICAO, nunca como teste novo.
- Particao OOS/IS do padrao do projeto. Custo = spread mediano medido.

---

## 7. Criterio de FUNERAL — e por que este caso NAO e' um

**Regra:** se o omnibus nao passar **com poder adequado**, a familia calendario
recebe atestado, e nao se testa outra particao (4 blocos, 8 blocos, outra
ancora) para reanimar — isso e' pesca por definicao.

**Este caso nao aciona a regra.** O omnibus nunca rodou, e a Etapa 0 diz que
nao ha' poder adequado para roda-lo informativamente. A precondicao da regra
falha. O estado correto e' **BLOQUEADA**, nao enterrada — mesma categoria em
que a frente do spread parou.

O que desbloquearia, e so' isso:

1. **Desfecho limitado com a regra de saida titular** (BE no zero, stop
   3,67×ATR) instrumentado como coluna no EA de medicao — R7.
2. Ancora de sessao resolvida (secao 2.1), com a convencao pre-registrada
   ANTES de olhar o perfil de novo.

**Nao desbloqueia:** trocar particao, trocar horizonte, trocar ancora ate' o
numero fechar.

---

## 8. Ressalvas que acompanham qualquer numero futuro desta familia

- **n = meses, nao anos.** 6,5 meses de coleta, um simbolo, servidor de DEMO.
- **MFE nao e' lucro**, e MFE/MAE nao dizem a ORDEM dos eventos.
- **Duracao de bloco varia em marco**, quando Londres e NY dessincronizam.
- **Promocao significa virar coluna ou grade no EA de medicao**, nunca ligar
  em EA operacional (R7).

---

## 9. Observacao que vale alem desta frente

Duas frentes independentes — **spread** (interruptor mensal) e **calendario**
(esta) — pararam no **mesmo lugar**: falta um desfecho limitado que corresponda
a' estrategia titular. Isso deixa de ser coincidencia e vira argumento para
priorizar essa instrumentacao acima de abrir frente nova.
