#===============================================================================
# S-Py-Verifica_Rodada.py
#
# PASTA: C:\dev\SBurn\analise\
# COMPILA? Nao (script Python 3).
#
# O QUE FAZ
#   Confere uma rodada do Strategy Tester ANTES de alguem acreditar nela.
#   Tres blocos, todos com veredito explicito e saida != 0 se algum falhar:
#
#     A. RECONCILIACAO  CSV do EA x relatorio do MT5 (n de operacoes e P&L).
#     B. FALHAS         contadores do log do agente (abrir/fechar/BE/piramide).
#     C. REGRESSAO      metricas e INPUTS contra uma referencia gravada.
#
# POR QUE EXISTE
#   Em 2026-08-19 dois erros passaram pela conferencia manual e so' foram pegos
#   por curiosidade: (1) um numero transcrito errado na doc, (2) a v2.06
#   gravando 63 de 65 pernas da piramide - conserto quebrado, sem erro no log.
#   A armadilha 11 manda reproduzir o resultado anterior depois de mexer em
#   codigo validado, mas nao havia ferramenta: era disciplina. Isto e' o
#   mecanismo.
#
# USO
#   # so' reconciliar
#   python analise\S-Py-Verifica_Rodada.py <relatorio.htm>
#
#   # completo
#   python analise\S-Py-Verifica_Rodada.py <relatorio.htm> --log <agente.log>
#          --referencia analise\S-Ref-Referencia.json
#
#   # gravar a referencia a partir de uma rodada JA' verificada
#   python analise\S-Py-Verifica_Rodada.py <relatorio.htm>
#          --gravar-referencia analise\S-Ref-Referencia.json
#
#   O CSV e' descoberto sozinho em Terminal\Common\Files\SBurn (o mais recente),
#   ou informado com --csv.
#
# CHANGELOG
#   1.00  2026-08-19  Primeira versao.
#===============================================================================
import argparse, glob, html, io, json, os, re, sys

# O relatorio do MT5 e' localizado. Aceita os dois idiomas para nao quebrar em
# maquina com idioma diferente (R8).
ROTULOS = {
    "lucro":       ["Lucro L\u00edquido Total", "Total Net Profit"],
    "negociacoes": ["Total de Negocia\u00e7\u00f5es", "Total Trades"],
    "pf":          ["Fator de Lucro", "Profit Factor"],
    "dd_saldo":    ["Rebaixamento M\u00e1ximo do Saldo", "Balance Drawdown Maximal"],
    "dd_capital":  ["Rebaixamento M\u00e1ximo do Capital L\u00edquido",
                    "Equity Drawdown Maximal"],
    "recuperacao": ["Fator de Recupera\u00e7\u00e3o", "Recovery Factor"],
    "qualidade":   ["Qualidade do hist\u00f3rico", "History Quality"],
    "simbolo":     ["Ativo", "Symbol"],
    "periodo":     ["Per\u00edodo", "Period"],
}
# Metricas que a regressao compara. Numericas, tolerancia de centavo.
METRICAS = ["lucro", "negociacoes", "pf", "dd_saldo", "dd_capital", "recuperacao"]


class Erro(Exception):
    pass


def num(txt):
    """Primeiro numero do campo. '23.37 (0.22%)' -> 23.37 ; '10 000.00' -> 10000.0"""
    if txt is None:
        return None
    t = txt.replace("\u00a0", " ")
    m = re.match(r"\s*(-?[\d ]+(?:\.\d+)?)", t)
    if not m:
        return None
    return float(m.group(1).replace(" ", ""))


def decodifica(caminho):
    bruto = io.open(caminho, "rb").read()
    for enc in ("utf-16", "utf-8", "cp1252"):
        try:
            return bruto.decode(enc)
        except Exception:
            pass
    raise Erro("nao consegui decodificar %s" % caminho)


def le_relatorio(caminho):
    """Devolve (metricas, inputs) do .htm do tester."""
    plano = html.unescape(re.sub(r"<[^>]+>", "\t", decodifica(caminho)))
    cels = [c.strip() for c in plano.split("\t") if c.strip()]

    achado = {}
    for i, c in enumerate(cels):
        # O MT5 escreve "Rebaixamento Maximo do Saldo :" - com espaco ANTES dos
        # dois-pontos em alguns rotulos. rstrip(":") sozinho deixa o espaco.
        chave = c.rstrip().rstrip(":").rstrip()
        for nome, variantes in ROTULOS.items():
            if chave in variantes and nome not in achado and i + 1 < len(cels):
                achado[nome] = cels[i + 1]

    # Eco dos inputs: linhas "InpNome=Valor" na secao de parametros.
    inputs = {}
    for c in cels:
        m = re.match(r"^(Inp[A-Za-z0-9_]+)=(.*)$", c)
        if m:
            inputs[m.group(1)] = m.group(2).strip()

    return achado, inputs


def acha_csv(explicito):
    if explicito:
        return explicito
    base = os.path.join(os.environ.get("APPDATA", ""),
                        "MetaQuotes", "Terminal", "Common", "Files", "SBurn")
    cands = glob.glob(os.path.join(base, "ops_*.csv"))
    return max(cands, key=os.path.getmtime) if cands else None


