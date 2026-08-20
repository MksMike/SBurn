#===============================================================================
# S-Py-Descartado_Spread.py
#
# PASTA: C:\dev\SBurn\analise\
# COMPILA? Nao (script Python 3).
#
# A PERGUNTA
#   Abril e maio tiveram ZERO operacoes: o corte absoluto `InpMaxSpread=260`
#   barrou 100% dos sinais. Duas leituras preveem coisas opostas:
#
#     (a) o mercado estava ruim e o filtro ACERTOU ao ficar de fora;
#     (b) a linha de base SUBIU (308 em abril valia o que 260 valia em marco)
#         e a regua ficou presa.
#
#   Trocar o absoluto por percentil movel sem separar as duas e' apostar em (b)
#   sem prova. Aplica-se a lei do projeto: o valor de um filtro e' o desempenho
#   do que ele REMOVE.
#
# PRE-REGISTRO (R2) - escrito ANTES de ver qualquer desfecho
#
#   Metrica: assimetria = medMFE - medMAE na Entrada A, horizontes 5/15/30
#   barras, normalizada por `atr_ent` (em ATR, nunca em pontos - armadilha 17b).
#
#   TESTE 1 (o pedido, CONFUNDIDO): rejeitados de abril+maio contra os aceitos
#   dos OUTROS meses. Como abril/maio rejeitam 100%, nao existe grupo aceito
#   dentro deles: a comparacao mistura efeito de FILTRO com efeito de MES e
#   isso vai declarado junto do numero, nao em nota de rodape.
#
#   TESTE 2 (limpo quanto a mes): dentro de fevereiro e junho existem os DOIS
#   grupos (54% e 56% de rejeicao). Comparar rejeitados contra aceitos DENTRO
#   do mesmo mes responde "spread > 260 seleciona sinal pior?" sem confusao de
#   mes. Nao responde sobre abril/maio especificamente - responde sobre o
#   MECANISMO do filtro.
#
#   DECISAO, por IC95 bootstrap da diferenca de assimetria em 15 barras:
#     - IC95 inteiramente ABAIXO de zero  -> rejeitados sao piores. O filtro fez
#       o trabalho dele; percentil movel so' adicionaria perdedor. FRENTE MORRE.
#     - IC95 contendo zero E |diferenca| < 0,10 ATR (~2x o custo) -> rejeitados
#       sao normais. A regua estava presa; percentil se justifica.
#     - IC95 mais largo que 0,40 ATR -> SEM PODER. Dizer "inconclusivo", nao
#       escolher o lado que agrada.
#
#   O bootstrap reamostra por DIA, nao por sinal: tres dias respondem por 61%
#   do lucro da estrategia, entao sinal nao e' unidade independente. (Medido:
#   por dia e por sinal dao IC praticamente igual - 1,536 contra 1,584 ATR -
#   entao quem domina e' a dispersao bruta, nao o agrupamento.)
#
#   SEGUNDA RODADA, com desfecho LIMITADO. A assimetria saiu inconclusiva por
#   dispersao: MFE15/ATR tem p25=0,76 e p75=3,56, ou seja ~2,8 ATR entre
#   quartis contra um efeito procurado de ~0,2. Desfecho truncado por stop tem
#   variancia muito menor. Usa-se `tr_1` (trailing 2000 pts) porque e' a UNICA
#   coluna de saida simulada SEM sentinela: min = -2000, o proprio stop, para
#   os 568 sinais. As colunas `be_a*`, `tr_4` e `ct_*` gravam -999999 =
#   "nao saiu" e somar isso como P&L da' media de -56.726 pts (armadilha 13).
#   `tr_1` NAO e' a estrategia titular - e' regua comum aplicada igualmente aos
#   dois grupos, que e' o que a pergunta comparativa exige.
#
#   Criterio em P&L: IC95 todo abaixo de zero -> rejeitados piores; IC95
#   contendo zero, |diferenca| < custo (260 pts) E largura do IC95 <= 2x o
#   custo -> normais; qualquer largura maior -> SEM PODER.
#
#   CORRECAO 2026-08-20: a largura-limite era 4x o custo, frouxa demais. Um IC
#   de [-453, +381] cobre 3,2x o custo: nao distingue "rejeitados normais" de
#   "rejeitados bem piores". Com 4x, a primeira rodada declarava NORMAIS um
#   resultado que e' INCONCLUSIVO. O limite passa a 2x.
#
#   RESSALVA SOBRE `tr_1`, que muda o peso do resultado: foi escolhido por
#   DISPONIBILIDADE (unica coluna sem sentinela), nao por pre-registro. E
#   `InpTrail1=2000 pts` = 0,37 x ATR de TRAILING, enquanto o EA operacional usa
#   BE no zero com stop 3,67 x ATR. Trailing esta' na lista de hipoteses MORTAS
#   da secao 5.4 ("4 distancias + modulacao ATR; familia dominada"). O desfecho
#   limitado disponivel pertence a uma familia ja' enterrada: o resultado NAO
#   transfere para a estrategia titular. Serve como regua comparativa e nada mais.
#
# USO
#   python analise\S-Py-Descartado_Spread.py [csv]
#
# CHANGELOG
#   1.00  2026-08-20  Primeira versao.
#===============================================================================
import glob
import os
import sys

