# SBurn — Registro de Maquinas
**Versao:** 1.0 | **Atualizado:** 2026-08-18

Este projeto roda em mais de um PC. Os arquivos versionados NAO podem conter
caminho que dependa da maquina — o nome do perfil do Windows muda de PC para PC.
Este documento e' o unico lugar onde caminho real de maquina aparece.

---

## 1. Como o projeto fica independente de maquina

O repositorio espelha o caminho `MQL5\...` do MetaTrader. A ligacao entre os dois
e' feita por junctions, e o caminho da pasta de dados do terminal e' abstraido por
um **alias**:

    C:\MT5\Exness   ->  %APPDATA%\MetaQuotes\Terminal\<hash>\      (junction)

Com isso, `.vscode\settings.json` e `.vscode\tasks.json` apontam sempre para
`C:\MT5\Exness\MQL5`, em qualquer PC, e nenhum deles precisa ser editado ao trocar
de maquina.

O `<hash>` da pasta de dados e' derivado do caminho de INSTALACAO do terminal.
Nao chutar: o script de setup le o `origin.txt` de cada pasta e casa pelo caminho
de instalacao.

### O que e' por maquina (nao versionado)

| Item | Onde vive |
|---|---|
| Alias `C:\MT5\Exness` | sistema de arquivos |
| Junctions `Indicators\SBurn`, `Experts\SBurn`, `Include\SBurn` | sistema de arquivos |
| Identidade do git (`user.email`) | `.git\config` (local do repo) |
| Login do terminal, historico de ticks, caches do tester | pasta de dados do MT5 |
| `.ex5`, `dados\*.csv`, logs | ignorados pelo `.gitignore` |

### Parametrizar um PC novo

    git clone https://github.com/MksMike/SBurn.git C:\dev\SBurn
    cd C:\dev\SBurn
    powershell -ExecutionPolicy Bypass -File setup\S-Ps-Setup_Maquina.ps1

O script e' idempotente: descobre a pasta de dados, cria o alias e os 3 junctions,
cria a pasta de CSVs em `Terminal\Common\Files\SBurn` e verifica tudo. Se o MT5
EXNESS estiver instalado fora de `C:\Program Files\MetaTrader 5 EXNESS`, passe
`-Instalacao <caminho>`. Se o repositorio nao estiver em `C:\dev\SBurn`, passe
`-Repo <caminho>`.

Depois: identidade do git, dependencias de analise, compilacao.

    git config --local user.name  "Mike Inoue"
    git config --local user.email "<email da conta do GitHub>"
    python -m pip install pandas scipy
    # VS Code: Ctrl+Shift+B  (ou MetaEditor F7 — indicadores primeiro, EAs por ultimo)

**Desfazer junction:** `cmd /c rmdir "<caminho>"` (sem `/s`). `Remove-Item -Recurse`
do PowerShell SEGUE o link e apaga os fontes.

---

## 2. Maquinas registradas

| Apelido | COMPUTERNAME | Perfil Windows | Repositorio | Status |
|---|---|---|---|---|
| **PC-Escritorio** | `MIKE-PC` | `Mike Inoue` | `C:\dev\SBurn` | ativo, parametrizado em 2026-08-18 |

### Perfis vistos no historico do repositorio (ainda sem apelido)

O repositorio ja' carregou caminhos de outros dois perfis. Se ainda forem maquinas
em uso, registrar aqui com apelido; se nao, sao historico morto.

