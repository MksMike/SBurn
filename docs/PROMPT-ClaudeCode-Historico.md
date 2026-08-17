# Prompt para o Claude Code — base historica universal (C:\dev\Historico)

Cole o bloco abaixo numa sessao NOVA do Claude Code, com o terminal em `C:\dev`.

---

Voce vai construir uma **base historica de tick data universal**, que sera usada por
varios projetos de trading independentes. Responda em portugues do Brasil.

Trabalhe em etapas. Ao fim de CADA etapa, mostre o resultado e espere confirmacao.
Nao avance sozinho. Neste projeto, prosseguir com incerteza ja' custou semanas de
trabalho baseado em dados que nao eram o que pareciam.

---

## Contexto e arquitetura (leia antes de agir)

**O problema que isso resolve.** Backtests so' valem com tick real. A corretora atual
(Exness) so' tem tick real a partir de 2026.01 — periodos anteriores o tester SIMULA
a partir de barras M1, o que invalida qualquer estrategia dependente do caminho
intrabar. A Dukascopy tem tick real de gold (`xauusd`) desde **3 de junho de 1999**.

**Decisao de arquitetura — leia com atencao, ela nao e' obvia:**

No MT5, um custom symbol carrega bid e ask DENTRO dos proprios ticks. Nao existe
rodar "o mesmo simbolo com outro spread". Portanto:

- a base BRUTA (Dukascopy) e' **imutavel** e nao pertence a corretora nenhuma;
- cada combinacao de `corretora x tipo de conta x cenario de estresse` e' um
  **simbolo separado**, GERADO a partir da base bruta + um perfil;
- isso e' uma **fabrica de simbolos** centralizada, com catalogo. Projetos
  CONSOMEM simbolos prontos; nenhum projeto altera a base bruta.

**Proveniencia e' obrigatoria.** Cada periodo carrega a etiqueta da origem
(dukascopy_bruto / exness_tick_real / interpolado_m1). Sem isso, daqui a um ano
ninguem sabe qual trecho e' confiavel — e esse erro exato ja' aconteceu antes.

**Escopo DESTA sessao:** estrutura de pastas, download validado e manifesto de
proveniencia. A fabrica de simbolos e o StressLab vem depois, em outra sessao.
Nao os implemente agora; apenas crie as pastas vazias com README explicando.

---

## Etapa 0 — Diagnostico

1. Confirme que existe `C:\dev` e liste o que ha' nela (deve existir `SBurn`).
2. Verifique: `node --version` (precisa ser **18 ou superior**), `npm --version`,
   `python --version` (3.9+), e espaco livre em disco (**precisa de 20 GB ou mais**).
3. Verifique se `C:\dev\Historico` ja' existe. Se existir com conteudo, PARE e me
   mostre o que ha' dentro antes de qualquer coisa.
4. Apresente o diagnostico e espere confirmacao.

## Etapa 1 — Estrutura

Crie exatamente esta arvore em `C:\dev\Historico`:

    C:\dev\Historico\
      README.md
      bruto\              <- IMUTAVEL. Nunca editar, nunca sobrescrever.
        XAUUSD\
      calibracao\         <- ticks reais da corretora, usados como referencia
      perfis\             <- perfis de corretora e de estresse (JSON, versionados)
      simbolos\           <- simbolos gerados pela fabrica (vazio por enquanto)
      ferramentas\        <- scripts Python
      .gitignore