def le_csv(caminho):
    """Le sem pandas: o formato e' simples e a dependencia nao se justifica."""
    txt = io.open(caminho, encoding="cp1252", errors="replace").read()
    linhas = [l for l in txt.splitlines() if l.strip()]
    if not linhas:
        raise Erro("CSV vazio: %s" % caminho)
    cols = linhas[0].split(";")
    regs = []
    for l in linhas[1:]:
        v = l.split(";")
        if len(v) != len(cols):
            raise Erro("linha com %d campos, cabecalho tem %d: %s"
                       % (len(v), len(cols), l[:70]))
        regs.append(dict(zip(cols, v)))
    return cols, regs


def le_falhas(caminho):
    """Contadores da linha de resumo do EA no log do agente."""
    txt = decodifica(caminho)
    out = {}
    padroes = (
        (r"falhas: sinal=(\d+) contexto=(\d+) abrir=(\d+) fechar=(\d+)",
         ["sinal", "contexto", "abrir", "fechar"]),
        (r"breakeven: recusas=(\d+) \| posicoes que DESISTIRAM e correram sem BE=(\d+)",
         ["be_recusas", "be_desistiu"]),
        (r"piramide: adicoes=(\d+) rejeitadas=(\d+) sem_ticket=(\d+)",
         ["pir_adicoes", "pir_rejeitadas", "pir_sem_ticket"]),
        (r"pernas de piramide=(\d+)", ["pir_gravadas"]),
    )
    for pat, chaves in padroes:
        achados = re.findall(pat, txt)
        if not achados:
            continue
        # O log ACUMULA as rodadas do dia. Vale sempre a ULTIMA ocorrencia -
        # contar o arquivo inteiro foi exatamente como eu errei a armadilha 18.
        ult = achados[-1]
        ult = ult if isinstance(ult, tuple) else (ult,)
        for k, v in zip(chaves, ult):
            out[k] = int(v)
    return out