import numpy as np
import pandas as pd

CORTE = 260.0          # InpMaxSpread do EA operacional
HORIZONTES = [5, 15, 30]
N_BOOT = 5000
SEMENTE = 20260820     # fixa: o resultado tem de ser reproduzivel


def acha_csv(arg):
    if arg:
        return arg
    base = os.path.join(os.environ.get("APPDATA", ""), "MetaQuotes",
                        "Terminal", "Common", "Files", "SBurn")
    c = glob.glob(os.path.join(base, "test_consistgate_*.csv"))
    if not c:
        sys.exit("CSV do gate nao encontrado")
    return max(c, key=os.path.getmtime)


def assim(d, h):
    """medMFE - medMAE em ATR, horizonte h, Entrada A."""
    if len(d) == 0:
        return np.nan
    a = d["atr_ent"].where(d["atr_ent"] > 0)
    return (d["mfe%d_A" % h] / a).median() - (d["mae%d_A" % h] / a).median()


def boot_dif(da, db, h, rng):
    """IC95 da diferenca assim(da) - assim(db), reamostrando por DIA."""
    out = []
    for grupo in (da, db):
        dias = grupo["dia"].unique()
        amostras = []
        for _ in range(N_BOOT):
            esc = rng.choice(dias, size=len(dias), replace=True)
            sub = pd.concat([grupo[grupo["dia"] == d] for d in esc])
            amostras.append(assim(sub, h))
        out.append(np.array(amostras))
    d = out[0] - out[1]
    d = d[~np.isnan(d)]
    return float(np.percentile(d, 2.5)), float(np.percentile(d, 97.5))


def veredito(dif, lo, hi):
    larg = hi - lo
    if larg > 0.40:
        return "INCONCLUSIVO - IC95 de %.3f ATR de largura, sem poder" % larg
    if hi < 0:
        return "REJEITADOS PIORES - o filtro fez o trabalho dele"
    if lo > 0:
        return "REJEITADOS MELHORES - o filtro jogava fora sinal bom"
    if abs(dif) < 0.10:
        return "REJEITADOS NORMAIS - a regua estava presa"
    return "IC contem zero mas a diferenca pontual e' grande - sem conclusao"


def descreve(rot, d):
    linha = "  %-34s n=%-4d" % (rot, len(d))
    for h in HORIZONTES:
        linha += "  %2db=%+6.3f" % (h, assim(d, h))
    print(linha)


