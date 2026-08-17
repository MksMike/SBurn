# Prompt para o Claude Code — setup do ambiente SBurn

Cole o bloco abaixo no Claude Code, com o terminal aberto em `C:\dev\SBurn`
(crie a pasta e extraia o zip antes: o conteudo de `SB/` vai na raiz dela).

---

Voce esta configurando o ambiente de desenvolvimento do projeto SBurn (MQL5 /
MetaTrader 5). Leia `CLAUDE.md` na raiz ANTES de qualquer acao — ele contem as
regras do projeto, o estado empirico e as armadilhas conhecidas. Responda em
portugues do Brasil.

Trabalhe em etapas e me mostre o resultado de cada uma antes de seguir para a
proxima. Nao execute nada destrutivo sem me perguntar.

## Etapa 1 — Diagnostico

1. Liste a arvore de `C:\dev\SBurn` e confirme que existem: `CLAUDE.md`,
   `README.md`, `.gitignore`, e as pastas `indicators/`, `experts/`, `include/`,
   `analise/`, `docs/`, `dados/`.
2. Descubra a pasta de dados do MetaTrader 5. Ela e' a que contem `MQL5\Experts`.
   O caminho conhecido deste projeto e':
   `%APPDATA%\MetaQuotes\Terminal\53785E099C927DB68A545C249CDBCE06`
   Confirme se existe; se houver mais de um terminal instalado, liste todos e me
   pergunte qual usar.
3. Verifique se `git` esta instalado e se ja' existe um repositorio em
   `C:\dev\SBurn`. Verifique tambem se `gh` (GitHub CLI) esta disponivel.
4. Me apresente o diagnostico antes de mudar qualquer coisa.

## Etapa 2 — Junctions para o MetaTrader

O MetaEditor compila o `.ex5` ao lado do `.mq5` aberto. Para o repositorio ser a
unica fonte de verdade, o MT5 precisa VER as pastas do repositorio — por junction,
nao por copia. Copia gera duas versoes do mesmo arquivo, e isso ja' custou uma
madrugada de depuracao neste projeto.

Crie (cmd como administrador; me avise se precisar de elevacao):

    mklink /J "<PastaDeDados>\MQL5\Indicators\SBurn" "C:\dev\SBurn\indicators"
    mklink /J "<PastaDeDados>\MQL5\Experts\SBurn"    "C:\dev\SBurn\experts"
    mklink /J "<PastaDeDados>\MQL5\Include\SBurn"    "C:\dev\SBurn\include"

Se ja' existir uma pasta real (nao junction) em algum desses caminhos, PARE e me
mostre o conteudo dela antes de qualquer coisa — pode conter versoes antigas dos
mesmos arquivos, e a prioridade e' nao perder nada nem deixar duplicata para tras.

Depois de criar, valide: liste o conteudo pelo caminho do MT5 e confirme que
aparecem os arquivos do repositorio.

## Etapa 3 — Git local

1. `git init` (se ainda nao houver repositorio) e `git branch -M main`.
2. Confirme que o `.gitignore` cobre: `*.ex5`, `*.ex4`, `*.log`, `dados/*.csv`,
   `dados/*.html`, `dados/*.xlsx`. Os `.ex5` NAO devem ser versionados — sao
   binarios regeneraveis e mudam a cada compilacao.
3. `git add` e faca os commits SEPARADOS POR UNIDADE LOGICA, nesta ordem, usando
   estas mensagens:

   - `chore: estrutura do repositorio, .gitignore e documentacao`
     (CLAUDE.md, README.md, .gitignore, docs/, dados/README.md)
   - `feat(indicators): ScalpPullback v2.02 e TMO_Scalper v4.02`
     (indicators/)
   - `feat(include): ConsistencyGate v1.02 e MovConsistency`
     (include/)
   - `feat(experts): EA de medicao v1.20 e EA operacional v1.07`
     (experts/)
   - `feat(analise): scripts Python de analise e comparacao`
     (analise/)

4. Mostre `git log --oneline` e `git status` ao final.

## Etapa 4 — GitHub

1. Pergunte se o repositorio deve ser **privado** (recomendado — contem estrategia
   propria) e qual o nome (sugestao: `sburn`).
2. Se o `gh` estiver autenticado, crie o repositorio remoto e faca o push.
   Se nao estiver, me diga exatamente o comando de login e espere eu executar.
3. NAO faca push de nada em `dados/` nem de `.ex5`.
4. Confirme com `git remote -v` e o link do repositorio.

## Etapa 5 — VS Code

1. Crie `.vscode/settings.json` com: `files.encoding` em `windows1252` para
   `*.mq5` e `*.mqh` (o MetaEditor nao usa UTF-8), `files.eol` em `\r\n`, e
   `files.trimTrailingWhitespace` ativo.
2. Crie `.vscode/extensions.json` recomendando uma extensao de realce MQL5.
3. Adicione uma task em `.vscode/tasks.json` que chame o `metaeditor64.exe` com
   `/compile` para compilar um arquivo pelo VS Code. Procure o executavel; se nao
   achar, deixe o caminho como placeholder comentado e me avise.
4. Commit: `chore(vscode): configuracao do editor e task de compilacao`.

## Etapa 6 — Verificacao final

1. Abra o MetaEditor e compile nesta ordem: os dois indicadores primeiro, depois
   os dois EAs. Me reporte qualquer erro ou warning — nao tente "consertar" codigo
   validado por conta propria; me mostre o erro e espere.
2. Confirme que os `.ex5` foram gerados dentro das pastas do repositorio (via
   junction) e que o `git status` NAO os lista (o .gitignore deve estar pegando).
3. Resumo final: o que foi feito, o que ficou pendente, qual o proximo passo.

## Regras para esta sessao

- Nao altere logica de nenhum `.mq5` ou `.mqh`. Este setup e' infraestrutura; o
  codigo ja' foi auditado e o comportamento esta congelado.
- Se algo divergir do esperado, PARE e pergunte. Neste projeto, prosseguir com
  incerteza ja' custou rodadas inteiras de teste.
- Nunca sobrescreva arquivo existente sem antes me mostrar o que ha' nele.