def main():
    ap = argparse.ArgumentParser(description="Verifica uma rodada do Strategy Tester")
    ap.add_argument("relatorio")
    ap.add_argument("--csv")
    ap.add_argument("--log")
    ap.add_argument("--referencia")
    ap.add_argument("--gravar-referencia", dest="gravar")
    ap.add_argument("--tolerancia", type=float, default=0.01)
    a = ap.parse_args()

    ref = None
    if a.referencia and os.path.exists(a.referencia):
        ref = json.load(io.open(a.referencia, encoding="utf-8"))

    metr, inputs = le_relatorio(a.relatorio)
    print("== rodada ==")
    print("  relatorio    : %s" % os.path.basename(a.relatorio))
    print("  simbolo/TF   : %s %s" % (metr.get("simbolo", "?"), metr.get("periodo", "?")))
    print("  qualidade    : %s" % metr.get("qualidade", "?"))
    print("  inputs no eco: %d" % len(inputs))

    problemas = []

    # ------------------------------------------------------------------ A
    print("")
    print("== A. reconciliacao CSV x relatorio ==")
    csv = acha_csv(a.csv)
    n_rel = num(metr.get("negociacoes"))
    l_rel = num(metr.get("lucro"))
    if not csv or not os.path.exists(csv):
        print("  [--]  CSV nao encontrado - bloco pulado (rodar com InpLogCSV=true)")
    else:
        cols, regs = le_csv(csv)
        print("  .     %s (%d colunas, %d linhas)"
              % (os.path.basename(csv), len(cols), len(regs)))
        if "origem" in cols:
            por = {}
            for r in regs:
                por[r["origem"]] = por.get(r["origem"], 0) + 1
            print("  .     por origem: %s"
                  % ", ".join("%s=%d" % kv for kv in sorted(por.items())))

        if n_rel is None:
            problemas.append("relatorio sem o total de negociacoes")
        elif len(regs) == int(n_rel):
            print("  [ok]  operacoes: CSV %d == relatorio %d" % (len(regs), int(n_rel)))
        else:
            problemas.append("operacoes: CSV %d != relatorio %d (diferenca %d)"
                             % (len(regs), int(n_rel), int(n_rel) - len(regs)))

        if "pnl_moeda" in cols and l_rel is not None:
            soma = sum(float(r["pnl_moeda"]) for r in regs if r["pnl_moeda"].strip())
            if abs(soma - l_rel) <= a.tolerancia:
                print("  [ok]  P&L: CSV %.2f == relatorio %.2f" % (soma, l_rel))
            else:
                problemas.append("P&L: CSV %.2f != relatorio %.2f (diferenca %.2f)"
                                 % (soma, l_rel, soma - l_rel))

        # Coluna inteira constante em zero/vazio e' o sintoma da armadilha 13.
        if regs:
            const = [c for c in cols
                     if len(set(r[c] for r in regs)) == 1
                     and regs[0][c].strip() in ("0", "0.0", "")]
            if const:
                print("  [!?]  colunas constantes em zero/vazio: %s" % ", ".join(const))
                print("        nem sempre e' erro, mas confira - e' a armadilha 13")

    # ------------------------------------------------------------------ B
    print("")
    print("== B. contadores de falha ==")
    if not a.log:
        print("  [--]  sem --log - bloco pulado")
    else:
        f = le_falhas(a.log)
        if not f:
            print("  [--]  nenhum contador reconhecido no log")
        else:
            print("  .     %s" % ", ".join("%s=%d" % kv for kv in sorted(f.items())))
            criticos = ("sinal", "contexto", "abrir", "fechar", "be_desistiu",
                        "pir_rejeitadas", "pir_sem_ticket")
            #--- Sem referencia, qualquer falha e' problema (conservador). Com
            #    referencia, o que alerta e' a MUDANCA do perfil de falhas: as
            #    conhecidas continuam impressas, mas nao viram ruido a cada
            #    rodada. Alerta que sempre dispara e' alerta que ninguem le.
            esperadas = (ref or {}).get("falhas_esperadas")
            for k in criticos:
                obt = f.get(k, 0)
                if esperadas is None:
                    if obt > 0:
                        problemas.append("contador '%s' = %d - a rodada teve falha" % (k, obt))
                else:
                    esp = esperadas.get(k, 0)
                    if obt != esp:
                        problemas.append("contador '%s' = %d, a referencia tem %d"
                                         % (k, obt, esp))
            if esperadas is not None:
                conhecidas = ", ".join("%s=%d" % (k, v)
                                       for k, v in sorted(esperadas.items()) if v)
                print("  [ok]  perfil de falhas igual ao da referencia (%s)"
                      % (conhecidas if conhecidas else "nenhuma"))
            # Toda adicao aberta tem de virar linha no CSV. Foi este o bug da v2.06.
            if "pir_adicoes" in f and "pir_gravadas" in f:
                if f["pir_adicoes"] == f["pir_gravadas"]:
                    print("  [ok]  piramide: %d adicoes == %d gravadas"
                          % (f["pir_adicoes"], f["pir_gravadas"]))
                else:
                    problemas.append("piramide: %d adicoes mas %d gravadas no CSV"
                                     % (f["pir_adicoes"], f["pir_gravadas"]))

    # ------------------------------------------------------------------ C
    print("")
    print("== C. regressao contra a referencia ==")
    if ref is not None:
        print("  .     %s (%s)" % (os.path.basename(a.referencia),
                                   ref.get("gravado_em", "sem data")))
        for k in METRICAS:
            esp, obt = ref["metricas"].get(k), num(metr.get(k))
            if esp is None or obt is None:
                problemas.append("metrica '%s' ausente de um dos lados" % k)
            elif abs(esp - obt) <= a.tolerancia:
                print("  [ok]  %-12s %.2f" % (k, obt))
            else:
                problemas.append("%s: esperado %.2f, obtido %.2f" % (k, esp, obt))
        # Inputs: e' a armadilha 5 (o tester guarda os inputs da rodada anterior).
        difs = []
        for k, v in sorted(ref.get("inputs", {}).items()):
            if k not in inputs:
                difs.append("%s AUSENTE (esperado %s)" % (k, v))
            elif inputs[k] != v:
                difs.append("%s = %s (esperado %s)" % (k, inputs[k], v))
        for d in difs:
            problemas.append("input divergente: %s" % d)
        if not difs:
            print("  [ok]  %d inputs identicos aos da referencia"
                  % len(ref.get("inputs", {})))
    else:
        print("  [--]  sem --referencia - bloco pulado")

    # ------------------------------------------------------------ gravacao
    if a.gravar:
        if not a.log:
            raise Erro("gravar referencia exige --log: sem ele o perfil de "
                       "falhas esperadas ficaria vazio e a checagem nasceria cega")
        novo = {
            "gravado_em": "2026-08-19",
            "relatorio": os.path.basename(a.relatorio),
            "simbolo": metr.get("simbolo"),
            "periodo": metr.get("periodo"),
            "qualidade": metr.get("qualidade"),
            "metricas": dict((k, num(metr.get(k))) for k in METRICAS),
            "falhas_esperadas": le_falhas(a.log),
            "inputs": inputs,
        }
        # newline="" e' obrigatorio: em modo texto no Windows o Python
        # converte a quebra de linha e o arquivo sai em CRLF, quebrando a
        # invariante `* -text` do repositorio (ver S-Doc-Maquinas.md).
        io.open(a.gravar, "w", encoding="utf-8", newline="").write(
            json.dumps(novo, indent=2, ensure_ascii=False) + "\n")
        print("")
        print("  referencia GRAVADA em %s" % a.gravar)

    # ------------------------------------------------------------- veredito
    print("")
    print("== veredito ==")
    if problemas:
        for p in problemas:
            print("  [!!]  %s" % p)
        print("")
        print("  %d problema(s). NAO usar esta rodada antes de resolver." % len(problemas))
        return 1
    print("  Rodada consistente. Nenhum problema encontrado.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Erro as e:
        print("ERRO: %s" % e)
        sys.exit(2)