def main():
    caminho = acha_csv(sys.argv[1] if len(sys.argv) > 1 else None)
    df = pd.read_csv(caminho, sep=";", encoding="cp1252",
                     on_bad_lines="skip").copy()
    t = pd.to_datetime(df["time_sig"], errors="coerce", format="mixed")
    df["mes"] = t.dt.to_period("M").astype(str)
    df["dia"] = t.dt.date
    df["rej"] = df["spread_sig_pts"] > CORTE

    print("arquivo: %s" % os.path.basename(caminho))
    print("sinais : %d | corte: %.0f pts | assimetria em ATR" % (len(df), CORTE))

    print("")
    print("=" * 74)
    print("REJEICAO POR MES")
    print("=" * 74)
    print("  %-9s %5s %8s %9s %8s" % ("mes", "n", "mediana", "rejeit", "aceitos"))
    for m, g in df.groupby("mes"):
        print("  %-9s %5d %8.0f %8.1f%% %8d"
              % (m, len(g), g["spread_sig_pts"].median(),
                 100 * g["rej"].mean(), int((~g["rej"]).sum())))

    rng = np.random.default_rng(SEMENTE)
    alvo = df[df["mes"].isin(["2026-04", "2026-05"])]

    # ------------------------------------------------------------- TESTE 1
    print("")
    print("=" * 74)
    print("TESTE 1 - rejeitados de abril+maio x aceitos dos OUTROS meses")
    print("=" * 74)
    print("  CONFUNDIDO POR MES, e isto nao e' rodape: abril/maio rejeitam 100%,")
    print("  entao nao existe grupo aceito dentro deles. A diferenca abaixo")
    print("  mistura efeito de FILTRO com efeito de MES e nao os separa.")
    print("")
    a1 = alvo[alvo["rej"]]
    b1 = df[(~df["rej"]) & (~df["mes"].isin(["2026-04", "2026-05"]))]
    descreve("rejeitados abr+mai", a1)
    descreve("aceitos dos outros meses", b1)
    print("  %-34s n=%-4d" % ("(referencia) todos os sinais", len(df)), end="")
    print("  " + "  ".join("%2db=%+6.3f" % (h, assim(df, h)) for h in HORIZONTES))

    d1 = assim(a1, 15) - assim(b1, 15)
    lo1, hi1 = boot_dif(a1, b1, 15, rng)
    print("")
    print("  diferenca 15b: %+.3f ATR   IC95 [%+.3f, %+.3f]" % (d1, lo1, hi1))
    print("  -> %s" % veredito(d1, lo1, hi1))

    # ------------------------------------------------------------- TESTE 2
    print("")
    print("=" * 74)
    print("TESTE 2 - dentro de fevereiro e junho (limpo quanto a mes)")
    print("=" * 74)
    print("  Estes dois meses tem os DOIS grupos. Responde 'spread > 260")
    print("  seleciona sinal pior?' sem confusao de mes. Nao responde sobre")
    print("  abril/maio - responde sobre o MECANISMO do filtro.")
    print("")
    for m in ("2026-02", "2026-06"):
        g = df[df["mes"] == m]
        a, b = g[g["rej"]], g[~g["rej"]]
        descreve("%s rejeitados" % m, a)
        descreve("%s aceitos" % m, b)
        if len(a) >= 20 and len(b) >= 20:
            d = assim(a, 15) - assim(b, 15)
            lo, hi = boot_dif(a, b, 15, rng)
            print("    diferenca 15b: %+.3f ATR   IC95 [%+.3f, %+.3f]" % (d, lo, hi))
            print("    -> %s" % veredito(d, lo, hi))
        else:
            print("    grupos pequenos - nao avalio")
        print("")

    # combinado fev+jun, pareado por mes
    g = df[df["mes"].isin(["2026-02", "2026-06"])]
    a, b = g[g["rej"]], g[~g["rej"]]
    d = assim(a, 15) - assim(b, 15)
    lo, hi = boot_dif(a, b, 15, rng)
    print("  COMBINADO fev+jun: %+.3f ATR   IC95 [%+.3f, %+.3f]" % (d, lo, hi))
    print("  -> %s" % veredito(d, lo, hi))

    # ------------------------------------------------- DESFECHO LIMITADO
    print("")
    print("=" * 74)
    print("SEGUNDA RODADA - desfecho LIMITADO (tr_1), P&L em pontos")
    print("=" * 74)
    print("  A assimetria e' dispersa demais para decidir. tr_1 e' a unica")
    print("  coluna de saida simulada SEM sentinela -999999. Nao e' a")
    print("  estrategia titular: e' regua comum aplicada aos dois grupos.")
    print("")

    def boot_pnl(x, y, col, n=4000):
        dx, dy = x["dia"].unique(), y["dia"].unique()
        ix = {d: x[x["dia"] == d][col].values for d in dx}
        iy = {d: y[y["dia"] == d][col].values for d in dy}
        o = []
        for _ in range(n):
            o.append(np.concatenate([ix[d] for d in rng.choice(dx, len(dx), True)]).mean()
                     - np.concatenate([iy[d] for d in rng.choice(dy, len(dy), True)]).mean())
        o = np.array(o)
        return float(np.percentile(o, 2.5)), float(np.percentile(o, 97.5))

    def julga(rot, x, y):
        d = x["tr_1"].mean() - y["tr_1"].mean()
        lo, hi = boot_pnl(x, y, "tr_1")
        larg = hi - lo
        if larg > 2 * CORTE:
            v = ("SEM PODER (IC de %.0f pts = %.1fx o custo; limite 2x)"
                 % (larg, larg / CORTE))
        elif hi < 0:
            v = "REJEITADOS PIORES - o filtro fez o trabalho dele"
        elif lo > 0:
            v = "REJEITADOS MELHORES - o filtro jogava fora sinal bom"
        elif abs(d) < CORTE:
            v = "REJEITADOS NORMAIS - a regua estava presa"
        else:
            v = "IC contem zero mas a diferenca e' grande - sem conclusao"
        print("  %-30s %+7.0f x %+7.0f  dif %+7.0f  IC95 [%+.0f, %+.0f]"
              % (rot, x["tr_1"].mean(), y["tr_1"].mean(), d, lo, hi))
        print("      -> %s" % v)

    julga("T1 abr+mai rej x aceitos out", a1, b1)
    g2 = df[df["mes"].isin(["2026-02", "2026-06"])]
    julga("T2 fev+jun rej x aceitos", g2[g2["rej"]], g2[~g2["rej"]])

    print("")
    print("=" * 74)
    print("LIMITES")
    print("=" * 74)
    print("  - Assimetria e' condicao NECESSARIA, nao suficiente, e nao diz a")
    print("    ORDEM dos eventos. Nao e' P&L.")
    print("  - O teste 1 nao separa filtro de mes. O teste 2 separa mes mas")
    print("    fala de fev/jun, nao de abr/mai.")
    print("  - `tr_1` nao e' a estrategia titular (trailing de 2000 pts contra")
    print("    stop 3,67xATR e BE no zero). Vale como regua comparativa, nao")
    print("    como previsao de P&L da estrategia.")
    print("  - Um servidor de demo, um simbolo, 7 meses.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