| Perfil | Onde apareceu | Situacao |
|---|---|---|
| `mikem` | `.vscode\settings.json` ate' 2026-08-18 (removido pelo alias) | nao identificada |
| `fabul` | `docs\S-Doc-Handoff_Sessao.md` secao 1 (ainda la') | nao identificada |

---

## 3. PC-Escritorio — estado medido em 2026-08-18

| Item | Valor |
|---|---|
| COMPUTERNAME | `MIKE-PC` |
| Windows | 11 Pro 10.0.26200 |
| Repositorio | `C:\dev\SBurn` (clone de `github.com/MksMike/SBurn`, branch `main`) |
| MT5 EXNESS | `C:\Program Files\MetaTrader 5 EXNESS`, terminal build **5.0.0.6090** |
| Pasta de dados | `C:\Users\Mike Inoue\AppData\Roaming\MetaQuotes\Terminal\53785E099C927DB68A545C249CDBCE06` |
| Alias | `C:\MT5\Exness` -> pasta de dados (junction) |
| CSVs (FILE_COMMON) | `C:\Users\Mike Inoue\AppData\Roaming\MetaQuotes\Terminal\Common\Files\SBurn` (criada vazia) |
| Python | 3.12.10 + pandas 3.0.5 + scipy 1.18.0 |
| VS Code | 1.129.0 + `l-i-v.mql-tools` 2.2.0 + `user413.mql5-vscode-snippets` 1.0.0 |
| git / gh | 2.55.0 / 2.96.0, autenticado como `MksMike` |
| Integridade dos fontes | `git ls-files --eol` = `i/lf w/lf attr/-text` — LF puro, UTF-8 sem BOM, conversao desligada apesar de `core.autocrlf=true` global |

**Compilacao verificada** (metaeditor64 via CLI, `/inc:C:\MT5\Exness\MQL5`):
os 4 fontes compilaram com **0 erros, 0 warnings**, e os `.ex5` nasceram dentro do
repositorio — o MT5 enxerga o mesmo arquivo pelo junction, sem copia.

### Outros terminais MT5 nesta maquina (nao usar para o SBurn)

| Hash | Instalacao |
|---|---|
| `010E047102812FC0C18890992854220E` | MetaTrader 5 IC Markets Global |
| `F634CD449B3DB36D8BC52B7681BD9571` | BigBoss Mauritius MT5 Terminal |

---

## 4. PENDENTE nesta maquina: historico de ticks reais

**O ambiente compila e opera, mas ainda NAO reproduz o resultado de referencia.**

O terminal EXNESS desta maquina esta' logado em **conta 238363456, servidor
`Exness-MT5Real3`**. O resultado de referencia do projeto (137 trades, +$1.308,59,
DD $49,25, PF 5,83) foi medido em **`Exness-MT5Real41`**, conta 419168436.

Cobertura de ticks reais de XAUUSDm ja' baixada localmente (`bases\<servidor>\ticks\`):

| Servidor | Meses de tick presentes |
|---|---|
| `Exness-MT5Real41` | **so' 202608** |
| `Exness-MT5Trial5` | 202601 a 202608 (completo) |
| `Exness-MT5Trial3` | so' 202608 |

Consequencia direta da regra do projeto ("backtest so' com *Every tick based on real
ticks*"; o desenho e' path-dependent): rodar o backtest de referencia agora
produziria numero **invalido**, nao apenas diferente — faltam 7 dos 8 meses no
servidor certo.

**Para fechar a pendencia** (ordem importa — o passo 3 e' novo e nao e' opcional):

1. Logar o terminal em uma conta de `Exness-MT5Real41`, abrir XAUUSDm e deixar o
   MT5 baixar os ticks de 2026.01 a 2026.08.
2. Exportar os ticks (Simbolos > XAUUSDm > Ticks > Exportar) para
   `C:\dev\Historico\`.
3. **Rodar `analise\S-Py-Perfil_Spread.py` sobre o export e ler a coluna
   `trocas/1M`.** Baixar tick nao garante tick vivo: em 2026-08-18 mediu-se
   2026.01 do XAUUSD@Real3 com spread constante (armadilha 13 do CLAUDE.md). Se o
   mesmo defeito estiver no XAUUSDm, o periodo de referencia muda e rodar o
   backtest antes disso so' produz numero bonito e invalido.
4. So' entao rodar `S-EA-Pullback_Live` com os defaults (M5, 0.01 lote) na janela
   que sobreviver ao passo 3, e conferir contra os numeros do README.

Enquanto os numeros nao baterem, esta maquina **nao** e' base valida para promover
ou reprovar hipotese.

Nao substituir por `Exness-MT5Trial5` "porque tem os 8 meses": servidor diferente e'
base de ticks diferente. Se um dia for usado de proposito, e' um experimento com
proveniencia propria, declarada — nunca uma troca silenciosa (R3).
