#===============================================================================
# S-Ps-Setup_Maquina.ps1
#
# PASTA: C:\dev\SBurn\setup\
# COMPILA? Nao (script PowerShell).
# RODAR EM: qualquer PC novo, uma vez, para ligar o repositorio ao MT5.
#
# O QUE FAZ
#   1. Descobre a pasta de dados do terminal MetaTrader 5 EXNESS lendo o
#      origin.txt de cada pasta em %APPDATA%\MetaQuotes\Terminal (o hash da
#      pasta e' derivado do caminho de instalacao - nao chutar).
#   2. Cria o alias C:\MT5\Exness -> pasta de dados do terminal.
#      Existe para que os arquivos VERSIONADOS (.vscode\settings.json e
#      tasks.json) nao carreguem o nome do perfil do Windows, que muda de
#      PC para PC.
#   3. Cria os 3 junctions Indicators\SBurn, Experts\SBurn e Include\SBurn
#      apontando para dentro do repositorio.
#   4. Verifica e imprime o relatorio da maquina.
#
# Idempotente: rodar de novo nao quebra nada, so' reporta o que ja' existe.
# `mklink /J` NAO exige administrador.
#
# USO
#   powershell -ExecutionPolicy Bypass -File setup\S-Ps-Setup_Maquina.ps1
#   powershell -ExecutionPolicy Bypass -File setup\S-Ps-Setup_Maquina.ps1 -Repo D:\dev\SBurn
#
# CUIDADO AO DESFAZER: para remover um junction use `cmd /c rmdir <caminho>`
# (sem /s). `Remove-Item -Recurse` SEGUE o link e apaga os fontes.
#
# CHANGELOG
#   1.00  2026-08-18  Primeira versao. Verificado no PC-Escritorio.
#===============================================================================
[CmdletBinding()]
param(
  [string]$Repo  = "C:\dev\SBurn",
  [string]$Alias = "C:\MT5\Exness",
  # Caminho de instalacao do terminal, como aparece no origin.txt.
  [string]$Instalacao = "C:\Program Files\MetaTrader 5 EXNESS"
)

$ErrorActionPreference = "Stop"
$erros = 0

function Titulo($t) { Write-Host ""; Write-Host "== $t ==" -ForegroundColor Cyan }
function Ok($m)     { Write-Host "  [ok]  $m" -ForegroundColor Green }
function Info($m)   { Write-Host "  .     $m" }
function Falha($m)  { Write-Host "  [!!]  $m" -ForegroundColor Red; $script:erros++ }

Titulo "1. Identidade da maquina"
Info "COMPUTERNAME : $env:COMPUTERNAME"
Info "USERNAME     : $env:USERNAME"
Info "Repositorio  : $Repo"
if (-not (Test-Path (Join-Path $Repo "CLAUDE.md"))) {
  Falha "Nao parece o repositorio SBurn (CLAUDE.md nao encontrado em $Repo)."
  exit 1
}

Titulo "2. Pasta de dados do terminal MT5"
$raiz = Join-Path $env:APPDATA "MetaQuotes\Terminal"
$dados = $null
foreach ($d in (Get-ChildItem -LiteralPath $raiz -Directory)) {
  $o = Join-Path $d.FullName "origin.txt"
  if (-not (Test-Path $o)) { continue }
  # origin.txt e' UTF-16LE com BOM.
  $origem = (Get-Content -LiteralPath $o -Encoding Unicode -Raw).Trim()
  if ($origem -eq $Instalacao) { $dados = $d.FullName; break }
}
if ($null -eq $dados) {
  Falha "Nenhuma pasta de dados aponta para '$Instalacao'."
  Info  "Terminais encontrados:"
  foreach ($d in (Get-ChildItem -LiteralPath $raiz -Directory)) {
    $o = Join-Path $d.FullName "origin.txt"
    if (Test-Path $o) { Info ("  " + $d.Name + " -> " + (Get-Content -LiteralPath $o -Encoding Unicode -Raw).Trim()) }
  }
  Info  "Se o MT5 EXNESS esta' instalado em outro lugar, passe -Instalacao <caminho>."
  exit 1
}
Ok "$dados"

Titulo "3. Alias $Alias"
function Ligar($link, $alvo) {
  if (Test-Path $link) {
    $item = Get-Item -LiteralPath $link -Force
    if ($item.LinkType -eq "Junction") {
      $atual = @($item.Target)[0]
      if ($atual -eq $alvo) { Ok "ja' existe -> $atual"; return }
      Falha "junction existe mas aponta para '$atual' (esperado '$alvo'). Remova com: cmd /c rmdir `"$link`""
      return
    }
    Falha "'$link' existe e NAO e' junction. Nao vou tocar - resolva a mao."
    return
  }
  $pai = Split-Path -Parent $link
  if (-not (Test-Path $pai)) { New-Item -ItemType Directory -Path $pai -Force | Out-Null }
  cmd /c mklink /J "$link" "$alvo" | Out-Null
  if (Test-Path $link) { Ok "criado -> $alvo" } else { Falha "falhou ao criar $link" }
}
Ligar $Alias $dados

Titulo "4. Junctions do projeto"
foreach ($p in @("Indicators","Experts","Include")) {
  Write-Host "  $p\SBurn"
  Ligar (Join-Path $dados "MQL5\$p\SBurn") (Join-Path $Repo "MQL5\$p\SBurn")
}

Titulo "5. Verificacao"
$me = Join-Path $Instalacao "metaeditor64.exe"
if (Test-Path $me) { Ok "metaeditor64.exe presente" } else { Falha "metaeditor64.exe nao encontrado em $Instalacao" }

$esperado = @{
  "MQL5\Indicators\SBurn\S-Ind-ScalpPullback.mq5" = $true
  "MQL5\Experts\SBurn\S-EA-Pullback_Live.mq5"     = $true
  "MQL5\Include\SBurn\S-Include-ConsistencyGate.mqh" = $true
}
foreach ($rel in $esperado.Keys) {
  $viaAlias = Join-Path $Alias $rel
  if (Test-Path $viaAlias) { Ok "$rel visivel pelo alias" } else { Falha "$rel NAO visivel em $viaAlias" }
}

# Pasta IRMA dos CSVs (FILE_COMMON grava aqui, nao na pasta do terminal).
$common = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files\SBurn"
if (-not (Test-Path $common)) { New-Item -ItemType Directory -Path $common -Force | Out-Null; Ok "criada pasta de CSVs $common" }
else { Ok "pasta de CSVs ja' existe: $common" }

Titulo "Resultado"
if ($erros -eq 0) {
  Write-Host "  Maquina parametrizada. Proximo passo: compilar (Ctrl+Shift+B no VS Code)" -ForegroundColor Green
  Write-Host "  ou abrir o MetaEditor e compilar indicadores primeiro, EAs por ultimo." -ForegroundColor Green
  Write-Host ""
  Write-Host "  Registre esta maquina em docs\S-Doc-Maquinas.md se ainda nao estiver la'."
} else {
  Write-Host "  $erros problema(s). Nada foi apagado - resolva os itens marcados [!!]." -ForegroundColor Red
  exit 1
}