O `README.md` da raiz deve explicar, em portugues: o que e' a base, a regra de que
`bruto\` e' imutavel, o conceito de fabrica de simbolos, o significado das
etiquetas de proveniencia, e que projetos consomem simbolos prontos sem tocar no
bruto. Cada subpasta ganha um `README.md` de uma linha dizendo o que guarda.

O `.gitignore` deve excluir `bruto\`, `simbolos\` e `calibracao\` (sao dados
grandes e regeneraveis) e versionar apenas `ferramentas\`, `perfis\` e os READMEs.

Inicialize git e faca o commit `chore: estrutura da base historica universal`.

## Etapa 2 — Instalar e testar a ferramenta com UM mes

Use o **dukascopy-node** (https://github.com/Leo4815162342/dukascopy-node). E'
maduro e testado; nao escreva um downloader proprio.

Baixe **apenas janeiro de 2026** primeiro:

    npx dukascopy-node -i xauusd -from 2026-01-01 -to 2026-02-01 -t tick -f csv --cache

Ajuste `batchSize` para baixo e a pausa entre lotes para cima se houver falha — a
documentacao recomenda isso para periodos longos.

Escolhi janeiro de 2026 de proposito: e' o unico periodo em que existe tick REAL da
Exness para comparar. E' o mes de calibracao.

Ao terminar, me reporte: quantos ticks, tamanho do arquivo, faixa de precos
(gold deve estar entre 500 e 20000 — se estiver fora, a escala esta errada e
PARE), e o primeiro e ultimo timestamp.

## Etapa 3 — Validacao contra a Exness (a etapa que decide tudo)

Escreva `ferramentas\validar_calibracao.py`. Ele compara o mes baixado da
Dukascopy com os ticks reais da Exness do mesmo periodo e responde:

1. **Fuso.** A Dukascopy entrega em **UTC**; o servidor da Exness roda em GMT+2/+3
   com horario de verao. Descubra o deslocamento EMPIRICAMENTE: agregue os dois
   feeds em barras M5 e ache o deslocamento que maximiza a correlacao dos fechos.
   Nao assuma o valor — meca. Se o deslocamento nao for constante ao longo do mes,
   e' horario de verao, e isso precisa estar documentado.
2. **Preco.** Diferenca tipica entre os feeds (mediana e p90, em pontos), depois de
   alinhado o fuso.
3. **Spread.** Distribuicao do spread da Dukascopy vs da Exness. Serao diferentes:
   sao livros de liquidez distintos. Registre as duas.
4. **Lacunas.** Horas presentes num feed e ausentes no outro.

Me apresente o relatorio. **So' avance se o alinhamento fizer sentido.** Se as
barras M5 nao coincidirem, tudo que vier depois estara errado e nao adianta baixar
mais dado.

Peca a mim o arquivo de ticks reais da Exness se ele nao estiver em
`calibracao\` — eu tenho os 8 meses de 2026.

## Etapa 4 — Download completo

So' apos a Etapa 3 aprovada. Baixe **mes a mes, em cascata**, de 2022-01 ate o mes
atual. Um mes por vez, verificando cada um antes do proximo.

Escreva `ferramentas\baixar_historico.py` que orquestra isso chamando o
dukascopy-node, com: retomada (nao rebaixa o que ja' existe), pausa entre meses,
e registro do resultado de cada mes.

Reporte o progresso a cada mes concluido. Isso vai levar horas — nao ha' pressa,
e' melhor devagar e completo do que rapido e furado.

## Etapa 5 — Manifesto de proveniencia

Escreva `ferramentas\gerar_manifesto.py`, que produz
`bruto\XAUUSD\_proveniencia.json` com, para cada mes: origem, numero de ticks,
horas com dados, horas vazias, horas faltantes, primeiro e ultimo timestamp,
faixa de precos, e a data em que foi baixado.

E um relatorio legivel: tabela mes a mes marcando quais tem lacuna. Horas vazias em
fim de semana e feriado sao NORMAIS; horas faltantes em dia util NAO sao.

Commit: `feat(historico): download 2022-2026 com manifesto de proveniencia`.

---

## Regras desta sessao

- **`bruto\` e' imutavel.** Nunca edite, nunca sobrescreva, nunca "corrija" um
  arquivo baixado. Se algo estiver errado, rebaixe e registre.
- **Nao invente numeros.** Fuso, escala de preco e spread saem de medicao, nao de
  suposicao. Se nao der para medir, diga que nao deu.
- **Pare e pergunte** diante de qualquer divergencia do esperado.
- **Nao implemente** a fabrica de simbolos nem o StressLab nesta sessao.
- Ao final, escreva `docs\CHECKPOINT.md` com: o que foi feito, o que ficou
  pendente, e quais numeros de calibracao foram medidos (fuso, spread, diferenca
  de preco). Esse arquivo e' o que a proxima sessao vai ler.
